import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:cloud_functions/cloud_functions.dart';
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
      await doc.set({
        'uid': user.uid,
        'email': user.email,
        'name': user.name.isEmpty ? '' : user.name,
        'role': (user.role.isEmpty ? 'patient' : user.role),
        'birthDate': user.birthDate,
        'hospitalId': user.hospitalId,
        'surgeryDate': user.surgeryDate,
        'surgeryApproach': user.surgeryApproach,
        'surgerySide': user.surgerySide,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
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
    String? thumbnailUrl,
  }) async {
    final data = {
      'title': title,
      'description': description,
      'videoUrl': videoUrl,
      'hospitalId': hospitalId,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
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

class VideoStatsService {
  /// 動画再生開始時に回数をインクリメント
  static Future<void> incrementPlay({required String userId, required String exerciseId}) async {
    final ref = _db.collection('users').doc(userId).collection('video_stats').doc(exerciseId);
    await ref.set({
      'playCount': FieldValue.increment(1),
      'lastPlayedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// 直近n日分のサマリを取得（playCount 合計）
  static Future<int> playedCountSince({required String userId, required int days}) async {
    final since = DateTime.now().subtract(Duration(days: days));
    // 簡易実装: video_stats は累積なので差分は別途。ここではprogress_records件数で代替も可能
    final qs = await _db.collection('users').doc(userId)
      .collection('progress_records')
      .where('ts', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
      .get();
    return qs.docs.length;
  }
}

class FeedbackService {
  /// 術後第N週を付与して週次フィードバックを保存
  static Future<void> addWeeklyFeedback({
    required String userId,
    required int pain,
    required int satisfaction,
  }) async {
    DateTime? surgery;
    final userDoc = await _db.collection('users').doc(userId).get();
    if (userDoc.exists) {
      final s = userDoc.data()!['surgeryDate'];
      if (s is String && s.isNotEmpty) {
        surgery = DateTime.tryParse(s);
      }
    }
    int? sinceOpWeek;
    if (surgery != null) {
      final diff = DateTime.now()
          .difference(DateTime(surgery.year, surgery.month, surgery.day))
          .inDays;
      sinceOpWeek = (diff ~/ 7) + 1; // 1始まり
    }

    final col = _db.collection('users').doc(userId).collection('weekly_feedback');
    await col.add({
      'pain': pain,
      'satisfaction': satisfaction,
      'sinceOpWeek': sinceOpWeek,
      'ts': FieldValue.serverTimestamp(),
    });
  }

  /// 週次フィードバックのストリーム（新しい順）
  static Stream<QuerySnapshot<Map<String, dynamic>>> stream(String uid) =>
      _db
          .collection('users')
          .doc(uid)
          .collection('weekly_feedback')
          .orderBy('ts', descending: true)
          .snapshots();
}

/// エクササイズプラン管理（管理UI用CRUD追加）
class PlanService {
  static Stream<List<ExercisePlan>> streamPlans(String uid) => _db
      .collection('users').doc(uid).collection('plans')
      .where('active', isEqualTo: true)
      .snapshots()
      .map((qs) => qs.docs.map((d) => ExercisePlan.fromMap(d.id, d.data())).toList());

  static Future<void> create({
    required String uid,
    required String exerciseId,
    required int targetCount,
    required List<int> daysOfWeek,
    bool active = true,
  }) => _db.collection('users').doc(uid).collection('plans').add({
        'exerciseId': exerciseId,
        'targetCount': targetCount,
        'daysOfWeek': daysOfWeek,
        'active': active,
      });

  static Future<void> update({
    required String uid,
    required String planId,
    required int targetCount,
    required List<int> daysOfWeek,
    bool? active,
  }) => _db.collection('users').doc(uid).collection('plans').doc(planId).set({
        'targetCount': targetCount,
        'daysOfWeek': daysOfWeek,
        if (active != null) 'active': active,
      }, SetOptions(merge: true));

  static Future<void> remove({required String uid, required String planId}) =>
      _db.collection('users').doc(uid).collection('plans').doc(planId).delete();

  static bool runsToday(ExercisePlan p) {
    final dow = DateTime.now().weekday; // 1=Mon..7=Sun
    return p.daysOfWeek.contains(dow);
  }

  static int remainingDaysThisWeek(ExercisePlan p) {
    final today = DateTime.now();
    final int dow = today.weekday; // 1=Mon..7=Sun
    int rem = 0;
    for (int d = dow; d <= 7; d++) {
      if (p.daysOfWeek.contains(d)) rem++;
    }
    return rem; // 今日を含む残り日数
  }
}

class StatsService {
  /// 直近90日の記録から連続日数を計算
  static Future<int> currentStreakDays(String uid) async {
    final since = DateTime.now().subtract(const Duration(days: 90));
    final qs = await _db
        .collection('users')
        .doc(uid)
        .collection('progress_records')
        .where('ts', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .orderBy('ts', descending: true)
        .get();

    final days = <DateTime>{};
    for (final d in qs.docs) {
      final dt = (d['ts'] as Timestamp).toDate();
      days.add(DateTime(dt.year, dt.month, dt.day));
    }

    int streak = 0;
    DateTime cur = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    while (days.contains(cur)) {
      streak++;
      cur = cur.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// 今週の達成日数（重複なしの日数）
  static Future<int> achievedDaysThisWeek(String uid) async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1)); // 月曜はじまり
    final qs = await _db
        .collection('users')
        .doc(uid)
        .collection('progress_records')
        .where(
          'ts',
          isGreaterThanOrEqualTo: Timestamp.fromDate(
            DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
          ),
        )
        .get();

    final days = <String>{};
    for (final d in qs.docs) {
      final dt = (d['ts'] as Timestamp).toDate();
      days.add(DateFormat('yyyy-MM-dd').format(dt));
    }
    return days.length;
  }

  /// 指定期間の「プラン日数」と「達成日数（進捗があった日）」を集計
  static Future<(int planDays, int achievedDays)> _planVsAchievedInRange({
    required String uid,
    required DateTime start,
    required DateTime end,
  }) async {
    // 1) プラン日（activeのみ）
    final plansSnap = await _db.collection('users').doc(uid)
        .collection('plans').where('active', isEqualTo: true).get();
    final Set<int> dows = {}; // 期間内で対象となる曜日集合
    // 期間内の各日で、当該日の曜日がプランに含まれていればプラン日
    final int daysSpan = end.difference(start).inDays + 1;
    int planDays = 0;
    for (int i = 0; i < daysSpan; i++) {
      final day = DateTime(start.year, start.month, start.day).add(Duration(days: i));
      final dow = day.weekday; // 1..7
      bool isPlanDay = false;
      for (final p in plansSnap.docs) {
        final list = (p.data()['daysOfWeek'] as List? ?? []).map((e) => (e as num).toInt()).toList();
        if (list.contains(dow)) { isPlanDay = true; break; }
      }
      if (isPlanDay) planDays++;
      dows.add(dow);
    }

    // 2) 達成日（progress_recordsが1件以上記録された日）
    final prog = await _db.collection('users').doc(uid)
        .collection('progress_records')
        .where('ts', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('ts', isLessThan: Timestamp.fromDate(end.add(const Duration(days: 1))))
        .get();
    final achievedDates = <String>{};
    for (final d in prog.docs) {
      final ts = (d['ts'] as Timestamp?)?.toDate();
      if (ts == null) continue;
      final s = DateFormat('yyyy-MM-dd').format(ts);
      achievedDates.add(s);
    }

    // 3) プラン日に限定した達成日数
    int achievedOnPlanDays = 0;
    for (final s in achievedDates) {
      final dt = DateTime.parse(s);
      if (dt.isBefore(start) || dt.isAfter(end)) continue;
      // その日の曜日が、いずれかのプランのdaysOfWeekに含まれていれば達成日とカウント
      final dow = dt.weekday;
      bool isPlanDay = false;
      for (final p in plansSnap.docs) {
        final list = (p.data()['daysOfWeek'] as List? ?? []).map((e) => (e as num).toInt()).toList();
        if (list.contains(dow)) { isPlanDay = true; break; }
      }
      if (isPlanDay) achievedOnPlanDays++;
    }

    return (planDays, achievedOnPlanDays);
  }

  static Future<double> achievementRateThisWeek(String uid) async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final start = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    final end = start.add(const Duration(days: 6));
    final (planDays, achievedDays) = await _planVsAchievedInRange(uid: uid, start: start, end: end);
    if (planDays == 0) return 0.0;
    return achievedDays / planDays;
  }

  static Future<double> achievementRateLastWeek(String uid) async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final thisStart = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    final start = thisStart.subtract(const Duration(days: 7));
    final end = thisStart.subtract(const Duration(days: 1));
    final (planDays, achievedDays) = await _planVsAchievedInRange(uid: uid, start: start, end: end);
    if (planDays == 0) return 0.0;
    return achievedDays / planDays;
  }

  static Future<double> achievementRateLast30Days(String uid) async {
    final end = DateTime.now();
    final start = end.subtract(const Duration(days: 29));
    final (planDays, achievedDays) = await _planVsAchievedInRange(uid: uid, start: DateTime(start.year, start.month, start.day), end: DateTime(end.year, end.month, end.day));
    if (planDays == 0) return 0.0;
    return achievedDays / planDays;
  }
}

class AdminService {
  /// 招待コードで管理者権限に昇格
  static Future<bool> elevateToAdmin(String inviteCode) async {
    final fn = FirebaseFunctions.instanceFor(region: 'asia-northeast1')
        .httpsCallable('elevateToAdmin');
    final res = await fn.call({'inviteCode': inviteCode});
    final data = res.data;
    if (data is Map && data['ok'] == true) return true;
    return false;
  }
}