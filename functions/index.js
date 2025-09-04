// ==== Imports ====
const admin = require('firebase-admin');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onObjectFinalized } = require('firebase-functions/v2/storage');
// Identity triggersは利用せず、クライアント側で users/{uid} 作成を行う
const { defineSecret } = require('firebase-functions/params');

// ==== Init ====
admin.initializeApp();
const ADMIN_INVITE_CODE = defineSecret('ADMIN_INVITE_CODE');

// 初回サインアップ時の users/{uid} 作成はクライアントから行います（UserBootstrapServiceなど）

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

  // 既に所属済みなら禁止
  if (claims?.hid) {
    throw new HttpsError('failed-precondition', '既に病院が設定されています。変更はできません。');
  }

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

  // 管理者ユーザーに hospitalId と病院名を反映（管理UIで表示するため name を病院名に）
  await db.collection('users').doc(uid).set({
    hospitalId: hid,
    role: 'admin',
    name: name,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  const user = await admin.auth().getUser(uid);
  const current = user.customClaims || {};
  await admin.auth().setCustomUserClaims(uid, { ...current, admin: true, hid });

  return { ok: true, hospitalId: hid };
});

// ==== 病院コードで参加（患者/管理者どちらでも可） ====
exports.joinHospitalByCode = onCall({ region: 'asia-northeast1' }, async (req) => {
  const uid = req.auth?.uid;
  const claims = req.auth?.token;
  if (!uid) throw new HttpsError('unauthenticated', 'ログインが必要です。');

  // 既に所属済みなら禁止
  if (claims?.hid) {
    throw new HttpsError('failed-precondition', '既に病院が設定されています。変更はできません。');
  }

  const code = (req.data?.code || '').trim();
  if (!code) throw new HttpsError('invalid-argument', 'code が必要です。');

  const db = admin.firestore();
  const snap = await db.collection('hospitals').where('joinCode', '==', code).limit(1).get();
  if (snap.empty) throw new HttpsError('not-found', '該当する病院がありません。');

  const hid = snap.docs[0].id;
  // 既存病院に参加。管理者であれば name を病院名に、role も 'admin' を維持
  let hospitalName = '';
  try {
    const hdoc = await db.collection('hospitals').doc(hid).get();
    hospitalName = hdoc.data()?.name || '';
  } catch(_) {}

  const setData = { hospitalId: hid, updatedAt: admin.firestore.FieldValue.serverTimestamp() };
  if (claims?.admin) {
    // すでに管理者のユーザーは表示名を病院名にそろえる
    setData['role'] = 'admin';
    if (hospitalName) setData['name'] = hospitalName;
  }
  await db.collection('users').doc(uid).set(setData, { merge: true });

  const user = await admin.auth().getUser(uid);
  const current = user.customClaims || {};
  await admin.auth().setCustomUserClaims(uid, { ...current, hid });

  return { ok: true, hospitalId: hid };
});

// ==== 動画メタ検証（最大2分、720pまで） ====
exports.checkVideoMetaOnUpload = onObjectFinalized({ region: 'asia-northeast1' }, async (event) => {
  const obj = event.data;
  const name = obj.name || '';
  // 720p変換パイプライン: uploads_raw/** を処理対象にする
  if (!(name.startsWith('uploads_raw/') || name.startsWith('rehab_videos/'))) return;
  if (!/\.(mp4|mov|qt)$/i.test(name)) return;

  const db = admin.firestore();

  // ここではStorageメタの custom metadata を信頼。将来ffprobe等に切替可能
  const bucket = admin.storage().bucket(obj.bucket);
  const file = bucket.file(name);
  let durationSec = null; let height = null;
  try {
    const [md] = await file.getMetadata();
    const m = md?.metadata || {};
    if (m.durationSec) durationSec = Number(m.durationSec);
    if (m.height) height = Number(m.height);
  } catch (_) {}

  const violations = [];
  const isMov = /\.(mov|qt)$/i.test(name);
  if (durationSec != null && durationSec > 120) violations.push('overDuration');
  if (height != null && height > 720) violations.push('overResolution');
  if (isMov) violations.push('movFormat');
  if (violations.length === 0) return;

  // ex-<exerciseId>-*.ext の慣例で exercises doc を推定
  const base = name.split('/').pop() || '';
  const m = base.match(/ex-([A-Za-z0-9_-]+)/);
  if (!m) return;
  const exerciseId = m[1];

  await db.collection('exercises').doc(exerciseId).set({
    warning: {
      movFormat: violations.includes('movFormat'),
      overDuration: violations.includes('overDuration'),
      overResolution: violations.includes('overResolution'),
      checkedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    // 時間/解像度逸脱は公開ブロック
    ...(violations.includes('overDuration') || violations.includes('overResolution') ? { blocked: true } : {})
  }, { merge: true });

  // もし raw に置かれた原本なら、ここで720p変換ジョブをキック（簡易: ここではマーカーのみ。次ステップでCloud Run実装）
  if (name.startsWith('uploads_raw/')) {
    await db.collection('exercises').doc(exerciseId).set({ processing: true }, { merge: true });
    // Cloud Run TranscoderへHTTPリクエスト（環境変数 TRANSCODER_URL を設定しておく）
    const dest = name.replace('uploads_raw/', 'rehab_videos/').replace(/\.(mov|qt)$/i, '.mp4');
    const body = { bucket: obj.bucket, src: name, dest };
    try {
      let url = process.env.TRANSCODER_URL;
      if (!url) {
        try {
          const conf = await db.doc('app_config/runtime').get();
          url = conf?.data()?.transcoderUrl || null;
        } catch (_) {}
      }
      if (url) {
        await fetch(url + '/transcode', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
        const finalUrl = `https://storage.googleapis.com/${obj.bucket}/${dest}`;
        await db.collection('exercises').doc(exerciseId).set({ videoUrl: finalUrl, processing: false }, { merge: true });
      }
    } catch (_) {}
  }
});

// ==== 月間アップロード制限（管理者: 10本/月） ====
function monthKeyNow() {
  const now = new Date();
  const y = now.getUTCFullYear();
  const m = (now.getUTCMonth() + 1).toString().padStart(2, '0');
  return `${y}${m}`;
}

exports.assertExerciseUploadQuota = onCall({ region: 'asia-northeast1' }, async (req) => {
  const uid = req.auth?.uid;
  const claims = req.auth?.token;
  if (!uid) throw new HttpsError('unauthenticated', 'ログインが必要です。');
  if (!claims?.admin) throw new HttpsError('permission-denied', '管理者のみアップロード可能です。');

  const db = admin.firestore();
  const key = monthKeyNow();
  const ref = db.collection('users').doc(uid).collection('upload_counters').doc(key);

  let countAfter;
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const cur = (snap.exists ? (snap.data().count || 0) : 0);
    if (cur >= 10) {
      throw new HttpsError('resource-exhausted', '今月のアップロード上限（10本）に達しました。');
    }
    countAfter = cur + 1;
    tx.set(ref, { count: countAfter, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
  });

  return { ok: true, count: countAfter, month: key };
});