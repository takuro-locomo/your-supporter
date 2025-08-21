class AppUser {
  final String uid;
  final String email;
  final String name;          // 常に非null。未設定は空文字
  final String role;          // 未設定は 'patient'
  final String? birthDate;    // YYYY-MM-DD
  final String? hospitalId;   // HID
  final String? surgeryDate;  // YYYY-MM-DD
  final String? surgeryApproach;
  final String? surgerySide;

  AppUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    this.birthDate,
    this.hospitalId,
    this.surgeryDate,
    this.surgeryApproach,
    this.surgerySide,
  });

  factory AppUser.fromMap(Map<String, dynamic> m) {
    return AppUser(
      uid: (m['uid'] as String?) ?? '',
      email: (m['email'] as String?) ?? '',
      name: (m['name'] as String?) ?? '',
      role: (m['role'] as String?) ?? 'patient',
      birthDate: (m['birthDate'] as String?),
      hospitalId: (m['hospitalId'] as String?),
      surgeryDate: (m['surgeryDate'] as String?),
      surgeryApproach: (m['surgeryApproach'] as String?),
      surgerySide: (m['surgerySide'] as String?),
    );
  }

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'email': email,
    'name': name,
    'role': role,
    if (birthDate != null) 'birthDate': birthDate,
    if (hospitalId != null) 'hospitalId': hospitalId,
    if (surgeryDate != null) 'surgeryDate': surgeryDate,
    if (surgeryApproach != null) 'surgeryApproach': surgeryApproach,
    if (surgerySide != null) 'surgerySide': surgerySide,
  };
}

class Exercise {
  final String id;
  final String title;
  final String description;
  final String videoUrl;
  final String? thumbnailUrl;
  Exercise({required this.id,required this.title,required this.description,required this.videoUrl,this.thumbnailUrl});
  Map<String, dynamic> toMap() => {
    'title': title,
    'description': description,
    'videoUrl': videoUrl,
    if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
  };
  static Exercise fromMap(String id, Map<String, dynamic> m) => Exercise(
    id: id,
    title: m['title'] ?? '',
    description: m['description'] ?? '',
    videoUrl: m['videoUrl'] ?? '',
    thumbnailUrl: m['thumbnailUrl'] as String?,
  );
}

class ExercisePlan {
  final String id;
  final String exerciseId;
  final int targetCount;
  final List<int> daysOfWeek; // 1=Mon ... 7=Sun
  final bool active;

  ExercisePlan({
    required this.id,
    required this.exerciseId,
    required this.targetCount,
    required this.daysOfWeek,
    required this.active,
  });

  factory ExercisePlan.fromMap(String id, Map<String, dynamic> m) => ExercisePlan(
    id: id,
    exerciseId: m['exerciseId'] as String,
    targetCount: (m['targetCount'] ?? 0) as int,
    daysOfWeek: (m['daysOfWeek'] as List).map((e) => (e as num).toInt()).toList(),
    active: (m['active'] ?? true) as bool,
  );

  Map<String, dynamic> toMap() => {
    'exerciseId': exerciseId,
    'targetCount': targetCount,
    'daysOfWeek': daysOfWeek,
    'active': active,
  };
}