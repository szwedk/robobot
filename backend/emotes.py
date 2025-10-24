import asyncio
import os

USE_SDK = os.getenv("USE_UNITREE_SDK", "0") == "1"

_robot = None

async def _ensure_robot():
    global _robot
    if _robot or not USE_SDK:
        return
    # from unitree_sdk2py.core import robot_interface
    # _robot = robot_interface.RobotInterface()
    await asyncio.sleep(0)

async def emote_nod(speed: float = 1.0):
    await _ensure_robot()
    await asyncio.sleep(0.6 / speed)

async def emote_wave(speed: float = 1.0):
    await _ensure_robot()
    await asyncio.sleep(0.8 / speed)

EMOTES = {
    "nod": emote_nod,
    "wave": emote_wave,
}

async def run_emote(name: str, speed: float = 1.0):
    fn = EMOTES.get(name)
    if not fn:
        return
    try:
        await fn(speed)
    except:
        pass