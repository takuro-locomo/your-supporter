// ==== Imports ====
const admin = require('firebase-admin');
const functions = require('firebase-functions'); // ← v1 を使う（auth trigger用）
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');

// ==== Init ====
admin.initializeApp();
const ADMIN_INVITE_CODE = defineSecret('ADMIN_INVITE_CODE');

// ==== Auth: ユーザー作成時に users/{uid} を用意（v1トリガー） ====
exports.onAuthCreate = functions
  .region('asia-northeast1')
  .auth.user()
  .onCreate(async (user) => {
    await admin.firestore().collection('users').doc(user.uid).set(
      {
        uid: user.uid,
        email: user.email || '',
        name: user.displayName || '',
        role: 'patient',
        hospitalId: null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  });

// ==== 管理者昇格（招待コード） ====
exports.elevateToAdmin = onCall(
  { region: 'asia-northeast1', secrets: [ADMIN_INVITE_CODE] },
  async (req) => {
    const uid = req.auth?.uid;
    if (!uid) throw new HttpsError('unauthenticated', 'ログインが必要です。');

    const code = (req.data?.code || '').trim();
    if (!code) throw new HttpsError('invalid-argument', 'code が必要です。');
    if (code !== ADMIN_INVITE_CODE.value())
      throw new HttpsError('permission-denied', '招待コードが無効です。');

    await admin.auth().setCustomUserClaims(uid, { admin: true });
    await admin.firestore().collection('users').doc(uid).set({ role: 'admin' }, { merge: true });
    return { ok: true };
  }
);

// ==== 病院を作成（自分を所属させる） ====
exports.createHospital = onCall({ region: 'asia-northeast1' }, async (req) => {
  const uid = req.auth?.uid;
  const claims = req.auth?.token;
  if (!uid) throw new HttpsError('unauthenticated', 'ログインが必要です。');
  if (!claims?.admin) throw new HttpsError('permission-denied', '管理者のみ実行できます。');

  const name = (req.data?.name || '').trim();
  const joinCode = (req.data?.joinCode || '').trim();
  if (!name || !joinCode) throw new HttpsError('invalid-argument', 'name と joinCode が必要です。');

  const db = admin.firestore();
  const dup = await db.collection('hospitals').where('joinCode', '==', joinCode).limit(1).get();
  if (!dup.empty) throw new HttpsError('already-exists', 'この病院コードは既に使用されています。');

  const ref = await db.collection('hospitals').add({
    name,
    joinCode,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    createdBy: uid,
  });
  const hid = ref.id;

  await db.collection('users').doc(uid).set({ hospitalId: hid }, { merge: true });

  const user = await admin.auth().getUser(uid);
  const current = user.customClaims || {};
  await admin.auth().setCustomUserClaims(uid, { ...current, admin: true, hid });

  return { ok: true, hospitalId: hid };
});

// ==== 病院コードで参加（患者/管理者どちらでも可） ====
exports.joinHospitalByCode = onCall({ region: 'asia-northeast1' }, async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'ログインが必要です。');

  const code = (req.data?.code || '').trim();
  if (!code) throw new HttpsError('invalid-argument', 'code が必要です。');

  const db = admin.firestore();
  const snap = await db.collection('hospitals').where('joinCode', '==', code).limit(1).get();
  if (snap.empty) throw new HttpsError('not-found', '該当する病院がありません。');

  const hid = snap.docs[0].id;

  await db.collection('users').doc(uid).set({ hospitalId: hid }, { merge: true });

  const user = await admin.auth().getUser(uid);
  const current = user.customClaims || {};
  await admin.auth().setCustomUserClaims(uid, { ...current, hid });

  return { ok: true, hospitalId: hid };
});