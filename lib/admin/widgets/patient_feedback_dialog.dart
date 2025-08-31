import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../app_common/services.dart';

class PatientFeedbackDialog extends StatelessWidget {
  final String patientUid;
  final String patientName;
  const PatientFeedbackDialog({super.key, required this.patientUid, required this.patientName});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Text('週次フィードバック（$patientName）', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ]),
              const SizedBox(height: 12),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FeedbackService.stream(patientUid),
                  builder: (_, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snap.data?.docs ?? [];
                    if (docs.isEmpty) return const Center(child: Text('まだフィードバックはありません'));
                    return ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final m = docs[i].data();
                        final memo = (m['memo'] as String?) ?? '';
                        final ts = (m['ts'] as Timestamp?)?.toDate();
                        final when = ts == null ? '' : '${ts.year}/${ts.month}/${ts.day}';
                        return ListTile(
                          leading: const Icon(Icons.event_note),
                          title: Text('術後 第${m['sinceOpWeek'] ?? '-'}週（$when）'),
                          subtitle: Text('痛み ${m['pain']}・満足度 ${m['satisfaction']}${memo.isNotEmpty ? '・メモ: $memo' : ''}'),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


