import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'app_common/app_theme.dart';

import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_ui_localizations/firebase_ui_localizations.dart';

import 'admin/pages/admin_dashboard_page.dart';
import 'admin/pages/elevate_to_admin_page.dart'; // ← これも作成済みか確認

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
      locale: const Locale('ja'),
      supportedLocales: const [Locale('ja'), Locale('en')],
      localizationsDelegates: const [
        FirebaseUILocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const _AdminHomeRouter(),
    );
  }
}

class _AdminHomeRouter extends StatefulWidget {
  const _AdminHomeRouter({super.key});
  @override
  State<_AdminHomeRouter> createState() => _AdminHomeRouterState();
}

class _AdminHomeRouterState extends State<_AdminHomeRouter> {
  fb.User? _user;
  bool? _isAdmin;

  @override
  void initState() {
    super.initState();
    fb.FirebaseAuth.instance.idTokenChanges().listen((u) async {
      _user = u;
      if (u == null) {
        setState(() => _isAdmin = null);
        return;
      }
      final token = await u.getIdTokenResult(true);
      setState(() => _isAdmin = token.claims?['admin'] == true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) return SignInScreen(providers: [EmailAuthProvider()]);
    if (_isAdmin == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    // 管理者でなければ「招待コード入力」へ
    return _isAdmin! ? const AdminDashboardPage() : const ElevateToAdminPage();
  }
}