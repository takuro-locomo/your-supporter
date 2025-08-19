import 'dart:io' show File;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;
import 'package:your_supporter/app_common/services.dart';

/// Web/モバイル対応の動画アップロード関数
Future<void> saveExerciseWithUpload({
  String? id,
  required String title,
  required String description,
  required String fileName,
  Uint8List? fileBytes,
  String? filePath,
}) async {
  final hid = await currentHid();
  if (hid == null) throw Exception('病院IDが取得できません');

  final cleanFileName = p.basename(fileName);
  final ref = FirebaseStorage.instance.ref('rehab_videos/$hid/$cleanFileName');

  String url;
  if (kIsWeb) {
    // Web: bytesを使用
    if (fileBytes == null) throw Exception('Webでは動画データが必要です');
    final meta = SettableMetadata(contentType: 'video/mp4');
    await ref.putData(fileBytes, meta);
    url = await ref.getDownloadURL();
  } else {
    // モバイル: ファイルパスを使用
    if (filePath == null) throw Exception('モバイルでは動画ファイルパスが必要です');
    await ref.putFile(File(filePath));
    url = await ref.getDownloadURL();
  }

  await ExerciseService.addOrUpdateExercise(
    id: id,
    title: title,
    description: description,
    videoUrl: url,
    hospitalId: hid,
  );
}
