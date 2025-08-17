import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthGate extends StatelessWidget {
  final Widget Function() patientBuilder;
  final Widget Function() adminBuilder;
  final bool adminOnly;

  const AuthGate({
    super.key,
    required this.patientBuilder,
    required this.adminBuilder,
    this.adminOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<fb.User?>(
      stream: fb.FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null) {
          return SignInScreen(providers: [EmailAuthProvider()],);
        }
        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
          builder: (context, snap) {
            if (!snap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
            final data = snap.data!.data() ?? {};
            final role = data['role'] ?? 'patient';
            if (adminOnly) {
              return role == 'admin' ? adminBuilder() : const _NoPermission();
            }
            return role == 'admin' ? adminBuilder() : patientBuilder();
          },
        );
      },
    );
  }
}

class _NoPermission extends StatelessWidget {
  const _NoPermission({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('権限がありません（管理者のみ）')),
    );
  }
}