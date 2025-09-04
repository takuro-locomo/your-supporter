import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  Timer? _safetyTimer;

  @override
  void initState() {
    super.initState();
    // フォールバック: 6秒経っても判定できない場合は非管理者として表示（無限ローディング回避）
    _safetyTimer = Timer(const Duration(seconds: 6), () {
      if (!mounted) return;
      if (_isAdmin == null) {
        setState(() { _isAdmin = false; });
      }
    });
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
        
        // 🐛 デバッグ出力（本番は抑制）
        // debugPrint('=== AdminHomeRouter Debug ===');
        // debugPrint('User UID: ${u.uid}');
        // debugPrint('Claims: ${token.claims}');
        // debugPrint('isAdmin: $isAdmin (State: $_isAdmin)');
        // debugPrint('hid: $hid (State: $_hid)');
        // debugPrint('Will show: ${_getPageName(isAdmin, hid)}');
        // debugPrint('=============================');
        
        if (mounted) {
          setState(() { 
            _isAdmin = isAdmin; 
            _hid = hid; 
          });
        }

        // フォールバック: claims に hid が無い/未反映のとき users/{uid} を参照
        if ((hid == null || hid.isEmpty) || _isAdmin == null) {
          try {
            final snap = await FirebaseFirestore.instance.collection('users').doc(u.uid).get();
            final data = snap.data();
            if (data != null) {
              final role = (data['role'] as String?) ?? '';
              final fhid = (data['hospitalId'] as String?) ?? '';
              if (mounted) {
                setState(() {
                  _isAdmin = role == 'admin';
                  if ((_hid == null || _hid!.isEmpty) && fhid.isNotEmpty) {
                    _hid = fhid;
                  }
                });
              }
            }
          } catch (_) {}
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
    _safetyTimer?.cancel();
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