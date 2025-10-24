#!/usr/bin/env bash
set -euo pipefail

# --- Config (you can change these defaults) ------------------------------
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PYTHON_BIN="${PYTHON_BIN:-python3}"
VENV_DIR="${PROJECT_ROOT}/.venv"
PORT="${PORT:-8000}"
KOID_TOKEN="${KOID_TOKEN:-change-me}"

# Piper voice choices (model + json live under models/)
declare -A VOICE_URLS=(
  # High quality male (bigger)
  ["en_US-ryan-high.onnx"]="https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/ryan/high/en_US-ryan-high.onnx"
  ["en_US-ryan-high.onnx.json"]="https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/ryan/high/en_US-ryan-high.onnx.json"

  # Medium female (smaller, faster)
  ["en_US-amy-medium.onnx"]="https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/amy/medium/en_US-amy-medium.onnx"
  ["en_US-amy-medium.onnx.json"]="https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/amy/medium/en_US-amy-medium.onnx.json"
)
DEFAULT_MODEL="en_US-ryan-high"   # or: en_US-amy-medium
# ------------------------------------------------------------------------

echo "==> macOS setup for robobot at: ${PROJECT_ROOT}"

cd "${PROJECT_ROOT}"

# 1) Ensure Homebrew (for ffmpeg) and base tools
if ! command -v brew >/dev/null 2>&1; then
  echo "==> Homebrew not found. Installing Homebrew (requires Xcode Command Line Tools)…"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  echo "=> After install, open a new shell or eval the Brew env line it prints."
fi

echo "==> Ensuring audio playback tools"
brew list ffmpeg >/dev/null 2>&1 || brew install ffmpeg
# macOS already has 'afplay'; ffplay from ffmpeg is our fallback.

# 2) Python venv + dependencies
if [[ ! -d "${VENV_DIR}" ]]; then
  echo "==> Creating venv at ${VENV_DIR}"
  "${PYTHON_BIN}" -m venv "${VENV_DIR}"
fi
# shellcheck disable=SC1090
source "${VENV_DIR}/bin/activate"

echo "==> Upgrading pip"
pip install --upgrade pip

echo "==> Installing Python dependencies"
if [[ ! -f requirements.txt ]]; then
  echo "fastapi
uvicorn[standard]
pydantic==1.*
piper-tts
python-dotenv" > requirements.txt
fi
pip install -r requirements.txt

# 3) Prepare models/ and let user choose a voice
mkdir -p "${PROJECT_ROOT}/models"
echo "==> Available voices:"
echo "   1) en_US-ryan-high (larger, higher quality)"
echo "   2) en_US-amy-medium (smaller, faster)"
read -r -p "Select voice [1/2] (default 1): " CHOICE
CHOICE="${CHOICE:-1}"
case "$CHOICE" in
  2) MODEL_NAME="en_US-amy-medium" ;;
  *) MODEL_NAME="${DEFAULT_MODEL}" ;;
esac

MODEL_ONNX="${MODEL_NAME}.onnx"
MODEL_JSON="${MODEL_NAME}.onnx.json"

download_if_missing () {
  local filename="$1"
  local url="$2"
  local dest="${PROJECT_ROOT}/models/${filename}"
  if [[ -f "$dest" ]]; then
    echo "==> ${filename} already exists"
  else
    echo "==> Downloading ${filename}"
    curl -L -o "$dest" "$url"
  fi
}

echo "==> Fetching Piper voice model: ${MODEL_NAME}"
download_if_missing "${MODEL_ONNX}" "${VOICE_URLS[${MODEL_ONNX}]}"
download_if_missing "${MODEL_JSON}" "${VOICE_URLS[${MODEL_JSON}]}"

# 4) Quick audio sanity check (Piper -> WAV -> afplay/ffplay)
echo "==> Running Piper sanity check"
echo "Koid online. Hello from RoboStore." | piper \
  --model "${PROJECT_ROOT}/models/${MODEL_ONNX}" \
  --config "${PROJECT_ROOT}/models/${MODEL_JSON}" \
  --output_file /tmp/koid_check.wav
if command -v afplay >/dev/null 2>&1; then
  afplay /tmp/koid_check.wav || true
else
  ffplay -autoexit -nodisp -loglevel quiet /tmp/koid_check.wav || true
fi

# 5) Seed minimal frontend if missing
if [[ ! -f frontend/index.html ]]; then
  echo "==> Seeding frontend/"
  mkdir -p frontend/assets
  cat > frontend/index.html <<'HTML'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1,user-scalable=no"/>
<title>Koid — Soundboard</title>
<link rel="stylesheet" href="assets/app.css"/>
</head>
<body>
  <h2>Koid — Unitree G1 (RoboStore)</h2>
  <div class="row">
    <input id="customText" placeholder="Type phrase…"/>
    <button id="speakBtn">Speak</button>
  </div>
  <h3>Soundboard</h3>
  <div id="phrases" class="grid"></div>
  <h3>Emotes</h3>
  <div id="emotes" class="grid"></div>
  <script src="assets/app.js"></script>
</body>
</html>
HTML

  cat > frontend/assets/app.css <<'CSS'
