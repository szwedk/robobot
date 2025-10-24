"""
backend/tts.py
Speak text out loud with Piper (Ryan high) via the Piper CLI.
- No permanent audio files (temp file deleted after play)
- Keep a rolling history of the last 5 texts
- Expose helpers to read history and replay an item
"""

from __future__ import annotations

import os
import sys
import json
import shutil
import tempfile
import subprocess
from collections import deque
from pathlib import Path
from typing import List, Dict

# ----------------------------
# Paths / config
# ----------------------------
ROOT = Path(__file__).resolve().parents[1]          # repo root
MODELS_DIR = ROOT / "models"
DATA_DIR = ROOT / "data"
DATA_DIR.mkdir(parents=True, exist_ok=True)
HISTORY_JSON = DATA_DIR / "tts_history.json"

MODEL_NAME = os.getenv("PIPER_MODEL_NAME", "en_US-ryan-high")
MODEL_PATH = MODELS_DIR / f"{MODEL_NAME}.onnx"
CONFIG_PATH = MODELS_DIR / f"{MODEL_NAME}.onnx.json"

# Last 5 spoken texts (newest first)
_history: deque[Dict[str, str]] = deque(maxlen=5)


# ----------------------------
# Utilities
# ----------------------------
def _ensure_piper():
    if shutil.which("piper") is None:
        raise RuntimeError(
            "Piper CLI not found. Install with: pip install piper-tts (and ensure 'piper' is on PATH)"
        )

def _ensure_model():
    if not MODEL_PATH.exists():
        raise RuntimeError(f"Piper model not found: {MODEL_PATH}")
    # JSON config is optional; if present we pass it.

def _detect_player() -> list[str]:
    if sys.platform == "darwin":
        return ["afplay"]
    if shutil.which("aplay"):
        return ["aplay", "-q"]
    if shutil.which("ffplay"):
        return ["ffplay", "-autoexit", "-nodisp", "-loglevel", "quiet"]
    raise RuntimeError("No audio player found. Install 'afplay' (macOS), 'aplay' or 'ffplay'.")

def _save_history_to_disk():
    try:
        with open(HISTORY_JSON, "w", encoding="utf-8") as f:
            json.dump(list(_history), f, indent=2, ensure_ascii=False)
    except Exception:
        pass

def _load_history_from_disk():
    if HISTORY_JSON.exists():
        try:
            data = json.loads(HISTORY_JSON.read_text(encoding="utf-8"))
            # keep only last 5, newest first if possible
            for item in list(reversed(data))[-5:]:
                if isinstance(item, dict) and "text" in item:
                    _history.appendleft({"text": item["text"]})
        except Exception:
            pass


# Load any prior history on import (best effort)
_load_history_from_disk()


# ----------------------------
# Core operations
# ----------------------------
def speak(text: str) -> None:
    """Synthesize and play speech (no permanent file)."""
    t = (text or "").strip()
    if not t:
        return

    _ensure_piper()
    _ensure_model()
    player = _detect_player()

    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tf:
        wav_path = tf.name

    try:
        cmd = ["piper", "--model", str(MODEL_PATH), "--output_file", wav_path]
        if CONFIG_PATH.exists():
            cmd += ["--config", str(CONFIG_PATH)]
        # send text through stdin
        subprocess.run(cmd, input=t.encode("utf-8"), check=True)
        subprocess.run(player + [wav_path], check=True)
    except subprocess.CalledProcessError as e:
        raise RuntimeError(f"Piper or audio playback failed: {e}") from e
    finally:
        try:
            os.remove(wav_path)
        except OSError:
            pass


def add_to_history(text: str) -> None:
    """Push newest text and persist rolling 5."""
    t = (text or "").strip()
    if not t:
        return
    _history.appendleft({"text": t})
    _save_history_to_disk()


def get_history() -> List[Dict[str, str]]:
    """Return newest-first list of up to 5 entries like [{'text': 'hello'}]."""
    return list(_history)


def replay(index: int) -> None:
    """Replay the n-th (0-based) history item."""
    if index < 0 or index >= len(_history):
        raise IndexError("Invalid history index")
    speak(_history[index]["text"])