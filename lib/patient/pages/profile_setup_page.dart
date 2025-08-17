import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../app_common/services.dart';

class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({super.key});
  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final _name = TextEditingController();
  final _birth = TextEditingController(); // YYYY-MM-DD
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('プロフィール登録')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: '氏名', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(
              controller: _birth,
              readOnly: true,
              decoration: InputDecoration(
                labelText: '生年月日 (YYYY-MM-DD)',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(icon: const Icon(Icons.calendar_today), onPressed: _pickDate),
              ),
            ),
            const Spacer(),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy ? const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)) : const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 60), // 適当な初期値
      firstDate: DateTime(now.year - 120),
      lastDate: now,
    );
    if (picked != null) {
      _birth.text = "${picked.year.toString().padLeft(4,'0')}-${picked.month.toString().padLeft(2,'0')}-${picked.day.toString().padLeft(2,'0')}";
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _birth.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('氏名と生年月日を入力してください')));
      return;
    }
    setState(() => _busy = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await UserService.updateMyProfile(uid, name: _name.text.trim(), birthDate: _birth.text.trim());
      if (mounted) Navigator.pop(context); // 戻ってホームへ
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}