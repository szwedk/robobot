# backend/vision.py
import os
import base64
import requests

from . import tts

# Where Ollama is running
OLLAMA_HOST = os.getenv("OLLAMA_HOST", "http://127.0.0.1:11434")
# Vision-capable model (ensure it's pulled)
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "llama3.2-vision")

def _prompt_for(mode: str) -> str:
    m = (mode or "").strip().lower()
    if m == "compliment":
        return (
            "You're given a single webcam snapshot. "
            "Speak exactly one sentence, flirty compliment, . "
            "rizz it up."
        )
    if m == "roast":
        return (
            "You're given a single webcam snapshot. "
            "Speak exactly one sentence, playful roast. "
            "Be ruthless; roast the clothing, the look, anything."
        )
    return "Give one, observation about this snapshot, talk in first person, talk to them as if you are standing in front of them."

def analyze_image(image_bytes: bytes, mode: str) -> str:
    if not image_bytes:
        raise ValueError("empty image")

    # Raw base64 (no data: URL prefix)
    b64 = base64.b64encode(image_bytes).decode("ascii")

    payload = {
        "model": OLLAMA_MODEL,
        "prompt": _prompt_for(mode),
        "images": [b64],
        "stream": False,
    }

    url = f"{OLLAMA_HOST}/api/generate"
    try:
        r = requests.post(url, json=payload, timeout=90)
    except Exception as e:
        raise RuntimeError(f"Ollama request failed: {e}")

    if r.status_code != 200:
        try:
            detail = r.json()
        except Exception:
            detail = r.text
        raise RuntimeError(f"Ollama error {r.status_code}: {detail}")

    data = r.json()
    text = (data.get("response") or "").strip()
    if not text:
        raise RuntimeError("Empty response from Ollama")

    # Speak it (best-effort) and return text
    try:
        tts.speak(text)
    except Exception as e:
        print(f"[vision] TTS failed: {e}")

    return text