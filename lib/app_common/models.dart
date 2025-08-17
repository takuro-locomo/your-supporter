class AppUser {
  final String uid;
  final String name;
  final String email;
  final String role; // "patient" or "admin"
  final DateTime? surgeryDate;

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.surgeryDate,
  });

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'name': name,
    'email': email,
    'role': role,
    'surgeryDate': surgeryDate?.toIso8601String(),
  };

  static AppUser fromMap(Map<String, dynamic> m) => AppUser(
    uid: m['uid'],
    name: m['name'] ?? '',
    email: m['email'] ?? '',
    role: m['role'] ?? 'patient',
    surgeryDate: m['surgeryDate'] != null ? DateTime.tryParse(m['surgeryDate']) : null,
  );
}

class Exercise {
  final String id;
  final String title;
  final String description;
  final String videoUrl;

  Exercise({
    required this.id,
    required this.title,
    required this.description,
    required this.videoUrl,
  });

  Map<String, dynamic> toMap() => {
    'title': title,
    'description': description,
    'videoUrl': videoUrl,
  };

  static Exercise fromMap(String id, Map<String, dynamic> m) => Exercise(
    id: id,
    title: m['title'] ?? '',
    description: m['description'] ?? '',
    videoUrl: m['videoUrl'] ?? '',
  );
}