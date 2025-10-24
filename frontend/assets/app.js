// ---------- tiny helpers ----------
const $ = (sel) => document.querySelector(sel);
const toastEl = $("#toast");
const toastMsgEl = $("#toast-msg");
const toastCloseEl = $("#toast-close");

function toast(msg) {
  if (!toastEl || !toastMsgEl) return alert(msg);
  toastMsgEl.textContent = msg;
  toastEl.showModal();
}
if (toastCloseEl && toastEl) {
  toastCloseEl.addEventListener("click", () => toastEl.close());
}

// Small timed fetch helper (so we don't hang forever)
async function fetchWithTimeout(url, opts = {}, ms = 60000) { // ↑ 60s
  const ctrl = new AbortController();
  const id = setTimeout(() => ctrl.abort(), ms);
  try {
    return await fetch(url, { ...opts, signal: ctrl.signal });
  } finally {
    clearTimeout(id);
  }
}

// ---------- elements ----------
const soundsGrid = $("#sounds");
const player = $("#player");
const ttsForm = $("#tts-form");
const ttsText = $("#tts-text");
const speakBtn = $("#speak-btn");
const speakStatus = $("#speak-status");
const recentEl = $("#recent-list");

// Vision elements (no start/stop/capture buttons)
const camWrap = $("#cam-wrap");
const videoEl = $("#cam");
const snapshotCanvas = $("#snapshot");
const visionStatus = $("#vision-status");
const complimentBtn = $("#analyze-compliment");
const roastBtn = $("#analyze-roast");
const togglePreview = $("#toggle-preview");

// ---------- Recent (rolling 5, client-side only) ----------
const RECENT_KEY = "tts_recent_v1";
function loadRecent() {
  try {
    const raw = localStorage.getItem(RECENT_KEY);
    const arr = raw ? JSON.parse(raw) : [];
    return Array.isArray(arr) ? arr : [];
  } catch {
    return [];
  }
}
function saveRecent(arr) {
  try {
    localStorage.setItem(RECENT_KEY, JSON.stringify(arr.slice(0, 5)));
  } catch {}
}
function pushRecent(text) {
  const trimmed = (text || "").trim();
  if (!trimmed) return;
  let arr = loadRecent();
  if (arr[0] !== trimmed) arr.unshift(trimmed);
  arr = arr.slice(0, 5);
  saveRecent(arr);
  renderRecent();
}
function renderRecent() {
  if (!recentEl) return;
  recentEl.innerHTML = "";

  const arr = loadRecent();
  if (!arr.length) {
    const li = document.createElement("li");
    li.className = "muted";
    li.textContent = recentEl.dataset.empty || "Nothing yet.";
    recentEl.appendChild(li);
    return;
  }

  for (const text of arr) {
    const li = document.createElement("li");
    li.className = "recent-item";

    const label = document.createElement("span");
    label.className = "recent-text";
    label.textContent = text;

    const spacer = document.createElement("span");
    spacer.style.flex = "1";

    const btn = document.createElement("button");
    btn.className = "btn small";
    btn.textContent = "Replay";
    btn.style.marginLeft = "0.5rem";
    btn.addEventListener("click", async () => {
      try {
        await sayText(text);
      } catch (e) {
        toast(String(e));
      }
    });

    li.appendChild(label);
    li.appendChild(spacer);
    li.appendChild(btn);
    recentEl.appendChild(li);
  }
}

// ---------- API ----------
async function api(url, opts = {}) {
  const res = await fetch(url, opts);
  if (!res.ok) {
    let msg = `${res.status} ${res.statusText}`;
    try {
      const data = await res.json();
      if (data && data.detail) msg = typeof data.detail === "string" ? data.detail : JSON.stringify(data.detail);
    } catch {}
    throw new Error(msg);
  }
  const ct = res.headers.get("content-type") || "";
  if (ct.includes("application/json")) return res.json();
  return res.text();
}

async function loadSounds() {
  if (!soundsGrid) return;
  soundsGrid.innerHTML = "";
  try {
    const list = await api("/api/sounds");
    if (!Array.isArray(list) || list.length === 0) {
      const empty = document.createElement("div");
      empty.className = "muted";
      empty.textContent = soundsGrid.dataset.empty || "No sounds found.";
      soundsGrid.appendChild(empty);
      return;
    }
    list.forEach((s) => {
      const btn = document.createElement("button");
      btn.className = "sound-btn";
      btn.textContent = s.name || s.file || "sound";
      btn.addEventListener("click", () => {
        if (!player) return;
        player.src = s.file;
        player.currentTime = 0;
        player.play().catch(() => {});
      });
      soundsGrid.appendChild(btn);
    });
  } catch (e) {
    console.error(e);
    const err = document.createElement("div");
    err.className = "muted";
    err.textContent = "Failed to load sounds.";
    soundsGrid.appendChild(err);
  }
}

async function sayText(text) {
  const t = (text || "").trim();
  if (!t) return;

  if (speakStatus) speakStatus.textContent = "Speaking…";
  if (speakBtn) speakBtn.disabled = true;

  try {
    const fd = new FormData();
    fd.append("text", t);
    await api("/api/say", { method: "POST", body: fd });
    pushRecent(t);
  } finally {
    if (speakBtn) speakBtn.disabled = false;
    if (speakStatus) speakStatus.textContent = "";
  }
}

