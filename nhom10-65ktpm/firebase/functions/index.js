// SingLearn Cloud Functions (cloud mode only).
//
// 1. notifyChallenge: sends an FCM push to the invited friend when a
//    "guess the song" challenge is created, and to the challenger when the
//    friend submits a result (section 4.2: Firebase Cloud Messaging).
// 2. setAdmin: callable used by an existing admin to grant the `admin`
//    custom claim to another account (section 8.3).
//
// Device tokens are stored by the app in users/{uid}.fcmTokens (array).
const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');

admin.initializeApp();

async function tokensOf(uid) {
  const snap = await admin.firestore().doc(`users/${uid}`).get();
  return (snap.exists && snap.data().fcmTokens) || [];
}

async function push(uid, title, body, data) {
  const tokens = await tokensOf(uid);
  if (tokens.length === 0) return;
  await admin.messaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
    data,
    android: { notification: { channelId: 'social' } },
  });
}

exports.notifyChallenge = onDocumentWritten('challenges/{id}', async (event) => {
  const before = event.data.before.exists ? event.data.before.data() : null;
  const after = event.data.after.exists ? event.data.after.data() : null;
  if (!after) return;
  if (!before && after.status === 'waiting') {
    await push(after.toUid, 'Lời mời thử thách mới',
      `${after.fromName} thách bạn "Đoán tên bài hát" (${after.fromScore} điểm).`,
      { challengeId: event.params.id });
  } else if (before && before.status === 'waiting' && after.status === 'completed') {
    const result = after.toScore === after.fromScore ? 'Hòa'
      : (after.toScore > after.fromScore ? `${after.toName} thắng` : 'Bạn thắng');
    await push(after.fromUid, 'Kết quả thử thách',
      `${result}: ${after.fromScore} – ${after.toScore}.`,
      { challengeId: event.params.id });
  }
});

exports.setAdmin = onCall(async (request) => {
  if (!request.auth || request.auth.token.admin !== true) {
    throw new HttpsError('permission-denied', 'Chỉ quản trị viên được cấp quyền.');
  }
  const email = String(request.data.email || '').toLowerCase();
  const user = await admin.auth().getUserByEmail(email);
  await admin.auth().setCustomUserClaims(user.uid, { ...(user.customClaims || {}), admin: true });
  return { uid: user.uid };
});
