const admin = require("firebase-admin");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");

admin.initializeApp();

// 招待コード（Secrets）
const ADMIN_INVITE_CODE = defineSecret("ADMIN_INVITE_CODE");

// 1) Auth トリガーの代わりに、アプリ側でユーザー作成時に呼び出す関数
exports.createUserDoc = onCall(
    {region: "asia-northeast1"},
    async (req) => {
      const uid = req.auth && req.auth.uid;
      if (!uid) throw new HttpsError("unauthenticated", "ログインが必要です。");

      const db = admin.firestore();
      const userRef = db.collection("users").doc(uid);
      const userDoc = await userRef.get();

      // 既にドキュメントが存在する場合はスキップ
      if (userDoc.exists) return {ok: true, message: "既に作成済み"};

      // 新規ユーザーの場合は基本情報を作成
      const userRecord = await admin.auth().getUser(uid);
      await userRef.set({
        uid: uid,
        email: userRecord.email || "",
        name: userRecord.displayName || "",
        role: "patient",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {ok: true, message: "ユーザードキュメント作成完了"};
    },
);

// 2) 招待コードOKなら admin クレーム付与 + Firestore も 'admin' に同期
exports.elevateToAdmin = onCall(
    {region: "asia-northeast1", secrets: [ADMIN_INVITE_CODE]},
    async (req) => {
      const uid = req.auth && req.auth.uid;
      if (!uid) throw new HttpsError("unauthenticated", "ログインが必要です。");

      const code = (req.data && req.data.code || "").trim();
      if (!code) throw new HttpsError("invalid-argument", "code が必要です。");

      const expected = ADMIN_INVITE_CODE.value();
      if (code !== expected) {
        throw new HttpsError("permission-denied", "招待コードが無効です。");
      }

      // custom claims に admin: true を付与
      await admin.auth().setCustomUserClaims(uid, {admin: true});

      // 表示用に Firestore 側の role も同期
      await admin.firestore().collection("users").doc(uid).set({
        role: "admin",
        adminSince: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});

      return {ok: true};
    },
);
