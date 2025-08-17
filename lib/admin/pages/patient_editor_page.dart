import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
  final _surgeryDate = TextEditingController();
  String _role = 'patient';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final m = widget.initial ?? {};
    _name.text = m['name'] ?? '';
    _email.text = m['email'] ?? '';
    _surgeryDate.text = (m['surgeryDate'] ?? '');
    _role = m['role'] ?? 'patient';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.userId == null ? '患者情報（新規/編集）' : '患者情報編集'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: '氏名')),
            TextField(controller: _email, decoration: const InputDecoration(labelText: 'メール')),
            TextField(controller: _surgeryDate, decoration: const InputDecoration(labelText: '手術日 (YYYY-MM-DD)')),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _role,
              items: const [
                DropdownMenuItem(value: 'patient', child: Text('患者')),
                DropdownMenuItem(value: 'admin', child: Text('管理者')),
              ],
              onChanged: (v) => setState(() => _role = v ?? 'patient'),
              decoration: const InputDecoration(labelText: 'ロール'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('閉じる')),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('保存'),
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
        'role': _role,
        'surgeryDate': _surgeryDate.text.isEmpty ? null : _surgeryDate.text,
      };
      if (widget.userId == null) {
        // 代理作成（認証ユーザは別途サインアップが必要）
        await col.add(data);
      } else {
        await col.doc(widget.userId!).set(data, SetOptions(merge: true));
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}