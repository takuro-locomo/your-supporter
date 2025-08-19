import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:your_supporter/app_common/services.dart';
import 'package:your_supporter/app_common/models.dart';

import 'exercise_detail_page.dart';
import 'weekly_feedback_page.dart';
import 'profile_setup_page.dart';
import 'hospital_join_page.dart';

class PatientHomePage extends StatefulWidget {
  const PatientHomePage({super.key});
  @override
  State<PatientHomePage> createState() => _PatientHomePageState();
}

class _PatientHomePageState extends State<PatientHomePage> {
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    () async {
      await _ensureProfile();
      if (!mounted) return;
      await _ensureMembership();
      if (mounted) setState(() => _checking = false);
    }();
  }

  Future<void> _ensureProfile() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final u = await UserService.fetch(uid);
    if (u == null || u.name.isEmpty || (u.birthDate == null || u.birthDate!.isEmpty)) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileSetupPage()));
    }
  }

  Future<void> _ensureMembership() async {
    final token = await FirebaseAuth.instance.currentUser!.getIdTokenResult(true);
    final hid = token.claims?['hid'] as String?;
    if (hid == null || hid.isEmpty) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const HospitalJoinPage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('your supporter（患者）'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut()),
        ],
      ),
      body: FutureBuilder<String?>(
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
              if (snap.hasError) return Center(child: Text('読み込みに失敗しました: ${snap.error}'));
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) return const Center(child: Text('エクササイズが未登録です'));
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final data = docs[i].data();
                  final ex = Exercise.fromMap(docs[i].id, data);
                  return ListTile(
                    title: Text(ex.title),
                    subtitle: Text(ex.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExerciseDetailPage(exercise: ex))),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        label: const Text('週次フィードバック'),
        icon: const Icon(Icons.rate_review),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WeeklyFeedbackPage())),
      ),
    );
  }
}