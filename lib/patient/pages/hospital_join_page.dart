import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class HospitalJoinPage extends StatefulWidget {
  const HospitalJoinPage({super.key});
  @override
  State<HospitalJoinPage> createState() => _HospitalJoinPageState();
}

class _HospitalJoinPageState extends State<HospitalJoinPage> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _msg;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('病院に参加')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _code, decoration: const InputDecoration(labelText: '病院コード', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            FilledButton(onPressed: _busy ? null : _join, child: const Text('参加する')),
            if (_msg != null) ...[
              const SizedBox(height: 12),
              Text(_msg!, style: const TextStyle(color: Colors.red)),
            ]
          ],
        ),
      ),
    );
  }

  Future<void> _join() async {
    setState(() { _busy = true; _msg = null; });
    try {
      final fns = FirebaseFunctions.instanceFor(region: 'asia-northeast1');
      await fns.httpsCallable('joinHospitalByCode').call({'code': _code.text.trim()});
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
      if (mounted) Navigator.pop(context);
    } on FirebaseFunctionsException catch (e) {
      setState(() => _msg = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
