import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:your_supporter/app_common/services.dart';

class WeeklyFeedbackPage extends StatefulWidget {
  const WeeklyFeedbackPage({super.key});

  @override
  State<WeeklyFeedbackPage> createState() => _WeeklyFeedbackPageState();
}

class _WeeklyFeedbackPageState extends State<WeeklyFeedbackPage> {
  double pain = 3;
  double satisfaction = 7;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('週次フィードバック')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _sliderTile('痛み（0-10）', pain, (v) => setState(() => pain = v)),
            const SizedBox(height: 16),
            _sliderTile('満足度（0-10）', satisfaction, (v) => setState(() => satisfaction = v)),
            const Spacer(),
            FilledButton(
              onPressed: () async {
                final uid = FirebaseAuth.instance.currentUser!.uid;
                await FeedbackService.addWeeklyFeedback(
                  userId: uid,
                  pain: pain.round(),
                  satisfaction: satisfaction.round(),
                );
                if (mounted) Navigator.pop(context);
              },
              child: const Text('送信'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sliderTile(String label, double value, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.toStringAsFixed(0)}'),
        Slider(min: 0, max: 10, divisions: 10, value: value, onChanged: onChanged),
      ],
    );
  }
}