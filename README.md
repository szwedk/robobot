# Koid — The Local AI Soundboard & Vision Personality System

Koid is a **fully local**, privacy-preserving **voice + vision interaction panel** designed for **Unitree G1 demos, robotics showcases, telepresence, and live audience interactions**.

It brings together:

- **Real-time speech** using **Piper TTS (Ryan voice)**
- A **Soundboard** for quick reaction audio clips
- **Text-to-Speech input** with automatic recent history memory
- **Webcam-based vision analysis** using **Ollama (LLaVA / Llama 3.2-Vision)**
- **Compliment** mode or **Roast** mode — spoken aloud instantly
- All processing is **100% local** — no cloud, no tracking.

Designed for *demos that feel alive* and interactions that feel *personal*.

---

## Features At a Glance

| Feature | Description |
|--------|-------------|
| Soundboard | Play reaction sounds instantly from `media/sounds/` |
| Text-to-Speech | Type anything and Koid says it in Piper’s Ryan voice |
| Recent Replay | Last 5 spoken phrases are saved for quick re-use |
| Webcam Capture | Video feed runs locally with 1-click snapshot capture |
| Compliment Mode | Analyzes the live image and produces a wholesome message |
| Roast Mode | Generates playful, crowd-pleasing roasts without being cruel |
| No Cloud Required | Ollama + Piper ensure everything runs offline |

---

## Project Structure

```
robobot/
│ backend/
│   server.py            # FastAPI web server + APIs
│   tts.py               # Piper TTS controller
│   vision.py            # Webcam → Image → Ollama → Text generation
│ frontend/
│   index.html           # UI layout
│   assets/
│     app.js             # Interaction logic, webcam, replay, roast/compliment
│     app.css            # Styling
│ media/
│   sounds/              # Customizable soundboard clips (.mp3)
│ models/
│   en_US-ryan-high.onnx
│   en_US-ryan-high.onnx.json
│ README.md
```

---

## Requirements

| Component | Purpose | Install |
|---------|---------|---------|
| **Python 3.12** | Runs backend | Already installed |
| **Ollama** | Local AI inference | https://ollama.com/download |
| **Piper-TTS** | Local speech synthesis | `pip install piper-tts` |
| **FFmpeg** | Plays sound output streams | `brew install ffmpeg` (macOS) |
| **LLaVA or Llama-3 Vision** | Vision language reasoning | `ollama pull llama3.2-vision` |

---

## Setup

### 1. Clone and enter project
```bash
cd ~/Documents/code/robobot
```

### 2. Activate your environment
```bash
source ~/.venvs/robobot/bin/activate
```

### 3. Install dependencies
```bash
pip install fastapi uvicorn pillow numpy piper-tts
```

### 4. Start Ollama
```bash
ollama serve
```

### 5. Run the App
```bash
uvicorn backend.server:app --reload --port 8000
```

### 6. Open in browser
```
http://localhost:8000
```

---

## 🎙️ Adjusting Speech Speed

Open:

```
backend/tts.py
```

Modify Piper length scale:

```python
"--length-scale", "1.25",
```

| Style | Value |
|------|-------|
| Default | `1.00` |
| Natural, conversational | `1.20` |
| Slower stage demo | `1.35` |
| Dramatic narrator | `1.50` |

---

## Compliment & Roast Prompt Personality

Edit tone inside:

```
backend/vision.py
```

---

## Adding Custom Soundboard Clips

Place `.mp3` files in:

```
media/sounds/
```

They auto-appear in the UI.

---

## Known Good Hardware Setup

| Component | Recommended |
|----------|-------------|
| MacBook M-series | Best performance |
| Logitech C920 Webcam | Plug-and-play |
| Bluetooth / robot speaker | For loud environments |

---

## Future Expansion Ideas

- Voice-triggered conversation mode
- Animated expression / arm sync
- Crowd-interaction looping routines

---

## Credits

Created and engineered for **RoboStore**.

If you're running demos, live activations, or training sessions — Koid makes the robot *feel alive*.
