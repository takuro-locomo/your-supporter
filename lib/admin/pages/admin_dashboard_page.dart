import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'exercise_manager_page.dart';
import 'patient_editor_page.dart';
import '../../app_common/services.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('your supporter（管理）'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut()),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 2,
            child: _PatientsPane(),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            flex: 3,
            child: const ExerciseManagerPage(),
          ),
        ],
      ),
    );
  }
}

class _PatientsPane extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: UserService.streamPatients(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        return Column(
          children: [
            ListTile(
              title: const Text('患者一覧'),
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  showDialog(context: context, builder: (_) => const PatientEditorPage());
                },
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final d = docs[i].data();
                  return ListTile(
                    title: Text(d['name'] ?? '(氏名未設定)'),
                    subtitle: Text('手術日: ${d['surgeryDate'] ?? '-'} / email: ${d['email'] ?? '-'}'),
                    onTap: () {
                      showDialog(context: context, builder: (_) => PatientEditorPage(userId: docs[i].id, initial: d));
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}