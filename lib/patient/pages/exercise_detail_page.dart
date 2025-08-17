import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:your_supporter/app_common/models.dart';
import 'package:your_supporter/app_common/services.dart';

class ExerciseDetailPage extends StatefulWidget {
  final Exercise exercise;
  const ExerciseDetailPage({super.key, required this.exercise});

  @override
  State<ExerciseDetailPage> createState() => _ExerciseDetailPageState();
}

class _ExerciseDetailPageState extends State<ExerciseDetailPage> {
  late VideoPlayerController _controller;
  final _countCtrl = TextEditingController(text: '10');

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.exercise.videoUrl))
      ..initialize().then((_) => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _countCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ex = widget.exercise;
    return Scaffold(
      appBar: AppBar(title: Text(ex.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_controller.value.isInitialized)
            AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            )
          else const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton(
                onPressed: () => _controller.play(),
                child: const Text('再生'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _controller.pause(),
                child: const Text('一時停止'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(ex.description),
          const Divider(height: 32),
          Row(
            children: [
              const Text('実施回数: '),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _countCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  final uid = FirebaseAuth.instance.currentUser!.uid;
                  final count = int.tryParse(_countCtrl.text) ?? 0;
                  await ProgressService.addProgress(
                    userId: uid,
                    exerciseId: ex.id,
                    count: count,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('記録しました')));
                  }
                },
                child: const Text('記録する'),
              ),
            ],
          )
        ],
      ),
    );
  }
}