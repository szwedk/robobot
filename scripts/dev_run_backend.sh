#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 -m venv .venv || true
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
export KOID_TOKEN=${KOID_TOKEN:-change-me}
uvicorn backend.server:app --host 0.0.0.0 --port 8000 --reload