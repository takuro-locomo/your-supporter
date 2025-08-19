import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:your_supporter/app_common/models.dart';
import 'package:your_supporter/app_common/services.dart';
import '../utils/video_upload_utils.dart';

class ExerciseManagerPage extends StatelessWidget {
  const ExerciseManagerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          title: const Text('エクササイズ管理'),
          trailing: FilledButton.icon(
            onPressed: () => showDialog(context: context, builder: (_) => const _AddExerciseDialog()),
            icon: const Icon(Icons.add),
            label: const Text('追加'),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: FutureBuilder<String?>(
            future: currentHid(),
            builder: (context, f) {
              if (!f.hasData) return const Center(child: CircularProgressIndicator());
              final hid = f.data!;
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: ExerciseService.streamExercisesOf(hid),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    print('ExerciseManager Error: ${snap.error}');
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error, size: 48, color: Colors.red),
                          const SizedBox(height: 16),
                          const Text('エクササイズの読み込みに失敗しました'),
                          const SizedBox(height: 8),
                          Text('エラー: ${snap.error}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    );
                  }
                  final docs = snap.data?.docs ?? [];
                  if (docs.isEmpty) return const Center(child: Text('エクササイズが未登録です'));
                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (_, i) {
                      final data = docs[i].data();
                      return ListTile(
                        title: Text(data['title'] ?? '(タイトル未設定)'),
                        subtitle: Text(data['description'] ?? ''),
                        trailing: const Icon(Icons.movie),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AddExerciseDialog extends StatefulWidget {
  const _AddExerciseDialog();

  @override
  State<_AddExerciseDialog> createState() => _AddExerciseDialogState();
}

class _AddExerciseDialogState extends State<_AddExerciseDialog> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  Uint8List? _bytes;
  String? _fileName;
  String? _filePath;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('エクササイズ追加'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'タイトル')),
            TextField(controller: _desc, decoration: const InputDecoration(labelText: '説明')),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _busy ? null : _pickVideo,
                  icon: const Icon(Icons.upload),
                  label: Text(_fileName ?? '動画ファイルを選択 (mp4等)'),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('キャンセル')),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('保存'),
        ),
      ],
    );
  }

  Future<void> _pickVideo() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.video,
      withData: kIsWeb, // ★ Webはbytesを取る
    );
    if (res != null && res.files.isNotEmpty) {
      final file = res.files.single;
      setState(() {
        _bytes = file.bytes;
        _fileName = file.name;
        _filePath = file.path; // モバイル用
      });
    }
  }

  Future<void> _save() async {
    if (_title.text.isEmpty || _fileName == null) return;
    setState(() => _busy = true);
    try {
      await saveExerciseWithUpload(
        title: _title.text,
        description: _desc.text,
        fileName: _fileName!,
        fileBytes: _bytes,
        filePath: _filePath,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('アップロードに失敗しました: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}