#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# stop previous patient runners
pgrep -f "lib/main_patient.dart" | xargs -r kill -9 || true

LOG=/tmp/ys_patient_dyn.log
nohup bash -lc 'flutter run -d web-server -t lib/main_patient.dart --web-hostname=127.0.0.1 --web-port=0 >'$LOG' 2>&1' >/dev/null 2>&1 &

# wait for the URL to appear
for i in {1..40}; do
  URL=$(grep -m1 -Eo 'http://127\.0\.0\.1:[0-9]+' "$LOG" || true)
  if [ -n "$URL" ]; then echo "$URL"; exit 0; fi
  sleep 0.25
done
echo "(URL not found yet; see $LOG)"


