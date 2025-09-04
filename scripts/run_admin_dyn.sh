#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# stop previous
pgrep -f "lib/main_admin.dart" | xargs -r kill -9 || true
for p in 5100 5110 5120 5130 5170; do lsof -tn -iTCP:$p -sTCP:LISTEN | xargs -r kill -9 || true; done

LOG=/tmp/ys_admin_dyn4.log
nohup bash -lc 'flutter run -d web-server -t lib/main_admin.dart --web-hostname=127.0.0.1 --web-port=0 >'$LOG' 2>&1' >/dev/null 2>&1 &

# wait a moment then parse URL
for i in {1..40}; do
  URL=$(grep -m1 -Eo 'http://127\.0\.0\.1:[0-9]+' "$LOG" || true)
  if [ -n "$URL" ]; then echo "$URL"; exit 0; fi
  sleep 0.25
done
echo "(URL not found yet; see $LOG)"


