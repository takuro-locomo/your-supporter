import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
// import '../../app_common/services.dart';

class PatientEditorPage extends StatefulWidget {
  final String? userId;
  final Map<String, dynamic>? initial;
  const PatientEditorPage({super.key, this.userId, this.initial});

  @override
  State<PatientEditorPage> createState() => _PatientEditorPageState();
}

class _PatientEditorPageState extends State<PatientEditorPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _birthDate = TextEditingController();
  final _surgeryDate = TextEditingController();
  String _surgeryApproach = '未設定';
  String _surgerySide = '未設定';
  String _role = 'patient';
  bool _busy = false;
  // KPI設定
  bool? _kpiShowThisWeek;
  bool? _kpiShowLastWeek;
  bool? _kpiShow30Days;
  double? _kpiTargetRate; // 0.0 .. 1.0

  @override
  void initState() {
    super.initState();
    final m = widget.initial ?? {};
    _name.text = m['name'] ?? '';
    _email.text = m['email'] ?? '';
    _birthDate.text = (m['birthDate'] ?? '');
    _surgeryDate.text = (m['surgeryDate'] ?? '');
    _surgeryApproach = (m['surgeryApproach'] ?? '未設定');
    _surgerySide = (m['surgerySide'] ?? '未設定');
    _role = m['role'] ?? 'patient';
    final kpi = (m['kpi'] as Map?)?.cast<String, dynamic>() ?? {};
    _kpiShowThisWeek = kpi['showThisWeekRate'] as bool?;
    _kpiShowLastWeek = kpi['showLastWeekRate'] as bool?;
    _kpiShow30Days = kpi['show30DayRate'] as bool?;
    final tgt = kpi['targetRate'];
    if (tgt is num) _kpiTargetRate = tgt.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.userId == null ? '患者情報（新規/編集）' : '患者情報編集'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _name, decoration: const InputDecoration(labelText: '氏名')),
              TextField(controller: _email, decoration: const InputDecoration(labelText: 'メール')),
              TextField(controller: _birthDate, decoration: const InputDecoration(labelText: '生年月日 (YYYY-MM-DD)')),
              const SizedBox(height: 12),
              const Divider(),
              Align(alignment: Alignment.centerLeft, child: Text('手術情報（患者側は編集不可）', style: Theme.of(context).textTheme.titleSmall)),
              TextField(
                controller: _surgeryDate,
                readOnly: true,
                decoration: const InputDecoration(labelText: '手術日 (YYYY-MM-DD)'),
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: now,
                    firstDate: DateTime(now.year - 5),
                    lastDate: DateTime(now.year + 1),
                  );
                  if (picked != null) {
                    setState(() => _surgeryDate.text = '${picked.year.toString().padLeft(4,'0')}-${picked.month.toString().padLeft(2,'0')}-${picked.day.toString().padLeft(2,'0')}');
                  }
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _surgeryApproach,
                decoration: const InputDecoration(labelText: 'アプローチ'),
                items: const [
                  DropdownMenuItem(value: '未設定', child: Text('未設定')),
                  DropdownMenuItem(value: '前方(DAA)', child: Text('前方(DAA)')),
                  DropdownMenuItem(value: '側方', child: Text('側方')),
                  DropdownMenuItem(value: '後方', child: Text('後方')),
                  DropdownMenuItem(value: 'その他', child: Text('その他')),
                ],
                onChanged: (v) => setState(() => _surgeryApproach = v ?? '未設定'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _surgerySide,
                decoration: const InputDecoration(labelText: '左右'),
                items: const [
                  DropdownMenuItem(value: '未設定', child: Text('未設定')),
                  DropdownMenuItem(value: '右', child: Text('右')),
                  DropdownMenuItem(value: '左', child: Text('左')),
                  DropdownMenuItem(value: '両側', child: Text('両側')),
                ],
                onChanged: (v) => setState(() => _surgerySide = v ?? '未設定'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _role,
                items: const [
                  DropdownMenuItem(value: 'patient', child: Text('患者')),
                  DropdownMenuItem(value: 'admin', child: Text('管理者')),
                ],
                onChanged: (v) => setState(() => _role = v ?? 'patient'),
                decoration: const InputDecoration(labelText: 'ロール'),
              ),
              const SizedBox(height: 12),
              const Divider(),
              Align(alignment: Alignment.centerLeft, child: Text('達成率の表示/目標（患者ごと）', style: TextStyle(fontWeight: FontWeight.bold))),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('今週達成率を表示'),
                value: _kpiShowThisWeek ?? true,
                onChanged: (v) => setState(() => _kpiShowThisWeek = v),
              ),
              SwitchListTile(
                title: const Text('先週達成率を表示'),
                value: _kpiShowLastWeek ?? true,
                onChanged: (v) => setState(() => _kpiShowLastWeek = v),
              ),
              SwitchListTile(
                title: const Text('直近30日達成率を表示'),
                value: _kpiShow30Days ?? true,
                onChanged: (v) => setState(() => _kpiShow30Days = v),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: Slider(
                  min: 0.5, max: 1.0, divisions: 5,
                  value: (_kpiTargetRate ?? 0.8).clamp(0.5, 1.0),
                  label: '${(((_kpiTargetRate ?? 0.8)*100).round())} %',
                  onChanged: (v) => setState(() => _kpiTargetRate = v),
                )),
                SizedBox(
                  width: 64,
                  child: Text('${(((_kpiTargetRate ?? 0.8)*100).round())}%', textAlign: TextAlign.right),
                ),
              ]),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('閉じる')),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy ? const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)) : const Text('保存'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final col = FirebaseFirestore.instance.collection('users');
      final data = {
        'name': _name.text,
        'email': _email.text,
        'birthDate': _birthDate.text.isEmpty ? null : _birthDate.text,
        'role': _role,
        'surgeryDate': _surgeryDate.text.isEmpty ? null : _surgeryDate.text,
        'surgeryApproach': _surgeryApproach,
        'surgerySide': _surgerySide,
      };
      if (widget.userId == null) {
        await col.add(data);
      } else {
        await col.doc(widget.userId!).set(data, SetOptions(merge: true));
        // KPI設定の保存
        await col.doc(widget.userId!).set({
          'kpi': {
            if (_kpiShowThisWeek != null) 'showThisWeekRate': _kpiShowThisWeek,
            if (_kpiShowLastWeek != null) 'showLastWeekRate': _kpiShowLastWeek,
            if (_kpiShow30Days != null) 'show30DayRate': _kpiShow30Days,
            if (_kpiTargetRate != null) 'targetRate': _kpiTargetRate,
          }
        }, SetOptions(merge: true));
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}