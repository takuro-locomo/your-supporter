import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'exercise_manager_page.dart';
import '../components/patients_panel.dart';
import 'hospital_setup_page.dart';
import '../../app_common/services.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<String?>(
          future: currentHid(),
          builder: (context, snap) {
            final hid = snap.data;
            if (hid == null) return const Text('your supporter（管理）');
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: HospitalService.stream(hid),
              builder: (context, docSnap) {
                final name = docSnap.data?.data()?['name'] ?? '';
                return Text(name.isEmpty ? 'your supporter（管理）' : '$name（管理）');
              },
            );
          },
        ),
        actions: [
          IconButton(
            tooltip: '病院設定',
            icon: const Icon(Icons.local_hospital_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HospitalSetupPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => fb.FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 2,
            child: const PatientsPanel(),
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

