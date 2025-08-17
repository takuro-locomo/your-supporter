import 'package:cloud_firestore/cloud_firestore.dart';
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
}

class ExerciseService {
  static Stream<List<Exercise>> streamExercises() {
    return _db.collection('exercises').snapshots().map((qs) =>
      qs.docs.map((d) => Exercise.fromMap(d.id, d.data())).toList());
  }

  static Future<void> addOrUpdateExercise({
    String? id,
    required String title,
    required String description,
    required String videoUrl,
  }) async {
    final col = _db.collection('exercises');
    if (id == null) {
      await col.add({'title': title, 'description': description, 'videoUrl': videoUrl});
    } else {
      await col.doc(id).set({'title': title, 'description': description, 'videoUrl': videoUrl}, SetOptions(merge: true));
    }
  }
}

class ProgressService {
  static Future<void> addProgress({
    required String userId,
    required String exerciseId,
    required int count,
  }) {
    final col = _db.collection('users').doc(userId).collection('progress_records');
    return col.add({
      'exerciseId': exerciseId,
      'count': count,
      'ts': FieldValue.serverTimestamp(),
    });
  }
}

class FeedbackService {
  static Future<void> addWeeklyFeedback({
    required String userId,
    required int pain,         // 0-10
    required int satisfaction, // 0-10
  }) {
    final col = _db.collection('users').doc(userId).collection('weekly_feedback');
    return col.add({
      'pain': pain,
      'satisfaction': satisfaction,
      'ts': FieldValue.serverTimestamp(),
    });
  }
}