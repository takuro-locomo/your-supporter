import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../app_common/ensure_user_doc.dart';

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
      final nav = Navigator.of(context);
      final fns = FirebaseFunctions.instanceFor(region: 'asia-northeast1');
      await fns.httpsCallable('joinHospitalByCode').call({'code': _code.text.trim()});
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
      // Firestoreからhidを引いて users/{uid} にrole/hospitalIdを確定保存
      final code = _code.text.trim();
      final hs = await FirebaseFirestore.instance
          .collection('hospitals')
          .where('joinCode', isEqualTo: code)
          .limit(1)
          .get();
      if (hs.docs.isNotEmpty) {
        final hid = hs.docs.first.id;
        await UserBootstrapService().ensureUserDoc(role: 'patient', hospitalId: hid);
      }
      if (!mounted) return;
      nav.pop();
    } on FirebaseFunctionsException catch (e) {
      setState(() => _msg = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
