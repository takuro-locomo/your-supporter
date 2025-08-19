import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:your_supporter/app_common/services.dart';

Future<void> saveExerciseWithUpload({
  String? id,
  required String title,
  required String description,
}) async {
  // ファイル選択
  final picked = await FilePicker.platform.pickFiles(type: FileType.video);
  if (picked == null || picked.files.single.path == null) return;

  final hid = await currentHid();
  final file = File(picked.files.single.path!);
  final filename = p.basename(file.path);

  // ★ 院ごとのフォルダに保存（Storage ルールに合わせる）
  final path = 'rehab_videos/$hid/$filename';
  final ref = FirebaseStorage.instance.ref(path);
  await ref.putFile(file);
  final url = await ref.getDownloadURL();

  await ExerciseService.addOrUpdateExercise(
    id: id,
    title: title,
    description: description,
    videoUrl: url,
    hospitalId: hid!,
  );
}
