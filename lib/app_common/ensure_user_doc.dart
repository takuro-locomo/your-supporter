import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// 初回作成やロール/病院IDの確定に使うブートストラップユーティリティ
class UserBootstrapService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// users/{uid} に role と hospitalId を保存（未作成なら作成）
  Future<void> ensureUserDoc({
    required String role, // 'patient' | 'hospital'
    required String hospitalId,
    Map<String, dynamic>? extra,
  }) async {
    final uid = _auth.currentUser!.uid;
    final ref = _db.collection('users').doc(uid);
    final snap = await ref.get();

    final data = <String, dynamic>{
      'role': role,
      'hospitalId': hospitalId,
      'updatedAt': FieldValue.serverTimestamp(),
      if (extra != null) ...extra,
    };

    if (!snap.exists) {
      await ref.set({
        ...data,
        'uid': uid,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } else {
      await ref.set(data, SetOptions(merge: true));
    }
  }
}


