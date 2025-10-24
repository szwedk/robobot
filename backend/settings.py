# backend/settings.py
from pathlib import Path

# Project root (…/robobot/)
ROOT_DIR = Path(__file__).resolve().parents[1]

# Frontend
FRONTEND_DIR = ROOT_DIR / "frontend"
ASSETS_DIR   = FRONTEND_DIR / "assets"

# Media
MEDIA_DIR  = ROOT_DIR / "media"
SOUNDS_DIR = MEDIA_DIR / "sounds"
SAVED_DIR  = MEDIA_DIR / "saved"

# TTS cache (where your current tts.py writes files)
TTS_CACHE_DIR = SAVED_DIR / "tts_cache"

# Ensure required directories exist
for p in (FRONTEND_DIR, ASSETS_DIR, MEDIA_DIR, SOUNDS_DIR, SAVED_DIR, TTS_CACHE_DIR):
    p.mkdir(parents=True, exist_ok=True)