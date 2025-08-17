import 'package:flutter/material.dart';
import '../../app_common/services.dart';

class AdminInvitePage extends StatefulWidget {
  const AdminInvitePage({super.key});

  @override
  State<AdminInvitePage> createState() => _AdminInvitePageState();
}

class _AdminInvitePageState extends State<AdminInvitePage> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submitInviteCode() async {
    final code = _controller.text.trim();
    if (code.isEmpty) {
      setState(() => _errorMessage = '招待コードを入力してください');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final success = await AdminService.elevateToAdmin(code);
      if (mounted) {
        if (success) {
          // 成功時は画面を閉じてメイン画面に戻る
          Navigator.of(context).pop();
        } else {
          setState(() => _errorMessage = '招待コードが無効です');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'エラーが発生しました: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('管理者登録'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.admin_panel_settings,
              size: 80,
              color: Colors.blue,
            ),
            const SizedBox(height: 32),
            const Text(
              '管理者権限の取得',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              '管理者から提供された招待コードを入力してください',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: '招待コード',
                border: const OutlineInputBorder(),
                errorText: _errorMessage,
              ),
              obscureText: true,
              enabled: !_loading,
              onSubmitted: (_) => _submitInviteCode(),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading ? null : _submitInviteCode,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('管理者権限を取得'),
            ),
          ],
        ),
      ),
    );
  }
}