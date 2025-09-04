import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_storage/firebase_storage.dart';
// import 'package:your_supporter/app_common/models.dart';
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
                      final thumb = data['thumbnailUrl'] as String?;
                      final warn = (data['warning'] as Map?)?.cast<String, dynamic>();
                      return ListTile(
                        leading: thumb == null
                            ? const Icon(Icons.movie)
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.network(thumb, width: 56, height: 56, fit: BoxFit.cover),
                              ),
                        title: Text(data['title'] ?? '(タイトル未設定)'),
                        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          if ((data['description'] ?? '').toString().isNotEmpty) Text(data['description']),
                          if (warn != null && (warn['overDuration'] == true || warn['overResolution'] == true))
                            Row(children: const [
                              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16),
                              SizedBox(width: 4),
                              Text('動画規約に違反の可能性（2分/720p超）', style: TextStyle(color: Colors.orange)),
                            ]),
                          if (warn != null && (warn['movFormat'] == true))
                            Row(children: const [
                              Icon(Icons.info_outline, color: Colors.blue, size: 16),
                              SizedBox(width: 4),
                              Text('MOVはブラウザ再生に不向き。mp4(H.264/AAC)推奨', style: TextStyle(color: Colors.blue)),
                            ]),
                          if (data['blocked'] == true)
                            Row(children: const [
                              Icon(Icons.block, color: Colors.red, size: 16),
                              SizedBox(width: 4),
                              Text('公開不可（規約違反）', style: TextStyle(color: Colors.red)),
                            ]),
                        ]),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            tooltip: 'プレビュー/編集',
                            icon: const Icon(Icons.play_circle_outline),
                            onPressed: () {
                              showDialog(context: context, builder: (_) => _PreviewEditDialog(
                                id: docs[i].id,
                                initial: data,
                              ));
                            },
                          ),
                          IconButton(
                            tooltip: '削除',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('削除確認'),
                                  content: const Text('この動画メニューを削除しますか？'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
                                    FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('削除')),
                                  ],
                                ),
                              );
                              if (ok != true) return;
                              // Firestore 削除
                              await FirebaseFirestore.instance.collection('exercises').doc(docs[i].id).delete();
                              // Storageも削除（可能なら）
                              final url = data['videoUrl'] as String?;
                              if (url != null && url.startsWith('https://storage.googleapis.com/')) {
                                try {
                                  await FirebaseStorage.instance.refFromURL(url).delete();
                                } catch (_) {}
                              }
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('削除しました')));
                              }
                            },
                          ),
                          const Icon(Icons.chevron_right),
                        ]),
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

class _PreviewEditDialog extends StatefulWidget {
  final String id; final Map<String, dynamic> initial;
  const _PreviewEditDialog({required this.id, required this.initial});
  @override State<_PreviewEditDialog> createState() => _PreviewEditDialogState();
}

class _PreviewEditDialogState extends State<_PreviewEditDialog> {
  late final TextEditingController _title;
  late final TextEditingController _desc;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.initial['title'] ?? '');
    _desc = TextEditingController(text: widget.initial['description'] ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.initial['videoUrl'] as String?;
    final size = MediaQuery.of(context).size;
    final maxW = size.width * 0.9;
    final maxH = size.height * 0.85;
    return AlertDialog(
      title: const Text('プレビュー / 編集'),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxW.clamp(360.0, 860.0),
          maxHeight: maxH.clamp(420.0, 980.0),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'タイトル')),
            TextField(controller: _desc, decoration: const InputDecoration(labelText: '説明')),
            const SizedBox(height: 8),
            if (url != null)
              Container(
                constraints: BoxConstraints(
                  // ダイアログ内でプレイヤーがはみ出さないよう最大サイズを指定
                  maxHeight: maxH * 0.6,
                  maxWidth: maxW * 0.9,
                ),
                alignment: Alignment.center,
                child: _VideoPreviewPlayer(url: url),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('閉じる')),
        FilledButton(
          onPressed: () async {
            await FirebaseFirestore.instance.collection('exercises').doc(widget.id).set({
              'title': _title.text,
              'description': _desc.text,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class _VideoPreviewPlayer extends StatefulWidget {
  final String url; const _VideoPreviewPlayer({required this.url});
  @override
  State<_VideoPreviewPlayer> createState() => _VideoPreviewPlayerState();
}

class _VideoPreviewPlayerState extends State<_VideoPreviewPlayer> {
  late final VideoPlayerController _controller =
      VideoPlayerController.networkUrl(Uri.parse(widget.url));
  bool _inited = false;
  bool _muted = true;

  @override
  void initState() {
    super.initState();
    () async {
      try {
        await _controller.setLooping(true);
        await _controller.setVolume(0.0); // Webの自動再生対策
        await _controller.initialize();
        await _controller.play();
        if (mounted) setState(() => _inited = true);
      } catch (_) {}
    }();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aspect = _inited
        ? (_controller.value.aspectRatio == 0 ? 16 / 9 : _controller.value.aspectRatio)
        : 16 / 9;
    return AspectRatio(
      aspectRatio: aspect,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_inited) VideoPlayer(_controller) else const Center(child: CircularProgressIndicator()),
          Positioned(
            bottom: 8,
            left: 8,
            child: Row(children: [
              IconButton(
                tooltip: _controller.value.isPlaying ? '一時停止' : '再生',
                icon: Icon(_controller.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, size: 32),
                onPressed: !_inited ? null : () {
                  setState(() {
                    _controller.value.isPlaying ? _controller.pause() : _controller.play();
                  });
                },
              ),
              IconButton(
                tooltip: _muted ? 'ミュート解除' : 'ミュート',
                icon: Icon(_muted ? Icons.volume_off : Icons.volume_up),
                onPressed: !_inited ? null : () async {
                  final next = !_muted;
                  await _controller.setVolume(next ? 1.0 : 0.0);
                  setState(() => _muted = !next);
                },
              ),
            ]),
          ),
        ],
      ),
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
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _pickVideo,
                  icon: const Icon(Icons.upload),
                  label: Text(_fileName ?? '動画ファイルを選択 (mp4のみ)'),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.amber.shade200)),
              child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('アップロードの注意', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('・再生の安定性のため mp4(H.264/AAC) のみ対応です。'),
                Text('・iPhoneで撮影した動画は mp4 への変換をお願いします。'),
                Text('・動画は最大2分・解像度は720pまでにしてください。'),
              ]),
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
    // クライアント側チェック: 拡張子・動画長・解像度（簡易）
    final lower = _fileName!.toLowerCase();
    if (!(lower.endsWith('.mp4') || lower.endsWith('.mov') || lower.endsWith('.qt'))) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('対応形式は mp4 / mov のみです（mp4推奨）')));
      }
      return;
    }
    // 長さ・解像度の厳密検証はアップロード後の運用で（ここでは事前注意のみ）
    setState(() => _busy = true);
    try {
      await saveExerciseWithUpload(
        title: _title.text,
        description: _desc.text,
        fileName: _fileName!,
        fileBytes: _bytes,
        filePath: _filePath,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('アップロードしました。動画は最大2分・720pまででお願いします。')));
      }
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