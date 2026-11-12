const fs = require('node:fs');
const path = require('node:path');
const { after, before, beforeEach, test } = require('node:test');
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  collection,
  doc,
  getDoc,
  setDoc,
  updateDoc,
} = require('firebase/firestore');

let environment;
const projectId = 'demo-edutrack-rules';

before(async () => {
  environment = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8'),
    },
  });
});

beforeEach(async () => {
  await environment.clearFirestore();
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await Promise.all([
      setDoc(doc(db, 'users/student-1'), {
        uid: 'student-1', email: 'one@example.edu', displayName: 'Student One', role: 'student',
      }),
      setDoc(doc(db, 'users/student-2'), {
        uid: 'student-2', email: 'two@example.edu', displayName: 'Student Two', role: 'student',
      }),
      setDoc(doc(db, 'users/teacher-1'), {
        uid: 'teacher-1', email: 'teacher@example.edu', displayName: 'Teacher One', role: 'teacher',
      }),
      setDoc(doc(db, 'users/admin-1'), {
        uid: 'admin-1', email: 'admin@example.edu', displayName: 'Admin One', role: 'admin',
      }),
      setDoc(doc(db, 'courses/course-1'), {
        name: 'Course One', teacherName: 'Teacher One', teacherUid: 'teacher-1',
      }),
      setDoc(doc(db, 'courses/course-2'), {
        name: 'Course Two', teacherName: 'Other Teacher', teacherUid: 'teacher-2',
      }),
      setDoc(doc(db, 'enrollments/student-1_course-1'), {
        studentUid: 'student-1', courseId: 'course-1', status: 'active',
      }),
      setDoc(doc(db, 'sessions/session-1'), {
        courseId: 'course-1', teacherUid: 'teacher-1', startsAt: new Date(),
      }),
      setDoc(doc(db, 'sessions/session-2'), {
        courseId: 'course-2', teacherUid: 'teacher-2', startsAt: new Date(),
      }),
      setDoc(doc(db, 'users/student-1/notifications/n1'), {
        title: 'Notice', message: 'Hello', createdAt: new Date(), isRead: false,
      }),
      setDoc(doc(db, 'users/student-2/notifications/n2'), {
        title: 'Notice', message: 'Hello', createdAt: new Date(), isRead: false,
      }),
    ]);
  });
});

after(async () => {
  await environment?.cleanup();
});

test('students can read only their private profile and enrolled course/session data', async () => {
  const db = environment.authenticatedContext('student-1').firestore();
  await assertSucceeds(getDoc(doc(db, 'users/student-1')));
  await assertFails(getDoc(doc(db, 'users/student-2')));
  await assertSucceeds(getDoc(doc(db, 'courses/course-1')));
  await assertFails(getDoc(doc(db, 'courses/course-2')));
  await assertSucceeds(getDoc(doc(db, 'sessions/session-1')));
  await assertFails(getDoc(doc(db, 'sessions/session-2')));
});

test('students cannot promote themselves, edit protected profile fields, or write attendance', async () => {
  const db = environment.authenticatedContext('student-1').firestore();
  await assertSucceeds(updateDoc(doc(db, 'users/student-1'), { displayName: 'Updated Name' }));
  await assertFails(updateDoc(doc(db, 'users/student-1'), { role: 'admin' }));
  await assertFails(updateDoc(doc(db, 'users/student-1'), { className: 'DSI L3' }));
  await assertFails(setDoc(doc(db, 'attendance/student-1_session-1'), {
    studentUid: 'student-1', sessionId: 'session-1', courseId: 'course-1', status: 'present', recordedAt: new Date(),
  }));
});

test('students can only mark their own notification as read', async () => {
  const db = environment.authenticatedContext('student-1').firestore();
  await assertSucceeds(updateDoc(doc(db, 'users/student-1/notifications/n1'), { isRead: true }));
  await assertFails(updateDoc(doc(db, 'users/student-1/notifications/n1'), { message: 'changed' }));
  await assertFails(updateDoc(doc(db, 'users/student-2/notifications/n2'), { isRead: true }));
});

test('teachers can access their assigned course and create only its sessions', async () => {
  const db = environment.authenticatedContext('teacher-1').firestore();
  await assertSucceeds(getDoc(doc(db, 'courses/course-1')));
  await assertFails(getDoc(doc(db, 'courses/course-2')));
  await assertSucceeds(setDoc(doc(db, 'sessions/session-new'), {
    courseId: 'course-1', teacherUid: 'teacher-1', startsAt: new Date(),
  }));
  await assertFails(setDoc(doc(db, 'sessions/session-other'), {
    courseId: 'course-2', teacherUid: 'teacher-1', startsAt: new Date(),
  }));
  await assertFails(setDoc(doc(db, 'attendance/teacher-1_session-1'), {
    studentUid: 'teacher-1', sessionId: 'session-1', courseId: 'course-1', status: 'present', recordedAt: new Date(),
  }));
});

test('admins can create and reschedule sessions for their assigned courses', async () => {
  const db = environment.authenticatedContext('admin-1', { admin: true }).firestore();
  const sessionRef = doc(db, 'sessions/admin-session');
  const startsAt = new Date(Date.now() + 60_000);
  const endsAt = new Date(startsAt.getTime() + 60 * 60 * 1000);

  await assertSucceeds(setDoc(sessionRef, {
    courseId: 'course-1',
    teacherUid: 'teacher-1',
    startsAt,
    endsAt,
  }));
  await assertSucceeds(updateDoc(sessionRef, {
    startsAt: new Date(Date.now()),
    endsAt: new Date(Date.now() + 60 * 60 * 1000),
  }));
  await assertFails(setDoc(doc(db, 'sessions/wrong-teacher'), {
    courseId: 'course-1',
    teacherUid: 'teacher-2',
    startsAt,
  }));
});

test('admin access depends on the custom claim', async () => {
  const claimedAdmin = environment.authenticatedContext('admin-1', { admin: true }).firestore();
  const roleOnlyAdmin = environment.authenticatedContext('admin-1').firestore();
  await assertSucceeds(getDoc(doc(claimedAdmin, 'users/student-2')));
  await assertSucceeds(getDoc(doc(claimedAdmin, 'courses/course-2')));
  await assertFails(getDoc(doc(roleOnlyAdmin, 'users/student-2')));
});
