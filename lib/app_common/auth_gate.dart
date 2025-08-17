import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
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
      // トークン（Custom Claims含む）が更新された時にも発火するストリーム
      stream: fb.FirebaseAuth.instance.idTokenChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null) {
          return SignInScreen(providers: [EmailAuthProvider()]);
        }

        return FutureBuilder<fb.IdTokenResult>(
          future: user.getIdTokenResult(),
          builder: (context, tokenSnapshot) {
            if (!tokenSnapshot.hasData) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            final claims = tokenSnapshot.data!.claims;
            final isAdmin = claims?['admin'] == true;

            if (adminOnly) {
              return isAdmin ? adminBuilder() : const _NoPermission();
            }
            return isAdmin ? adminBuilder() : patientBuilder();
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