// Only compiled on web
import 'dart:async';
import 'dart:html' as html;

Future<Map<String, num>?> probeVideoMetaWeb(List<int> bytes) async {
  try {
    final blob = html.Blob([bytes], 'video/mp4');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final video = html.VideoElement()
      ..src = url
      ..preload = 'metadata'
      ..muted = true;
    final completer = Completer<Map<String, num>?>();
    void cleanup() {
      html.Url.revokeObjectUrl(url);
      video.remove();
    }
    video.onLoadedMetadata.first.then((_) {
      final duration = video.duration.isFinite ? video.duration : 0;
      final h = video.videoHeight;
      final map = <String, num>{
        'durationSec': duration,
        'height': h,
      };
      cleanup();
      completer.complete(map);
    }).catchError((_) {
      cleanup();
      completer.complete(null);
    });
    // Timeout safety
    Future.delayed(const Duration(seconds: 5), () {
      if (!completer.isCompleted) {
        cleanup();
        completer.complete(null);
      }
    });
    return completer.future;
  } catch (_) {
    return null;
  }
}


