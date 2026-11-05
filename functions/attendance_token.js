const crypto = require('node:crypto');

function encode(value) {
  return Buffer.from(value).toString('base64url');
}

function createAttendanceToken(sessionId, expiresAt, secret, now = Date.now()) {
  if (
    typeof sessionId !== 'string' ||
    sessionId.length === 0 ||
    sessionId.length > 256 ||
    sessionId.includes('/')
  ) {
    throw new TypeError('sessionId must be a non-empty string');
  }
  if (typeof secret !== 'string' || secret.length < 32) {
    throw new TypeError('QR signing secret must contain at least 32 characters');
  }
  const payload = {
    v: 1,
    sessionId,
    issuedAt: now,
    expiresAt,
    nonce: crypto.randomBytes(16).toString('base64url'),
  };
  const encoded = encode(JSON.stringify(payload));
  const signature = crypto
    .createHmac('sha256', secret)
    .update(encoded)
    .digest('base64url');
  return `edutrack:v1:${encoded}.${signature}`;
}

function verifyAttendanceToken(token, secret, now = Date.now(), allowExpired = false) {
  if (typeof token !== 'string' || typeof secret !== 'string' || secret.length < 32) {
    return null;
  }
  const match = /^edutrack:v1:([A-Za-z0-9_-]+)\.([A-Za-z0-9_-]+)$/.exec(token);
  if (!match) return null;
  const [, encoded, providedSignature] = match;
  const expectedSignature = crypto
    .createHmac('sha256', secret)
    .update(encoded)
    .digest();
  let actualSignature;
  try {
    actualSignature = Buffer.from(providedSignature, 'base64url');
  } catch (_) {
    return null;
  }
  if (
    actualSignature.length !== expectedSignature.length ||
    !crypto.timingSafeEqual(actualSignature, expectedSignature)
  ) {
    return null;
  }
  try {
    const payload = JSON.parse(Buffer.from(encoded, 'base64url').toString('utf8'));
    if (
      payload.v !== 1 ||
      typeof payload.sessionId !== 'string' ||
      !payload.sessionId ||
      payload.sessionId.length > 256 ||
      payload.sessionId.includes('/') ||
      !Number.isSafeInteger(payload.expiresAt) ||
      !Number.isSafeInteger(payload.issuedAt) ||
      typeof payload.nonce !== 'string' ||
      payload.issuedAt > now ||
      (!allowExpired && payload.expiresAt <= now)
    ) {
      return null;
    }
    return payload;
  } catch (_) {
    return null;
  }
}

module.exports = { createAttendanceToken, verifyAttendanceToken };
