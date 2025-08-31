import 'package:flutter/material.dart';
import 'package:your_supporter/app_common/services.dart';

Future<void> showWeeklyFeedbackSheet(BuildContext context, String uid) async {
  double pain = 3;
  double satisfaction = 7;
  final memoCtrl = TextEditingController();
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 16, right: 16, top: 16,
        ),
        child: StatefulBuilder(
          builder: (ctx, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text('週次フィードバック'),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _sliderTile('痛み（0-10）', pain, (v) => setState(() => pain = v)),
              const SizedBox(height: 12),
              _sliderTile('満足度（0-10）', satisfaction, (v) => setState(() => satisfaction = v)),
              const SizedBox(height: 12),
              TextField(
                controller: memoCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '一言メモ（任意）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    await FeedbackService.addWeeklyFeedback(
                      userId: uid,
                      pain: pain.round(),
                      satisfaction: satisfaction.round(),
                      memo: memoCtrl.text.trim(),
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('送信'),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      );
    },
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


