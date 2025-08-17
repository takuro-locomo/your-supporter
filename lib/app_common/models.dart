class AppUser {
  final String uid;
  final String name;         // 氏名
  final String email;
  final String role;         // "patient" | "admin"
  final String? birthDate;   // YYYY-MM-DD
  final String? surgeryDate;     // 手術日 YYYY-MM-DD（管理者のみ編集）
  final String? surgeryApproach; // アプローチ（管理者のみ）
  final String? surgerySide;     // 左右（管理者のみ）

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.birthDate,
    this.surgeryDate,
    this.surgeryApproach,
    this.surgerySide,
  });

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'name': name,
    'email': email,
    'role': role,
    'birthDate': birthDate,
    'surgeryDate': surgeryDate,
    'surgeryApproach': surgeryApproach,
    'surgerySide': surgerySide,
  };

  static AppUser fromMap(Map<String, dynamic> m) => AppUser(
    uid: m['uid'],
    name: m['name'] ?? '',
    email: m['email'] ?? '',
    role: m['role'] ?? 'patient',
    birthDate: m['birthDate'],
    surgeryDate: m['surgeryDate'],
    surgeryApproach: m['surgeryApproach'],
    surgerySide: m['surgerySide'],
  );
}

class Exercise {
  final String id;
  final String title;
  final String description;
  final String videoUrl;
  Exercise({required this.id,required this.title,required this.description,required this.videoUrl});
  Map<String, dynamic> toMap() => {'title': title,'description': description,'videoUrl': videoUrl};
  static Exercise fromMap(String id, Map<String, dynamic> m) =>
      Exercise(id: id, title: m['title'] ?? '', description: m['description'] ?? '', videoUrl: m['videoUrl'] ?? '');
}