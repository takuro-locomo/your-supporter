import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models.dart';

final _db = FirebaseFirestore.instance;

/// 現在のユーザの custom claims から hospitalId を取得
Future<String?> currentHid() async {
  final r = await FirebaseAuth.instance.currentUser!.getIdTokenResult(true);
  return r.claims?['hid'] as String?;
}

class UserService {
  static Future<void> ensureUserDoc(AppUser user) async {
    final doc = _db.collection('users').doc(user.uid);
    final snap = await doc.get();
    if (!snap.exists) {
      await doc.set(user.toMap(), SetOptions(merge: true));
    }
  }

  static Future<AppUser?> fetch(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromMap(doc.data()!);
  }

  /// ★ 院ごとの患者一覧（必ず hospitalId で絞り込む）
  static Stream<QuerySnapshot<Map<String, dynamic>>> streamPatientsOf(String hospitalId) {
    return _db.collection('users')
        .where('role', isEqualTo: 'patient')
        .where('hospitalId', isEqualTo: hospitalId)
        .snapshots();
  }

  /// 患者自身のプロフィール更新（氏名・生年月日のみ）
  static Future<void> updateMyProfile(String uid, {required String name, required String birthDate}) {
    return _db.collection('users').doc(uid).set({
      'name': name,
      'birthDate': birthDate,
    }, SetOptions(merge: true));
  }

  /// 管理者が手術情報を更新（患者側からは書けない）
  static Future<void> updateSurgeryByAdmin(String userId, {
    String? surgeryDate,
    String? surgeryApproach,
    String? surgerySide,
  }) {
    return _db.collection('users').doc(userId).set({
      if (surgeryDate != null) 'surgeryDate': surgeryDate,
      if (surgeryApproach != null) 'surgeryApproach': surgeryApproach,
      if (surgerySide != null) 'surgerySide': surgerySide,
    }, SetOptions(merge: true));
  }
}

class ExerciseService {
  /// ★ 院ごとのエクササイズ一覧
  static Stream<QuerySnapshot<Map<String, dynamic>>> streamExercisesOf(String hospitalId) =>
      _db.collection('exercises')
          .where('hospitalId', isEqualTo: hospitalId)
          .snapshots();

  /// ★ 作成/更新は hospitalId を必ず付与
  static Future<void> addOrUpdateExercise({
    String? id,
    required String title,
    required String description,
    required String videoUrl,
    required String hospitalId,
  }) async {
    final data = {
      'title': title,
      'description': description,
      'videoUrl': videoUrl,
      'hospitalId': hospitalId,
    };
    final col = _db.collection('exercises');
    if (id == null) {
      await col.add(data);
    } else {
      await col.doc(id).set(data, SetOptions(merge: true));
    }
  }
}

class HospitalService {
  /// 病院情報のストリーム
  static Stream<DocumentSnapshot<Map<String, dynamic>>> stream(String hospitalId) {
    return _db.collection('hospitals').doc(hospitalId).snapshots();
  }
}

class ProgressService {
  static Future<void> addProgress({
    required String userId,
    required String exerciseId,
    required int count,
  }) {
    final col = _db.collection('users').doc(userId).collection('progress_records');
    return col.add({'exerciseId': exerciseId, 'count': count, 'ts': FieldValue.serverTimestamp()});
  }
}

class FeedbackService {
  static Future<void> addWeeklyFeedback({
    required String userId,
    required int pain,
    required int satisfaction,
  }) {
    final col = _db.collection('users').doc(userId).collection('progress_records');
    return col.add({'pain': pain, 'satisfaction': satisfaction, 'ts': FieldValue.serverTimestamp()});
  }
}