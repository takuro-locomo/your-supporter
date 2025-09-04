import 'dart:io' show File;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'video_meta_stub.dart' if (dart.library.html) 'video_meta_web.dart';
import 'package:your_supporter/app_common/services.dart';
import 'package:cloud_functions/cloud_functions.dart';

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
  // 原本は uploads_raw に置く（サーバー側で720p変換→rehab_videosへ移動）
  final ref = FirebaseStorage.instance.ref('uploads_raw/$hid/$base');

  String url;
  String? thumbUrl;
  if (kIsWeb) {
    // Web: bytesを使用
    if (fileBytes == null) throw Exception('Webでは動画データが必要です');
    // Webのみ簡易メタ取得（ffprobe代替）。取得後、"最初のアップロード時のメタ" として付与する
    // finalize より後に updateMetadata するとレースするため、putData時に customMetadata を含める
    final metaMap = await probeVideoMetaWeb(fileBytes);
    final durationSec = (metaMap?["durationSec"] as num?)?.toDouble() ?? 0.0;
    if (durationSec > 120.0) {
      throw Exception('動画が長すぎます（最大2分）。現在: ${durationSec.toStringAsFixed(1)} 秒');
    }
    final meta = SettableMetadata(
      contentType: isMp4 ? 'video/mp4' : 'video/quicktime',
      customMetadata: {
        if (metaMap != null && metaMap['durationSec'] != null)
          'durationSec': metaMap['durationSec']!.toString(),
        if (metaMap != null && metaMap['height'] != null)
          'height': metaMap['height']!.toString(),
      },
    );
    await ref.putData(fileBytes, meta);
    url = await ref.getDownloadURL();
  } else {
    // モバイル: ファイルパスを使用
    if (filePath == null) throw Exception('モバイルでは動画ファイルパスが必要です');
    final meta = SettableMetadata(contentType: isMp4 ? 'video/mp4' : 'video/quicktime');
    await ref.putFile(File(filePath), meta);
    url = await ref.getDownloadURL();
  }

  // Firestoreに保存（MOVはwarningを付与）。最初は processing=true としておく
  await FirebaseFirestore.instance.collection('exercises').doc(exerciseId).set({
    'title': title,
    'description': description,
    'videoUrl': url, // 一時的に raw のURL（後でFunctionsが最終URLに差し替え）
    'hospitalId': hid,
    if (thumbUrl != null) 'thumbnailUrl': thumbUrl,
    'format': isMp4 ? 'mp4' : 'mov',
    if (!isMp4) 'warning': {'movFormat': true},
    'processing': true,
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  // 月間アップロード制限: 成功時にカウント（Functions側のトランザクションで検証）
  try {
    final fns = FirebaseFunctions.instanceFor(region: 'asia-northeast1');
    await fns.httpsCallable('assertExerciseUploadQuota').call();
  } catch (e) {
    // 失敗（上限超過）の場合は直近のアップロードを取り消す
    try { await FirebaseFirestore.instance.collection('exercises').doc(exerciseId).delete(); } catch (_) {}
    try { await ref.delete(); } catch (_) {}
    rethrow;
  }
}
