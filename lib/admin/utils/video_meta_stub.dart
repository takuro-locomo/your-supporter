// Fallback (non-web): return null so that server-side check relies on defaults
Future<Map<String, num>?> probeVideoMetaWeb(List<int> bytes) async {
  return null;
}


