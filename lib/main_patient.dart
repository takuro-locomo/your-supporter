import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'app_common/app_theme.dart';
import 'app_common/auth_gate.dart';
import 'patient/pages/patient_home_page.dart';
import 'admin/pages/admin_dashboard_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const PatientApp());
}

class PatientApp extends StatelessWidget {
  const PatientApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'your supporter',
      theme: theme,
      home: AuthGate(
        adminOnly: false,
        patientBuilder: () => const PatientHomePage(),
        adminBuilder: () => const AdminDashboardPage(), // ロールがadminなら管理画面へ
      ),
    );
  }
}