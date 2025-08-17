import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models.dart';

final _db = FirebaseFirestore.instance;

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

  static Stream<QuerySnapshot<Map<String, dynamic>>> streamPatients() {
    return _db.collection('users').where('role', isEqualTo: 'patient').snapshots();
  }

  // 患者自身のプロフィール更新（氏名・生年月日のみ）
  static Future<void> updateMyProfile(String uid, {required String name, required String birthDate}) {
    return _db.collection('users').doc(uid).set({
      'name': name,
      'birthDate': birthDate,
    }, SetOptions(merge: true));
  }

  // 管理者が手術情報を更新
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
  static Stream<List<Exercise>> streamExercises() => _db.collection('exercises')
      .snapshots().map((qs) => qs.docs.map((d) => Exercise.fromMap(d.id, d.data())).toList());

  static Future<void> addOrUpdateExercise({String? id, required String title, required String description, required String videoUrl}) async {
    final col = _db.collection('exercises');
    if (id == null) {
      await col.add({'title': title, 'description': description, 'videoUrl': videoUrl});
    } else {
      await col.doc(id).set({'title': title, 'description': description, 'videoUrl': videoUrl}, SetOptions(merge: true));
    }
  }
}

class ProgressService {
  static Future<void> addProgress({required String userId, required String exerciseId, required int count}) {
    final col = _db.collection('users').doc(userId).collection('progress_records');
    return col.add({'exerciseId': exerciseId, 'count': count, 'ts': FieldValue.serverTimestamp()});
  }
}

class FeedbackService {
  static Future<void> addWeeklyFeedback({required String userId, required int pain, required int satisfaction}) {
    final col = _db.collection('users').doc(userId).collection('weekly_feedback');
    return col.add({'pain': pain, 'satisfaction': satisfaction, 'ts': FieldValue.serverTimestamp()});
  }
}

class AdminService {
  static final _functions = FirebaseFunctions.instanceFor(region: 'asia-northeast1');

  /// 招待コードで管理者権限に昇格
  static Future<bool> elevateToAdmin(String inviteCode) async {
    try {
      final result = await _functions.httpsCallable('elevateToAdmin').call({
        'code': inviteCode,
      });
      
      // トークンを更新してCustom Claimsを反映
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
      
      return result.data['ok'] == true;
    } catch (e) {
      return false;
    }
  }

  /// ユーザー初期化（サインアップ後に呼び出し）
  static Future<bool> createUserDoc() async {
    try {
      final result = await _functions.httpsCallable('createUserDoc').call();
      return result.data['ok'] == true;
    } catch (e) {
      return false;
    }
  }
}