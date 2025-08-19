import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_ui_localizations/firebase_ui_localizations.dart';

import 'firebase_options.dart';
import 'admin/pages/admin_dashboard_page.dart';
import 'admin/pages/elevate_to_admin_page.dart';
import 'admin/pages/hospital_setup_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'your supporter（管理）',
      locale: const Locale('ja', 'JP'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FirebaseUILocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ja', 'JP'),
        Locale('en', 'US'),
      ],
      home: const AdminHomeRouter(),
    );
  }
}

class AdminHomeRouter extends StatefulWidget {
  const AdminHomeRouter({super.key});
  @override
  State<AdminHomeRouter> createState() => _AdminHomeRouterState();
}

class _AdminHomeRouterState extends State<AdminHomeRouter> {
  fb.User? _user;
  bool? _isAdmin;
  String? _hid;
  StreamSubscription<fb.User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = fb.FirebaseAuth.instance.idTokenChanges().listen((u) async {
      if (!mounted) return; // 👈 mounted チェック追加
      
      _user = u;
      if (u == null) { 
        if (mounted) setState(() { _isAdmin = null; _hid = null; }); 
        return; 
      }
      
      try {
        final token = await u.getIdTokenResult(true);
        final isAdmin = token.claims?['admin'] == true;
        final hid = token.claims?['hid'] as String?;
        
        // 🐛 デバッグ出力
        print('=== AdminHomeRouter Debug ===');
        print('User UID: ${u.uid}');
        print('Claims: ${token.claims}');
        print('isAdmin: $isAdmin (State: $_isAdmin)');
        print('hid: $hid (State: $_hid)');
        print('Will show: ${_getPageName(isAdmin, hid)}');
        print('=============================');
        
        if (mounted) {
          setState(() { 
            _isAdmin = isAdmin; 
            _hid = hid; 
          });
        }
      } catch (e) {
        print('Token取得エラー: $e');
        // Token取得エラーは無視（ログアウト時など）
        if (mounted) setState(() { _isAdmin = null; _hid = null; });
      }
    });
  }

  String _getPageName(bool? isAdmin, String? hid) {
    if (isAdmin == null) return 'Loading';
    if (isAdmin && (hid == null || hid.isEmpty)) return 'HospitalSetup';
    return isAdmin ? 'Dashboard' : 'ElevateToAdmin';
  }

  @override
  void dispose() {
    _authSubscription?.cancel(); // 👈 リスナーをキャンセル
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return SignInScreen(providers: [EmailAuthProvider()]);
    }
    if (_isAdmin == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // ★ 管理者だがHID未設定 → 病院設定へ
    if (_isAdmin! && (_hid == null || _hid!.isEmpty)) {
      return const HospitalSetupPage();
    }
    // 管理者ならダッシュボード、そうでなければ昇格ページ
    return _isAdmin! ? const AdminDashboardPage() : const ElevateToAdminPage();
  }
}