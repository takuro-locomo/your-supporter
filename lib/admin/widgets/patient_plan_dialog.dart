import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../app_common/models.dart';
import '../../app_common/services.dart';

class PatientPlanDialog extends StatefulWidget {
  final String patientUid;
  final String patientName;
  const PatientPlanDialog({super.key, required this.patientUid, required this.patientName});
  @override State<PatientPlanDialog> createState() => _PatientPlanDialogState();
}

class _PatientPlanDialogState extends State<PatientPlanDialog> {
  String? _selectedExerciseId;
  int _count = 10;
  final _days = <int>{1,3,5}; // 初期例：月水金

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Text('患者メニュー編集（${widget.patientName}）', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ]),
            const SizedBox(height: 12),
            // 既存プラン一覧
            SizedBox(
              height: 220,
              child: StreamBuilder<List<ExercisePlan>>(
                stream: PlanService.streamPlans(widget.patientUid),
                builder: (_, snap) {
                  final plans = snap.data ?? const <ExercisePlan>[];
                  if (plans.isEmpty) return const Center(child: Text('プランはまだありません'));
                  return ListView.separated(
                    itemCount: plans.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final p = plans[i];
                      return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        future: FirebaseFirestore.instance.collection('exercises').doc(p.exerciseId).get(),
                        builder: (_, eSnap) {
                          final title = eSnap.data?.data()?['title'] ?? 'エクササイズ';
                          return ListTile(
                            leading: const Icon(Icons.checklist),
                            title: Text(title),
                            subtitle: Text('回数 ${p.targetCount} / 曜日 ${_dowLabel(p.daysOfWeek)}'),
                            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                              IconButton(
                                tooltip: '停止',
                                onPressed: () => PlanService.update(
                                  uid: widget.patientUid, planId: p.id,
                                  targetCount: p.targetCount, daysOfWeek: p.daysOfWeek, active: false),
                                icon: const Icon(Icons.pause_circle_outline)),
                              IconButton(
                                tooltip: '削除',
                                onPressed: () => PlanService.remove(uid: widget.patientUid, planId: p.id),
                                icon: const Icon(Icons.delete_outline)),
                            ]),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(height: 24),
            // 新規作成
            Align(alignment: Alignment.centerLeft,
              child: Text('新規プランを追加', style: Theme.of(context).textTheme.titleMedium)),
            const SizedBox(height: 8),
            FutureBuilder<String?>(
              future: currentHid(),
              builder: (_, hidSnap) {
                if (!hidSnap.hasData) return const LinearProgressIndicator();
                final hid = hidSnap.data!;
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: ExerciseService.streamExercisesOf(hid),
                  builder: (_, exSnap) {
                    final docs = exSnap.data?.docs ?? [];
                    final list = docs.map((d) => Exercise.fromMap(d.id, d.data())).toList();
                    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'エクササイズ', border: OutlineInputBorder()),
                          value: _selectedExerciseId,
                          items: list.map((e) =>
                            DropdownMenuItem(value: e.id, child: Text(e.title))).toList(),
                          onChanged: (v) => setState(() => _selectedExerciseId = v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 160,
                        child: TextFormField(
                          decoration: const InputDecoration(labelText: '回数', border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                          initialValue: '$_count',
                          onChanged: (v) => _count = int.tryParse(v) ?? _count,
                        ),
                      ),
                    ]);
                  },
                );
              },
            ),
            const SizedBox(height: 8),
            _DowPicker(days: _days),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('追加'),
                onPressed: _selectedExerciseId == null ? null : () async {
                  await PlanService.create(
                    uid: widget.patientUid,
                    exerciseId: _selectedExerciseId!,
                    targetCount: _count,
                    daysOfWeek: _days.toList()..sort(),
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('プランを追加しました')));
                  }
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  static String _dowLabel(List<int> dows) {
    const jp = {1:'月',2:'火',3:'水',4:'木',5:'金',6:'土',7:'日'};
    return dows.map((d) => jp[d]).join('・');
  }
}

class _DowPicker extends StatefulWidget {
  final Set<int> days;
  const _DowPicker({required this.days});
  @override State<_DowPicker> createState() => _DowPickerState();
}
class _DowPickerState extends State<_DowPicker> {
  @override
  Widget build(BuildContext context) {
    const labels = ['月','火','水','木','金','土','日'];
    return Wrap(
      spacing: 6, children: List.generate(7, (i) {
        final d = i+1; final on = widget.days.contains(d);
        return FilterChip(
          label: Text(labels[i]), selected: on,
          onSelected: (_) => setState(() {
            on ? widget.days.remove(d) : widget.days.add(d);
          }),
        );
      }),
    );
  }
}
