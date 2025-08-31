import 'dart:io' show File;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;
import 'package:cloud_firestore/cloud_firestore.dart';
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
  final ext = p.extension(cleanFileName).toLowerCase();
  // 1) 拡張子チェック: mp4 推奨、movは警告（許容）
  final isMp4 = ext == '.mp4';
  final isMov = ext == '.mov' || ext == '.qt';
  if (!isMp4 && !isMov) {
    throw Exception('対応形式は mp4 または mov のみです（mp4推奨）');
  }
  // 先に exercises の docID を決めて、ファイル名に含める
  final docRef = FirebaseFirestore.instance.collection('exercises').doc();
  final exerciseId = id ?? docRef.id;
  final base = 'ex-$exerciseId-${DateTime.now().millisecondsSinceEpoch}$ext';
  final ref = FirebaseStorage.instance.ref('rehab_videos/$hid/$base');

  String url;
  String? thumbUrl;
  if (kIsWeb) {
    // Web: bytesを使用
    if (fileBytes == null) throw Exception('Webでは動画データが必要です');
    final meta = SettableMetadata(contentType: isMp4 ? 'video/mp4' : 'video/quicktime');
    await ref.putData(fileBytes, meta);
    url = await ref.getDownloadURL();
  } else {
    // モバイル: ファイルパスを使用
    if (filePath == null) throw Exception('モバイルでは動画ファイルパスが必要です');
    final meta = SettableMetadata(contentType: isMp4 ? 'video/mp4' : 'video/quicktime');
    await ref.putFile(File(filePath), meta);
    url = await ref.getDownloadURL();
  }

  // Firestoreに保存（MOVはwarningを付与）
  await FirebaseFirestore.instance.collection('exercises').doc(exerciseId).set({
    'title': title,
    'description': description,
    'videoUrl': url,
    'hospitalId': hid,
    if (thumbUrl != null) 'thumbnailUrl': thumbUrl,
    'format': isMp4 ? 'mp4' : 'mov',
    if (!isMp4) 'warning': {'movFormat': true},
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}
