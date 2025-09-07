import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:your_supporter/app_common/services.dart';
import 'package:your_supporter/app_common/models.dart';
import '../widgets/patient_plan_dialog.dart';
import '../widgets/patient_feedback_dialog.dart';
import '../pages/patient_editor_page.dart';

class PatientsPanel extends StatelessWidget {
  const PatientsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: currentHid(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final hid = snap.data!;
        // debugPrint('PatientsPanel: Hospital ID = $hid');
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: UserService.streamPatientsOf(hid),
          builder: (_, qs) {
            if (qs.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (qs.hasError) {
              // debugPrint('PatientsPanel Error: ${qs.error}');
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text('患者一覧の読み込みに失敗しました'),
                    const SizedBox(height: 8),
                    Text('エラー: ${qs.error}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              );
            }
            final docs = qs.data?.docs ?? [];
            if (docs.isEmpty) return const Center(child: Text('患者がまだ登録されていません'));
            return ListView.separated(
              itemCount: docs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final d = docs[i].data();
                final user = AppUser(
                  uid: docs[i].id,
                  name: d['name'] ?? '',
                  email: d['email'] ?? '',
                  role: d['role'] ?? 'patient',
                  birthDate: d['birthDate'],
                  surgeryDate: d['surgeryDate'],
                  surgeryApproach: d['surgeryApproach'],
                  surgerySide: d['surgerySide'],
                );
                return ListTile(
                  title: Text(d['name'] ?? '(氏名未登録)'),
                  subtitle: Text([
                    '生年月日:${d['birthDate'] ?? '-'}',
                    '手術日:${d['surgeryDate'] ?? '-'}',
                    'アプローチ:${d['surgeryApproach'] ?? '-'}',
                    '左右:${d['surgerySide'] ?? '-'}',
                  ].join(' / ')),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      tooltip: '手術情報編集',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => PatientEditorPage(userId: user.uid, initial: d),
                      ),
                    ),
                    IconButton(
                      tooltip: '統計',
                      icon: const Icon(Icons.query_stats),
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => _StatsDialog(uid: user.uid, name: user.name.isNotEmpty ? user.name : (user.email.isNotEmpty ? user.email : '患者')),
                      ),
                    ),
                    IconButton(
                      tooltip: 'フィードバック',
                      icon: const Icon(Icons.event_note_outlined),
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => PatientFeedbackDialog(
                          patientUid: user.uid,
                          patientName: user.name.isNotEmpty ? user.name : (user.email.isNotEmpty ? user.email : '患者'),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'メニュー',
                      icon: const Icon(Icons.list_alt),
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => PatientPlanDialog(
                          patientUid: user.uid,
                          patientName: user.name.isNotEmpty ? user.name : (user.email.isNotEmpty ? user.email : '患者'),
                        ),
                      ),
                    ),
                    // 既存の編集ボタンなどがあればそのまま
                  ]),
                  onTap: () {
                    // 既存の患者編集画面へ遷移（実装済みの想定）
                  },
                );
              },
            );
          },
        );
      },
    );
  }

}

class _StatsDialog extends StatefulWidget {
  final String uid;
  final String name;
  const _StatsDialog({required this.uid, required this.name});
  @override
  State<_StatsDialog> createState() => _StatsDialogState();
}

class _StatsDialogState extends State<_StatsDialog> {
  int? _weekCount;
  int? _monthCount;
  double? _rateThisWeek; double? _rateLastWeek; double? _rate30;
  String _fmtRate(double? r) => r == null ? '-' : '${(r * 100).round()}%';
  @override
  void initState() {
    super.initState();
    () async {
      _weekCount = await VideoStatsService.playedCountSince(userId: widget.uid, days: 7);
      _monthCount = await VideoStatsService.playedCountSince(userId: widget.uid, days: 30);
      _rateThisWeek = await StatsService.achievementRateThisWeek(widget.uid);
      _rateLastWeek = await StatsService.achievementRateLastWeek(widget.uid);
      _rate30 = await StatsService.achievementRateLast30Days(widget.uid);
      if (mounted) setState(() {});
    }();
  }
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('視聴/実施サマリ（${widget.name}）'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.calendar_view_week),
              title: const Text('直近7日'),
              trailing: Text((_weekCount ?? '-').toString()),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('直近30日'),
              trailing: Text((_monthCount ?? '-').toString()),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.task_alt_outlined),
              title: const Text('今週達成率'),
              subtitle: _progressBar(_rateThisWeek ?? 0.0),
              trailing: Text(_fmtRate(_rateThisWeek)),
            ),
            ListTile(
              leading: const Icon(Icons.history_toggle_off),
              title: const Text('先週達成率'),
              subtitle: _progressBar(_rateLastWeek ?? 0.0),
              trailing: Text(_fmtRate(_rateLastWeek)),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_view_month),
              title: const Text('直近30日達成率'),
              subtitle: _progressBar(_rate30 ?? 0.0),
              trailing: Text(_fmtRate(_rate30)),
            ),
            const SizedBox(height: 8),
            const Text('※ 現状は「完了記録の件数」を集計。必要に応じて詳細化可', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('閉じる')),
      ],
    );
  }
}

Widget _progressBar(double value) {
  final v = value.clamp(0.0, 1.0);
  return Padding(
    padding: const EdgeInsets.only(top: 4.0),
    child: LinearProgressIndicator(value: v, minHeight: 6),
  );
}