// ---------- TTS form ----------
if (ttsForm && ttsText) {
  ttsForm.addEventListener("submit", async (e) => {
    e.preventDefault();
    const text = ttsText.value;
    if (!text.trim()) return;
    try {
      await sayText(text);
    } catch (err) {
      toast(`TTS failed: ${String(err.message || err)}`);
    }
  });
}

// ---------- Vision (auto-start stream on demand) ----------
let camStream = null;
let startingCam = null;
let analyzing = false; // prevent double clicks

async function ensureCamera() {
  if (camStream) return camStream;
  if (startingCam) return startingCam;

  startingCam = (async () => {
    try {
      camStream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: "user", width: { ideal: 1280 }, height: { ideal: 720 } },
        audio: false
      });
      if (videoEl) {
        videoEl.srcObject = camStream;
        await videoEl.play().catch(() => {});
        await new Promise((r) => {
          if (videoEl.readyState >= 2) return r();
          videoEl.onloadeddata = () => r();
          setTimeout(r, 500);
        });
      }
      return camStream;
    } catch (err) {
      console.error("Camera error:", err);
      toast("Camera unavailable. Allow permission and use http://localhost:8000 in Chrome.");
      throw err;
    } finally {
      startingCam = null;
    }
  })();

  return startingCam;
}

async function getSnapshotBlob() {
  if (!videoEl || !snapshotCanvas) throw new Error("Camera not initialized");
  const vw = videoEl.videoWidth || 640;
  const vh = videoEl.videoHeight || 480;
  const targetW = 512;
  const scale = targetW / vw;
  const targetH = Math.max(1, Math.round(vh * scale));

  snapshotCanvas.width = targetW;
  snapshotCanvas.height = targetH;

  const ctx = snapshotCanvas.getContext("2d");
  ctx.drawImage(videoEl, 0, 0, targetW, targetH);

  const blob = await new Promise((resolve, reject) =>
    snapshotCanvas.toBlob((b) => (b ? resolve(b) : reject(new Error("Snapshot failed"))), "image/jpeg", 0.7)
  );
  return blob;
}

function setAnalyzeButtonsDisabled(disabled) {
  if (complimentBtn) complimentBtn.disabled = disabled;
  if (roastBtn) roastBtn.disabled = disabled;
}

async function analyzeAndSpeak(mode) {
  if (analyzing) return; // debounce
  analyzing = true;
  setAnalyzeButtonsDisabled(true);

  if (visionStatus) visionStatus.textContent = "Analyzing…";

  // Play analyzing SFX (non-blocking)
  let resumeSrc = null;
  let resumeTime = 0;
  try {
    if (player) {
      resumeSrc = player.src;
      resumeTime = player.currentTime || 0;
      player.pause();
      player.src = "/media/sounds/thinking.mp3"; // ensure this file exists
      player.currentTime = 0;
      player.play().catch(() => {});
    }
  } catch {}

  try {
    await ensureCamera();
    const blob = await getSnapshotBlob();

    const fd = new FormData();
    fd.append("image", blob, "snap.jpg");
    fd.append("mode", mode);

    // ↑ use 60s timeout now
    const res = await fetchWithTimeout("/api/vision/analyze", { method: "POST", body: fd }, 60000);

    let data;
    const ct = res.headers.get("content-type") || "";
    if (ct.includes("application/json")) {
      data = await res.json();
    } else {
      const txt = await res.text();
      data = { detail: txt };
    }

    if (!res.ok) {
      const msg = (data && (data.detail || data.error)) || `HTTP ${res.status}`;
      if (visionStatus) visionStatus.textContent = `Error: ${msg}`;
      toast(`Vision failed: ${msg}`);
      return;
    }

    const line = ((data && data.text) || "").trim();
    if (visionStatus) visionStatus.textContent = line || "(no text)";

    // Backend speaks via Piper. If you want FE to speak instead:
    // if (line) await sayText(line);

  } catch (err) {
    const msg = err?.name === "AbortError" ? "Timed out." : (err?.message || String(err));
    if (visionStatus) visionStatus.textContent = `Error: ${msg}`;
    toast(`Vision failed: ${msg}`);
  } finally {
    // stop analyzing SFX & restore prior playback
    try {
      if (player) {
        player.pause();
        if (resumeSrc) {
          player.src = resumeSrc;
          if (resumeTime) player.currentTime = resumeTime;
        }
      }
    } catch {}
    if (visionStatus && visionStatus.textContent === "Analyzing…") {
      visionStatus.textContent = "";
    }
    analyzing = false;
    setAnalyzeButtonsDisabled(false);
  }
}

// Hook up buttons
if (complimentBtn) complimentBtn.addEventListener("click", () => analyzeAndSpeak("compliment"));
if (roastBtn) roastBtn.addEventListener("click", () => analyzeAndSpeak("roast"));

// Toggle camera preview visibility
if (togglePreview) {
  togglePreview.addEventListener("change", () => {
    if (!camWrap) return;
    camWrap.style.display = togglePreview.checked ? "block" : "none";
  });
}

// ---------- boot ----------
loadSounds();
renderRecent();