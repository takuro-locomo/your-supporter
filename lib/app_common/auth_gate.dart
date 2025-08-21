import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
      builder: (context, snap) {
        final user = snap.data;
        if (user == null) {
          return SignInScreen(providers: [EmailAuthProvider()]);
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
          builder: (context, usnap) {
            if (!usnap.hasData || !usnap.data!.exists) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            final role = usnap.data!.data()?['role'] as String?;
            if (role == 'hospital') return adminBuilder();
            if (role == 'patient') return patientBuilder();
            return const _RoleNotAssigned();
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

class _RoleNotAssigned extends StatelessWidget {
  const _RoleNotAssigned({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('ロールが未設定です。管理者にお問い合わせください。')),
    );
  }
}