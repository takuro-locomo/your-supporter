import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../app_common/models.dart';
import '../../app_common/services.dart';
import 'weekly_feedback_sheet.dart';
import 'package:fl_chart/fl_chart.dart';
import 'profile_setup_page.dart';
import 'hospital_join_page.dart';

class PatientHomePage extends StatefulWidget {
  const PatientHomePage({super.key});
  @override State<PatientHomePage> createState() => _PatientHomePageState();
}

class _PatientHomePageState extends State<PatientHomePage> {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    () async {
      await _ensureUserDoc();
      await _ensureProfile();
      if (!mounted) return;
      await _ensureMembership();
      if (mounted) setState(() => _checking = false);
    }();
  }

  Future<void> _ensureUserDoc() async {
    final auth = FirebaseAuth.instance.currentUser!;
    final existing = await UserService.fetch(auth.uid);
    if (existing == null) {
      await UserService.ensureUserDoc(AppUser(
        uid: auth.uid,
        name: auth.displayName ?? '',
        email: auth.email ?? '',
        role: 'patient',
      ));
    }
  }

  Future<void> _ensureProfile() async {
    final nav = Navigator.of(context);
    final u = await UserService.fetch(uid);
    if (!mounted) return;
    if (u == null || u.name.isEmpty || (u.birthDate == null || u.birthDate!.isEmpty)) {
      await nav.push(MaterialPageRoute(builder: (_) => const ProfileSetupPage()));
    }
  }

  Future<void> _ensureMembership() async {
    final nav = Navigator.of(context);
    final token = await FirebaseAuth.instance.currentUser!.getIdTokenResult(true);
    if (!mounted) return;
    final hid = token.claims?['hid'] as String?;
    if (hid == null || hid.isEmpty) {
      await nav.push(MaterialPageRoute(builder: (_) => const HospitalJoinPage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<String?>(
          future: currentHid(),
          builder: (context, hidSnap) {
            const base = 'your supporter 患者用アプリ';
            final hid = hidSnap.data;
            if (hid == null || hid.isEmpty) {
              return const Text(base);
            }
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: HospitalService.stream(hid),
              builder: (context, hsnap) {
                final name = hsnap.data?.data()?['name'] as String? ?? '';
                return Text(name.isEmpty ? base : '$base - $name');
              },
            );
          },
        ),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut()),
        ],
      ),
      body: FutureBuilder<AppUser?>(
        future: UserService.fetch(uid),
        builder: (_, uSnap) {
          final user = uSnap.data;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ProfileCard(user: user),
              const SizedBox(height: 12),
              _KPISection(uid: uid),
              const SizedBox(height: 12),
              _TodayMenu(uid: uid),
              const SizedBox(height: 12),
              _WeeklyProgress(uid: uid),
              const SizedBox(height: 12),
              _FeedbackSection(uid: uid),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final AppUser? user;
  const _ProfileCard({required this.user});
  @override
  Widget build(BuildContext context) {
    final sDate = user?.surgeryDate;
    final approach = user?.surgeryApproach ?? '-';
    final side = user?.surgerySide ?? '-';
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          const CircleAvatar(radius: 24, child: Icon(Icons.person)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              (user?.name != null && user!.name.isNotEmpty)
                  ? user!.name
                  : (user?.email ?? 'ユーザー'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text('手術日：${(sDate ?? '').isEmpty ? '-' : sDate!}  / アプローチ：$approach  / 側：$side',
              style: Theme.of(context).textTheme.bodySmall),
          ])),
        ]),
      ),
    );
  }
}

class _KPISection extends StatefulWidget {
  final String uid; const _KPISection({required this.uid});
  @override State<_KPISection> createState() => _KPISectionState();
}
class _KPISectionState extends State<_KPISection> {
  int? _streak; int? _achieved;
  double? _rateThisWeek; double? _rateLastWeek; double? _rate30;
  @override
  void initState() {
    super.initState();
    () async {
      _streak = await StatsService.currentStreakDays(widget.uid);
      _achieved = await StatsService.achievedDaysThisWeek(widget.uid);
      _rateThisWeek = await StatsService.achievementRateThisWeek(widget.uid);
      _rateLastWeek = await StatsService.achievementRateLastWeek(widget.uid);
      _rate30 = await StatsService.achievementRateLast30Days(widget.uid);
      if (mounted) setState(() {});
    }();
  }
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(children: [
        _chip('連続日数', (_streak ?? '-').toString(), Icons.local_fire_department_outlined),
        _chip('今週の達成日数', (_achieved ?? '-').toString(), Icons.calendar_today_outlined),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        _chip('今週達成率', _fmtRate(_rateThisWeek), Icons.task_alt_outlined),
        _chip('先週達成率', _fmtRate(_rateLastWeek), Icons.history_toggle_off),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        _chip('直近30日達成率', _fmtRate(_rate30), Icons.calendar_view_month),
        const Expanded(child: SizedBox()),
      ]),
    ]);
  }

  Widget _chip(String label, String value, IconData icon) {
    return Expanded(
      child: Card(
        child: ListTile(
          leading: Icon(icon),
          title: Text(value, style: Theme.of(context).textTheme.headlineSmall),
          subtitle: Text(label),
          dense: true,
        ),
      ),
    );
  }

  String _fmtRate(double? r) {
    if (r == null) return '-';
    return '${(r * 100).round()}%';
  }
}

