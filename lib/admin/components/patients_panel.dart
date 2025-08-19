import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:your_supporter/app_common/services.dart';

class PatientsPanel extends StatelessWidget {
  const PatientsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: currentHid(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final hid = snap.data!;
        print('PatientsPanel: Hospital ID = $hid'); // デバッグ出力
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: UserService.streamPatientsOf(hid),
          builder: (_, qs) {
            if (qs.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (qs.hasError) {
              print('PatientsPanel Error: ${qs.error}');
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text('患者一覧の読み込みに失敗しました'),
                    const SizedBox(height: 8),
                    Text('エラー: ${qs.error}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              );
            }
            final docs = qs.data?.docs ?? [];
            if (docs.isEmpty) return const Center(child: Text('患者がまだ登録されていません'));
            return ListView.separated(
              itemCount: docs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final d = docs[i].data();
                return ListTile(
                  title: Text(d['name'] ?? '(氏名未登録)'),
                  subtitle: Text([
                    '生年月日:${d['birthDate'] ?? '-'}',
                    '手術日:${d['surgeryDate'] ?? '-'}',
                    'アプローチ:${d['surgeryApproach'] ?? '-'}',
                    '左右:${d['surgerySide'] ?? '-'}',
                  ].join(' / ')),
                  onTap: () {
                    // 既存の患者編集画面へ遷移（実装済みの想定）
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
