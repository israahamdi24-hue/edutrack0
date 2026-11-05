const test = require('node:test');
const assert = require('node:assert/strict');
const { createAttendanceToken, verifyAttendanceToken } = require('./attendance_token');

const secret = 'test-secret-at-least-thirty-two-characters';

test('verifies a signed QR token before its deadline', () => {
  const token = createAttendanceToken('session-1', 20_000, secret, 10_000);
  const payload = verifyAttendanceToken(token, secret, 15_000);
  assert.equal(payload.sessionId, 'session-1');
  assert.equal(payload.expiresAt, 20_000);
});

test('rejects modified, malformed, and expired tokens', () => {
  const token = createAttendanceToken('session-1', 20_000, secret, 10_000);
  assert.equal(verifyAttendanceToken(`${token}x`, secret, 15_000), null);
  assert.equal(verifyAttendanceToken('random text', secret, 15_000), null);
  assert.equal(verifyAttendanceToken(token, secret, 20_000), null);
});

test('uses a unique nonce for each token', () => {
  const first = verifyAttendanceToken(createAttendanceToken('s', 50_000, secret, 10_000), secret, 12_000);
  const second = verifyAttendanceToken(createAttendanceToken('s', 50_000, secret, 10_000), secret, 12_000);
  assert.notEqual(first.nonce, second.nonce);
});

test('rejects a token signed with a different secret', () => {
  const token = createAttendanceToken('session-1', 20_000, secret, 10_000);
  assert.equal(verifyAttendanceToken(token, 'another-secret-at-least-32-characters', 15_000), null);
});