class _TodayMenu extends StatelessWidget {
  final String uid; const _TodayMenu({required this.uid});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ExercisePlan>>(
      stream: PlanService.streamPlans(uid),
      builder: (_, pSnap) {
        final plans = pSnap.data ?? const <ExercisePlan>[];
        final todayPlans = plans.where(PlanService.runsToday).toList();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('今日のメニュー', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                if (plans.isNotEmpty)
                  Text('今週あと ${plans.map(PlanService.remainingDaysThisWeek).fold<int>(0, (p, e) => p + (e>0?1:0))} 日',
                    style: Theme.of(context).textTheme.bodySmall),
              ]),
              const SizedBox(height: 8),
              if (todayPlans.isEmpty) const Text('今日のメニューはありません。')
              else ...todayPlans.map((pl) => _PlanRow(uid: uid, plan: pl)),
            ]),
          ),
        );
      },
    );
  }
}

class _PlanRow extends StatelessWidget {
  final String uid; final ExercisePlan plan;
  const _PlanRow({required this.uid, required this.plan});

  Future<Exercise?> _fetchExercise(String id) async {
    final doc = await FirebaseFirestore.instance.collection('exercises').doc(id).get();
    if (!doc.exists) return null;
    return Exercise.fromMap(doc.id, doc.data()!);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Exercise?>(
      future: _fetchExercise(plan.exerciseId),
      builder: (_, eSnap) {
        final e = eSnap.data;
        final title = e?.title ?? 'エクササイズ';
        return ListTile(
          leading: const Icon(Icons.checklist),
          title: Text(title),
          subtitle: Text('目標 ${plan.targetCount} 回'),
          trailing: FilledButton(
            onPressed: () async {
              await ProgressService.addProgress(userId: uid, exerciseId: plan.exerciseId, count: plan.targetCount);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$title を ${plan.targetCount} 回 記録しました')));
              }
            },
            child: const Text('完了'),
          ),
        );
      },
    );
  }
}

class _FeedbackSection extends StatelessWidget {
  final String uid; const _FeedbackSection({required this.uid});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('週次フィードバック', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            OutlinedButton.icon(
              icon: const Icon(Icons.rate_review_outlined),
              label: const Text('送信する'),
              onPressed: () => showWeeklyFeedbackSheet(context, uid),
            ),
          ]),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FeedbackService.stream(uid),
            builder: (_, snap) {
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) return const Text('まだフィードバックはありません。');
              return Column(children: docs.map((d) {
                final m = d.data();
                final ts = (m['ts'] as Timestamp?)?.toDate();
                final when = ts == null ? '' : DateFormat('yyyy/MM/dd').format(ts);
                final w = (m['sinceOpWeek'] as num?)?.toInt();
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.event_note),
                  title: Text('術後 第${w ?? '-'}週（$when）'),
                  subtitle: Text('痛み ${m['pain']} / 満足度 ${m['satisfaction']}'),
                );
              }).toList());
            },
          ),
        ]),
      ),
    );
  }
}

class _WeeklyProgress extends StatefulWidget {
  final String uid; const _WeeklyProgress({required this.uid});
  @override
  State<_WeeklyProgress> createState() => _WeeklyProgressState();
}

class _WeeklyProgressState extends State<_WeeklyProgress> {
  List<int> _dailyCounts = List.filled(7, 0);
  int _total = 0;
  double _rate = 0; // 目標達成率（簡易: 実施日数/7）

  @override
  void initState() {
    super.initState();
    () async {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
      final qs = await FirebaseFirestore.instance
          .collection('users').doc(widget.uid)
          .collection('progress_records')
          .where('ts', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .get();
      final map = <int, int>{};
      for (final d in qs.docs) {
        final ts = (d['ts'] as Timestamp?)?.toDate();
        if (ts == null) continue;
        final dow = ts.weekday; // 1..7
        map[dow] = (map[dow] ?? 0) + 1;
      }
      _dailyCounts = List.generate(7, (i) => map[i + 1] ?? 0);
      _total = _dailyCounts.fold(0, (p, e) => p + e);
      final activeDays = _dailyCounts.where((c) => c > 0).length;
      _rate = activeDays / 7.0;
      if (mounted) setState(() {});
    }();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('今週のがんばり', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Text('達成日数 ${_dailyCounts.where((c)=>c>0).length}/7  ・ 合計実施 $_total回'),
            ]),
            const SizedBox(height: 8),
            SizedBox(
              height: 160,
              child: BarChart(
                BarChartData(
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: _bottomTitle)),
                  ),
                  barGroups: List.generate(7, (i) => BarChartGroupData(x: i, barRods: [
                    BarChartRodData(toY: _dailyCounts[i].toDouble(), width: 18, borderRadius: BorderRadius.circular(4)),
                  ])),
                ),
              ),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: _rate, minHeight: 8),
            const SizedBox(height: 4),
            Text(_rate >= 0.8 ? 'とてもよくできました！' : _rate >= 0.5 ? 'よくがんばっています！' : '少しずつ続けていきましょう'),
          ],
        ),
      ),
    );
  }

  Widget _bottomTitle(double value, TitleMeta meta) {
    const labels = ['月','火','水','木','金','土','日'];
    final idx = value.toInt();
    return SideTitleWidget(axisSide: meta.axisSide, child: Text(labels[idx]));
  }
}