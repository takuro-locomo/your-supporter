import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class HospitalSetupPage extends StatefulWidget {
  const HospitalSetupPage({super.key});
  @override
  State<HospitalSetupPage> createState() => _HospitalSetupPageState();
}

class _HospitalSetupPageState extends State<HospitalSetupPage> {
  final _name = TextEditingController();
  final _joinCode = TextEditingController();
  final _joinCode2 = TextEditingController();
  bool _busy = false;
  String? _msg;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('病院設定')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Align(alignment: Alignment.centerLeft, child: Text('新規作成', style: Theme.of(context).textTheme.titleMedium)),
            TextField(controller: _name, decoration: const InputDecoration(labelText: '病院名', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: _joinCode, decoration: const InputDecoration(labelText: '病院コード', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            FilledButton(onPressed: _busy ? null : _create, child: const Text('病院を作成して所属する')),
            const Divider(height: 32),
            Align(alignment: Alignment.centerLeft, child: Text('既存病院に参加', style: Theme.of(context).textTheme.titleMedium)),
            TextField(controller: _joinCode2, decoration: const InputDecoration(labelText: '病院コード', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            FilledButton(onPressed: _busy ? null : _join, child: const Text('病院に参加する')),
            if (_msg != null) ...[
              const SizedBox(height: 12),
              Text(_msg!, style: const TextStyle(color: Colors.red)),
            ]
          ],
        ),
      ),
    );
  }

  Future<void> _create() async {
    setState(() { _busy = true; _msg = null; });
    try {
      final fns = FirebaseFunctions.instanceFor(region: 'asia-northeast1');
      await fns.httpsCallable('createHospital').call({
        'name': _name.text.trim(),
        'joinCode': _joinCode.text.trim(),
      });
      await FirebaseAuth.instance.currentUser?.getIdToken(true); // claims 更新
      // AdminHomeRouterが自動でダッシュボードに遷移する
    } on FirebaseFunctionsException catch (e) {
      if (mounted) setState(() => _msg = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join() async {
    setState(() { _busy = true; _msg = null; });
    try {
      final fns = FirebaseFunctions.instanceFor(region: 'asia-northeast1');
      await fns.httpsCallable('joinHospitalByCode').call({'code': _joinCode2.text.trim()});
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
      // AdminHomeRouterが自動でダッシュボードに遷移する
    } on FirebaseFunctionsException catch (e) {
      if (mounted) setState(() => _msg = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
