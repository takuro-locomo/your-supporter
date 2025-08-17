import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'app_common/app_theme.dart';
import 'app_common/auth_gate.dart';
import 'admin/pages/admin_dashboard_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'your supporter（admin）',
      theme: theme,
      home: const AuthGate(
        adminOnly: true,
        patientBuilder: _NoAccess.new,
        adminBuilder: AdminDashboardPage.new,
      ),
    );
  }
}

class _NoAccess extends StatelessWidget {
  const _NoAccess({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('管理者のみ')));
  }
}