body { font-family: system-ui, -apple-system; margin:16px; }
h2 { margin:8px 0 12px; } h3 { margin-top:20px; }
.grid { display:grid; grid-template-columns:repeat(2,1fr); gap:12px; }
.row { display:flex; gap:8px; }
input, button { font-size:16px; padding:12px; border-radius:12px; }
input { border:1px solid #ddd; width:100%; }
button { border:none; background:#111; color:#fff; }
CSS

  cat > frontend/assets/app.js <<'JS'
const TOKEN = "change-me";
const H = { "Content-Type": "application/json", "x-koid-token": TOKEN };

async function loadPresets(){
  const res = await fetch("/api/presets");
  const data = await res.json();
  const phrases = document.getElementById("phrases"); phrases.innerHTML = "";
  (data.phrases||[]).forEach(t=>{
    const b=document.createElement("button");
    b.textContent=t; b.onclick=()=>say(t); phrases.appendChild(b);
  });
  const emotes = document.getElementById("emotes"); emotes.innerHTML = "";
  (data.emotes||[]).forEach(o=>{
    const b=document.createElement("button");
    b.textContent=o.name; b.onclick=()=>emote(o.name); emotes.appendChild(b);
  });
}

async function say(text){
  await fetch("/api/say",{method:"POST",headers:H,body:JSON.stringify({text})});
}
async function emote(name){
  await fetch("/api/emote",{method:"POST",headers:H,body:JSON.stringify({name})});
}

document.getElementById("speakBtn").onclick=()=>{
  const t=document.getElementById("customText").value.trim();
  if(t) say(t);
};

loadPresets();
JS
fi

# 6) Backend defaults if missing
if [[ ! -f backend/server.py ]]; then
  echo "==> Seeding backend/"
  mkdir -p backend
  cat > backend/settings.py <<'PY'
import os
from pathlib import Path
PROJECT_ROOT = Path(__file__).resolve().parents[1]
FRONTEND_DIR = PROJECT_ROOT / "frontend"
KOID_TOKEN = os.getenv("KOID_TOKEN", "change-me")
MODEL_DIR  = Path(os.getenv("MODEL_DIR", str(PROJECT_ROOT / "models")))
MODEL_NAME = os.getenv("MODEL_NAME", "en_US-ryan-high")
PY

  cat > backend/tts.py <<'PY'
from pathlib import Path
import os, shutil, subprocess, tempfile, sys
def _play_wav(path: str):
    if sys.platform == "darwin" and shutil.which("afplay"):
        subprocess.run(["afplay", path], check=True); return
    if shutil.which("aplay"):
        subprocess.run(["aplay", "-q", path], check=True); return
    if shutil.which("ffplay"):
        subprocess.run(["ffplay","-autoexit","-nodisp","-loglevel","quiet", path], check=True); return
    print("[TTS] No audio player found; WAV at:", path)
def speak(text: str, model_dir: Path, model_name: str) -> None:
    text = (text or "").trim() if hasattr(str, "trim") else (text or "").strip()
    if not text: return
    piper = shutil.which("piper")
    model = model_dir / f"{model_name}.onnx"
    conf  = model_dir / f"{model_name}.onnx.json"
    if piper and model.exists() and conf.exists():
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tf:
            wav = tf.name
        try:
            subprocess.run([piper,"--model",str(model),"--config",str(conf),
                            "--output_file",wav], input=text.encode("utf-8"), check=True)
            _play_wav(wav)
        finally:
            try: os.remove(wav)
            except OSError: pass
        return
    if sys.platform == "darwin" and shutil.which("say"):
        subprocess.run(["say", text], check=True); return
    print(f"[TTS:FALLBACK] {text}")
PY

  cat > backend/emotes.py <<'PY'
import asyncio
async def run_emote(name: str, speed: float = 1.0):
    print(f"[EMOTE] {name} @ {speed}")
    await asyncio.sleep(0.2)
PY

  cat > backend/server.py <<'PY'
from fastapi import FastAPI, Request, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from pathlib import Path
import json
from .settings import FRONTEND_DIR, KOID_TOKEN, MODEL_DIR, MODEL_NAME
from .tts import speak
from .emotes import run_emote

app = FastAPI(title="Koid Control")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
app.mount("/", StaticFiles(directory=str(FRONTEND_DIR), html=True), name="ui")

PRESETS_PATH = Path(__file__).resolve().parent / "presets.json"
if not PRESETS_PATH.exists():
    PRESETS_PATH.write_text(json.dumps({"phrases": [
        "I'm Koid, a Unitree G1 from RoboStore!",
        "System check complete. Ready to demonstrate.",
        "Please keep a safe distance while I move."
    ], "emotes": [{"name":"wave"},{"name":"nod"}]}, indent=2))
STATE = json.loads(PRESETS_PATH.read_text())

def check_auth(req: Request):
    if req.headers.get("x-koid-token") != KOID_TOKEN:
        raise HTTPException(status_code=401, detail="Unauthorized")

class SayReq(BaseModel):
    text: str
class EmoteReq(BaseModel):
    name: str
    speed: float = 1.0

@app.get("/api/health")
def health(): return {"ok": True}

@app.get("/api/presets")
def get_presets(): return STATE

@app.post("/api/presets")
async def add_preset(req: Request):
    check_auth(req)
    body = await req.json()
    changed = False
    if "text" in body:
        STATE.setdefault("phrases", []).append(body["text"]); changed = True
    if "emote" in body:
        STATE.setdefault("emotes", []).append({"name": body["emote"]}); changed = True
    if changed:
        PRESETS_PATH.write_text(json.dumps(STATE, indent=2))
    return {"ok": True}

@app.post("/api/say")
async def api_say(payload: SayReq, request: Request):
    check_auth(request); speak(payload.text, MODEL_DIR, MODEL_NAME); return {"ok": True}

@app.post("/api/emote")
async def api_emote(payload: EmoteReq, request: Request):
    check_auth(request); await run_emote(payload.name, payload.speed); return {"ok": True}
PY
fi

# 7) Run the dev server
echo "==> Starting dev server on http://0.0.0.0:${PORT}"
export KOID_TOKEN MODEL_NAME="${MODEL_NAME}"
exec uvicorn backend.server:app --host 0.0.0.0 --port "${PORT}" --reload