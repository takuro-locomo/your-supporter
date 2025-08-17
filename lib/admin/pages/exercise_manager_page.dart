import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:your_supporter/app_common/models.dart';
import 'package:your_supporter/app_common/services.dart';

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
          child: StreamBuilder<List<Exercise>>(
            stream: ExerciseService.streamExercises(),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final items = snap.data!;
              if (items.isEmpty) return const Center(child: Text('未登録'));
              return ListView.builder(
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final ex = items[i];
                  return ListTile(
                    title: Text(ex.title),
                    subtitle: Text(ex.description),
                    trailing: const Icon(Icons.movie),
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
    final res = await FilePicker.platform.pickFiles(withData: true, type: FileType.video);
    if (res != null && res.files.isNotEmpty) {
      setState(() {
        _bytes = res.files.single.bytes;
        _fileName = res.files.single.name;
      });
    }
  }

  Future<void> _save() async {
    if (_bytes == null || _fileName == null || _title.text.isEmpty) return;
    setState(() => _busy = true);
    try {
      final ref = FirebaseStorage.instance.ref('rehab_videos/${DateTime.now().millisecondsSinceEpoch}_$_fileName');
      final task = await ref.putData(_bytes!, SettableMetadata(contentType: 'video/mp4'));
      final url = await task.ref.getDownloadURL();
      await ExerciseService.addOrUpdateExercise(title: _title.text, description: _desc.text, videoUrl: url);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('アップロードに失敗しました（権限/ルールをご確認ください）')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}