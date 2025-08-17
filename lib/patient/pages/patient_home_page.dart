import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../app_common/services.dart';
import '../../app_common/models.dart';
import 'exercise_detail_page.dart';
import 'weekly_feedback_page.dart';

class PatientHomePage extends StatelessWidget {
  const PatientHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('your supporter（患者）'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: StreamBuilder<List<Exercise>>(
        stream: ExerciseService.streamExercises(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final items = snap.data!;
          if (items.isEmpty) return const Center(child: Text('エクササイズが未登録です'));
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (_, i) {
              final ex = items[i];
              return ListTile(
                title: Text(ex.title),
                subtitle: Text(ex.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ExerciseDetailPage(exercise: ex)),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        label: const Text('週次フィードバック'),
        icon: const Icon(Icons.rate_review),
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const WeeklyFeedbackPage()));
        },
      ),
    );
  }
}