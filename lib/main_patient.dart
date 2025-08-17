import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_ui_localizations/firebase_ui_localizations.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'firebase_options.dart';
import 'app_common/app_theme.dart';
import 'patient/pages/patient_home_page.dart';

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
      locale: const Locale('ja'),
      supportedLocales: const [Locale('ja'), Locale('en')],
      localizationsDelegates: const [
        FirebaseUILocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: StreamBuilder<fb.User?>(
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
              
              if (isAdmin) {
                return const _AdminNotAllowed(); // 管理者は患者用アプリ使用不可
              }
              return const PatientHomePage(); // 患者のみ
            },
          );
        },
      ),
    );
  }
}

class _AdminNotAllowed extends StatelessWidget {
  const _AdminNotAllowed({super.key});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.block,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            const Text(
              '管理者アカウントです',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '患者用アプリは使用できません\n管理者用アプリをご利用ください',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => fb.FirebaseAuth.instance.signOut(),
              icon: const Icon(Icons.logout),
              label: const Text('ログアウト'),
            ),
          ],
        ),
      ),
    );
  }
}