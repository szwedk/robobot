#!/usr/bin/env bash
set -euo pipefail
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 unitree@<G1_IP>"
  exit 1
fi
TARGET="$1"
SRC="$(cd "$(dirname "$0")/.."; pwd)/"
rsync -avz \
  --exclude '.venv' \
  --exclude '__pycache__' \
  --exclude '.DS_Store' \
  --exclude 'models/*' \
  "$SRC" "${TARGET}:~/robobot/"
echo "Sync complete → ${TARGET}:~/robobot/"