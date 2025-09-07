#!/usr/bin/env bash
set -euo pipefail

# 患者アプリを安定起動（専用Chromeプロファイル/固定ポート/TTY切断）
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PORT=5200
HOST=127.0.0.1
PROFILE_DIR="/tmp/ys_patient_profile_${PORT}"
LOG_FILE="/tmp/ys_patient_chrome_${PORT}.log"
PID_FILE="/tmp/ys_patient_chrome_${PORT}.pid"

mkdir -p "$PROFILE_DIR"

cd "$ROOT_DIR"

# 既存プロセス停止
pgrep -f "lib/main_patient.dart" | xargs -r kill -9 || true
lsof -tn -iTCP:${PORT} -sTCP:LISTEN | xargs -r kill -9 || true

# 依存取得
flutter pub get | cat

# 起動
nohup bash -lc "flutter run -d chrome \
  -t lib/main_patient.dart \
  --web-port=${PORT} \
  --web-hostname=${HOST} \
  --web-browser-flag=\"--user-data-dir=${PROFILE_DIR}\" \
  --web-browser-flag=\"--new-window\" \
  --web-browser-flag=\"--no-first-run\" \
  --web-browser-flag=\"--disable-extensions\" \
  </dev/null >> ${LOG_FILE} 2>&1" &
echo $! > "${PID_FILE}"

# ブラウザで開く
open -n "http://${HOST}:${PORT}" || true

echo "Patient app started on http://${HOST}:${PORT} (log: ${LOG_FILE})"


