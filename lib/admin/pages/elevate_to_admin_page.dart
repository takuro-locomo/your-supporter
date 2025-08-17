import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_dashboard_page.dart';

class ElevateToAdminPage extends StatefulWidget {
	const ElevateToAdminPage({super.key});

	@override
	State<ElevateToAdminPage> createState() => _ElevateToAdminPageState();
}

class _ElevateToAdminPageState extends State<ElevateToAdminPage> {
	final TextEditingController _codeController = TextEditingController();
	bool _submitting = false;
	String? _error;

	@override
	void dispose() {
		_codeController.dispose();
		super.dispose();
	}

	Future<void> _submit() async {
		final code = _codeController.text.trim();
		if (code.isEmpty) {
			setState(() => _error = '招待コードを入力してください');
			return;
		}
		setState(() {
			_submitting = true;
			_error = null;
		});

		try {
			final fns = FirebaseFunctions.instanceFor(region: 'asia-northeast1');
			final callable = fns.httpsCallable('elevateToAdmin');
			await callable.call({'code': code});

			// ★ クレーム反映
			await FirebaseAuth.instance.currentUser?.getIdToken(true);
			
			// デバッグ: Claims確認
			final r = await FirebaseAuth.instance.currentUser!.getIdTokenResult(true);
			debugPrint('claims: ${r.claims}'); // {admin: true} が見えればOK

			// ★ 成功したらダッシュボードに置き換え遷移
			if (mounted) {
				Navigator.pushAndRemoveUntil(
					context,
					MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
					(_) => false,
				);
			}
		} catch (e) {
			if (mounted) {
				setState(() => _error = '招待コードが無効です');
			}
		}
		
		if (mounted) {
			setState(() => _submitting = false);
		}
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
        title: const Text('管理者登録（招待コード）'),
        actions: [
          IconButton(
            tooltip: 'ログアウト',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
			body: Center(
				child: ConstrainedBox(
					constraints: const BoxConstraints(maxWidth: 420),
					child: Padding(
						padding: const EdgeInsets.all(24.0),
						child: Column(
							mainAxisAlignment: MainAxisAlignment.center,
							crossAxisAlignment: CrossAxisAlignment.stretch,
							children: [
								const Icon(Icons.admin_panel_settings, size: 72, color: Colors.blue),
								const SizedBox(height: 24),
								TextField(
									controller: _codeController,
									decoration: InputDecoration(
										labelText: '招待コード',
										border: const OutlineInputBorder(),
										errorText: _error,
									),
									obscureText: true,
									enabled: !_submitting,
									onSubmitted: (_) => _submit(),
								),
								const SizedBox(height: 16),
								ElevatedButton(
									onPressed: _submitting ? null : _submit,
									child: _submitting
										? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
										: const Text('管理者権限を取得'),
								),
							],
						),
					),
				),
			),
		);
	}
}