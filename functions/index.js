const { initializeApp } = require('firebase-admin/app');
const { FieldValue, Timestamp, getFirestore } = require('firebase-admin/firestore');
const { defineSecret } = require('firebase-functions/params');
const { HttpsError, onCall } = require('firebase-functions/v2/https');
const { createAttendanceToken, verifyAttendanceToken } = require('./attendance_token');

initializeApp();
const db = getFirestore();
const qrSigningSecret = defineSecret('EDUTRACK_QR_SIGNING_SECRET');
const attendanceWindowMs = 15 * 60 * 1000;

async function requireProfile(uid) {
  const snapshot = await db.collection('users').doc(uid).get();
  if (!snapshot.exists) {
    throw new HttpsError('permission-denied', 'EduTrack profile is missing.');
  }
  return snapshot.data();
}

exports.generateSessionQr = onCall(
  { secrets: [qrSigningSecret] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Sign in to generate a QR code.');
    }
    const sessionId = request.data?.sessionId;
    if (
      typeof sessionId !== 'string' ||
      !sessionId.trim() ||
      sessionId.length > 256 ||
      sessionId.includes('/')
    ) {
      throw new HttpsError('invalid-argument', 'A sessionId is required.');
    }
    const profile = await requireProfile(request.auth.uid);
    const hasAdminClaim = request.auth.token.admin === true;
    if ((profile.role === 'admin') !== hasAdminClaim) {
      throw new HttpsError('permission-denied', 'The profile role and admin claim do not match.');
    }
    const isAdmin = profile.role === 'admin';
    if (profile.role !== 'teacher' && !isAdmin) {
      throw new HttpsError('permission-denied', 'Only the session teacher can issue its QR code.');
    }

    const sessionSnapshot = await db.collection('sessions').doc(sessionId).get();
    if (!sessionSnapshot.exists) {
      throw new HttpsError('not-found', 'Session not found.');
    }
    const session = sessionSnapshot.data();
    if (typeof session.courseId !== 'string' || typeof session.teacherUid !== 'string') {
      throw new HttpsError('failed-precondition', 'The session assignment is invalid.');
    }
    const courseSnapshot = await db.collection('courses').doc(session.courseId).get();
    if (!courseSnapshot.exists || courseSnapshot.data().teacherUid !== session.teacherUid) {
      throw new HttpsError('failed-precondition', 'The session and course assignments do not match.');
    }
    if (!isAdmin && session.teacherUid !== request.auth.uid) {
      throw new HttpsError('permission-denied', 'This session belongs to another teacher.');
    }
    if (!(session.startsAt instanceof Timestamp)) {
      throw new HttpsError('failed-precondition', 'The session start time is invalid.');
    }
    if (session.endsAt != null && !(session.endsAt instanceof Timestamp)) {
      throw new HttpsError('failed-precondition', 'The session end time is invalid.');
    }
    if (
      session.endsAt &&
      session.endsAt.toMillis() <= session.startsAt.toMillis()
    ) {
      throw new HttpsError('failed-precondition', 'The session end must be after its start.');
    }
    const expiresAt = session.startsAt.toMillis() + attendanceWindowMs;
    const serverNow = Date.now();
    if (serverNow < session.startsAt.toMillis()) {
      throw new HttpsError('failed-precondition', 'The session has not started yet.');
    }
    if (serverNow >= expiresAt || (session.endsAt && serverNow >= session.endsAt.toMillis())) {
      throw new HttpsError('deadline-exceeded', 'The attendance window has expired.');
    }

    const qrPayload = createAttendanceToken(
      sessionId,
      expiresAt,
      qrSigningSecret.value(),
    );
    return { qrPayload, expiresAt };
  },
);

