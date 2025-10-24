# backend/server.py
from pathlib import Path

from fastapi import FastAPI, Form, UploadFile, File
from fastapi.responses import FileResponse, JSONResponse, HTMLResponse
from fastapi.staticfiles import StaticFiles

# our modules
from . import tts
from . import vision

# ---------- paths ----------
ROOT = Path(__file__).resolve().parents[1]
FRONTEND = ROOT / "frontend"
INDEX_HTML = FRONTEND / "index.html"
ASSETS_DIR = FRONTEND / "assets"

MEDIA_DIR = ROOT / "media"
SOUNDS_DIR = MEDIA_DIR / "sounds"
SOUNDS_DIR.mkdir(parents=True, exist_ok=True)

# ---------- app ----------
app = FastAPI(title="Koid Soundboard", version="1.0.0")

# static mounts (only if they exist)
if ASSETS_DIR.exists():
    app.mount("/assets", StaticFiles(directory=ASSETS_DIR), name="assets")

if MEDIA_DIR.exists():
    app.mount("/media", StaticFiles(directory=MEDIA_DIR), name="media")


# ---------- routes ----------
@app.get("/")
def root():
    if INDEX_HTML.exists():
        return FileResponse(INDEX_HTML)
    return HTMLResponse("<h1>Koid Soundboard</h1><p>frontend/index.html not found.</p>")

@app.get("/api/health")
def health():
    return "ok"

@app.get("/api/sounds")
def api_sounds():
    items = []
    if SOUNDS_DIR.exists():
        for f in sorted(SOUNDS_DIR.iterdir()):
            if f.suffix.lower() in {".mp3", ".wav", ".ogg"}:
                items.append({"name": f.stem, "file": f"/media/sounds/{f.name}"})
    print(f"[api/sounds] found: {len(items)} in {SOUNDS_DIR}")
    return JSONResponse(items)

@app.post("/api/say")
def api_say(text: str = Form(...)):
    try:
        tts.speak(text)   # no files; Piper + player under the hood
        return JSONResponse({"status": "ok"})
    except Exception as e:
        return JSONResponse({"detail": f"TTS failed: {e}"}, status_code=500)

@app.get("/api/recent")
def api_recent():
    return JSONResponse({"items": tts.recent()})

@app.post("/api/vision/analyze")
def api_vision_analyze(
    image: UploadFile = File(...),
    mode: str = Form("compliment"),
):
    try:
        image_bytes = image.file.read()
        text = vision.analyze_image(image_bytes, mode)
        return JSONResponse({"text": text})
    except Exception as e:
        return JSONResponse({"detail": f"{e}"}, status_code=500)