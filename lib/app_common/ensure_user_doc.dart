import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// 初回作成やロール/病院IDの確定に使うブートストラップユーティリティ
class UserBootstrapService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// users/{uid} に role / hospitalId / email / name を保存（未作成なら作成）
  Future<void> ensureUserDoc({
    required String role, // 'patient' | 'admin'（旧'hospital'は'admin'に正規化）
    required String hospitalId,
    Map<String, dynamic>? extra,
  }) async {
    final uid = _auth.currentUser!.uid;
    final email = _auth.currentUser!.email ?? '';
    final displayName = _auth.currentUser!.displayName ?? '';
    final ref = _db.collection('users').doc(uid);
    final snap = await ref.get();
    // 旧 'hospital' を 'admin' に正規化
    final roleNormalized = (role == 'hospital') ? 'admin' : role;

    final data = <String, dynamic>{
      'role': roleNormalized,
      'hospitalId': hospitalId,
      'email': email,
      'name': displayName,
      'uid': uid,
      'updatedAt': FieldValue.serverTimestamp(),
      if (extra != null) ...extra,
    };

    if (!snap.exists) {
      await ref.set({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } else {
      await ref.set(data, SetOptions(merge: true));
    }
  }
}