exports.recordStudentAttendance = onCall(
  { secrets: [qrSigningSecret] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Sign in before recording attendance.');
    }
    const profile = await requireProfile(request.auth.uid);
    if (profile.role !== 'student' || request.auth.token.admin === true) {
      throw new HttpsError('permission-denied', 'Only student accounts can record attendance.');
    }

    const qrPayload = request.data?.qrPayload;
    if (typeof qrPayload !== 'string' || qrPayload.length > 2048) {
      throw new HttpsError('invalid-argument', 'The QR code payload is invalid.');
    }
    const token = verifyAttendanceToken(
      qrPayload,
      qrSigningSecret.value(),
      Date.now(),
      true,
    );
    if (!token) {
      throw new HttpsError('invalid-argument', 'The QR code is invalid.');
    }
    if (token.expiresAt <= Date.now()) {
      throw new HttpsError('deadline-exceeded', 'The QR code has expired.');
    }

    const sessionRef = db.collection('sessions').doc(token.sessionId);
    const attendanceRef = db.collection('attendance').doc(`${request.auth.uid}_${token.sessionId}`);
    try {
      await db.runTransaction(async (transaction) => {
        const sessionSnapshot = await transaction.get(sessionRef);
        if (!sessionSnapshot.exists) {
          throw new HttpsError('not-found', 'The session no longer exists.');
        }
        const session = sessionSnapshot.data();
        if (!(session.startsAt instanceof Timestamp) || typeof session.courseId !== 'string') {
          throw new HttpsError('failed-precondition', 'The session data is invalid.');
        }
        if (session.endsAt != null && !(session.endsAt instanceof Timestamp)) {
          throw new HttpsError('failed-precondition', 'The session end time is invalid.');
        }
        const enrollmentRef = db.collection('enrollments').doc(`${request.auth.uid}_${session.courseId}`);
        const enrollmentSnapshot = await transaction.get(enrollmentRef);
        const existing = await transaction.get(attendanceRef);
        const now = Timestamp.now();
        const startsAtMs = session.startsAt.toMillis();
        const deadlineMs = startsAtMs + attendanceWindowMs;
        if (now.toMillis() < startsAtMs || now.toMillis() >= deadlineMs || token.expiresAt !== deadlineMs) {
          throw new HttpsError('deadline-exceeded', 'The attendance window is not open.');
        }
        if (session.endsAt && now.toMillis() >= session.endsAt.toMillis()) {
          throw new HttpsError('deadline-exceeded', 'The session has already ended.');
        }
        if (
          !enrollmentSnapshot.exists ||
          enrollmentSnapshot.data().studentUid !== request.auth.uid ||
          enrollmentSnapshot.data().courseId !== session.courseId ||
          enrollmentSnapshot.data().status !== 'active'
        ) {
          throw new HttpsError('permission-denied', 'You are not actively enrolled in this course.');
        }
        if (existing.exists) {
          throw new HttpsError('already-exists', 'Attendance was already recorded.');
        }
        transaction.create(attendanceRef, {
          studentUid: request.auth.uid,
          sessionId: token.sessionId,
          courseId: session.courseId,
          status: 'present',
          recordedAt: FieldValue.serverTimestamp(),
        });
      });
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      throw new HttpsError('internal', 'Attendance could not be recorded.');
    }

    return { success: true, message: 'Votre présence a été enregistrée.' };
  },
);

exports.getEnrolledStudents = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Sign in to view enrolled students.');
  }
  const profile = await requireProfile(request.auth.uid);
  const hasAdminClaim = request.auth.token.admin === true;
  if ((profile.role === 'admin') !== hasAdminClaim) {
    throw new HttpsError('permission-denied', 'The profile role and admin claim do not match.');
  }
  const isAdmin = profile.role === 'admin';
  if (profile.role !== 'teacher' && !isAdmin) {
    throw new HttpsError('permission-denied', 'This operation is for teachers.');
  }
  const courseId = request.data?.courseId;
  if (typeof courseId !== 'string' || !courseId.trim()) {
    throw new HttpsError('invalid-argument', 'A courseId is required.');
  }
  const courseSnapshot = await db.collection('courses').doc(courseId).get();
  if (!courseSnapshot.exists) {
    throw new HttpsError('not-found', 'Course not found.');
  }
  if (!isAdmin && courseSnapshot.data().teacherUid !== request.auth.uid) {
    throw new HttpsError('permission-denied', 'This course belongs to another teacher.');
  }
  const enrollments = await db
    .collection('enrollments')
    .where('courseId', '==', courseId)
    .get();
  const students = await Promise.all(enrollments.docs.map(async (enrollment) => {
    if (enrollment.data().status !== 'active') return null;
    const uid = enrollment.data().studentUid;
    if (typeof uid !== 'string' || enrollment.id !== `${uid}_${courseId}`) return null;
    const studentSnapshot = await db.collection('users').doc(uid).get();
    if (!studentSnapshot.exists || studentSnapshot.data().role !== 'student') return null;
    const student = studentSnapshot.data();
    return {
      uid,
      displayName: typeof student.displayName === 'string' ? student.displayName : 'Étudiant',
      className: typeof student.className === 'string' ? student.className : null,
    };
  }));
  return { students: students.filter(Boolean) };
});
