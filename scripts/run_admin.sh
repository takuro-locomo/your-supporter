#!/usr/bin/env bash
set -euo pipefail

# Project root = this script's parent directory
cd "$(dirname "$0")/.."

PORT=5100
HOST=127.0.0.1
LOG=/tmp/ys_admin_run.log

echo "[run_admin] stopping old listeners on :$PORT if any..."
if lsof -n -iTCP:$PORT -sTCP:LISTEN >/dev/null 2>&1; then
  lsof -tn -iTCP:$PORT -sTCP:LISTEN | xargs -r kill -INT || true
  sleep 1
fi

echo "[run_admin] stopping previous flutter run processes..."
pgrep -f "lib/main_admin.dart.*$PORT" | xargs -r kill -INT || true
sleep 1

echo "[run_admin] starting flutter run... (log: $LOG)"
nohup bash -lc "flutter run -d chrome -t lib/main_admin.dart --web-port=$PORT --web-hostname=$HOST >$LOG 2>&1" >/dev/null 2>&1 &

echo "[run_admin] waiting for dev server to listen on :$PORT ..."
for i in {1..80}; do
  if lsof -n -iTCP:$PORT -sTCP:LISTEN >/dev/null 2>&1; then
    break
  fi
  sleep 0.25
done

echo "[run_admin] opening http://$HOST:$PORT/#/"
open "http://$HOST:$PORT/#/" || true
echo "[run_admin] done. (If page is blank, check $LOG)"


