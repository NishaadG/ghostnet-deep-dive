#!/usr/bin/env python3
"""Make the voice-over clips with ElevenLabs (https://elevenlabs.io).

Every spoken line comes from the game itself (Story.voice_lines in scripts/story.gd). Steps:

  1. godot --headless --path . res://tools/voice_lines.tscn     # writes tools/voice_lines.json
  2. python3 tools/make_voices.py voices                         # list voices you can use
  3. edit tools/voice_cast.json                                  # which voice speaks for whom
  4. python3 tools/make_voices.py make                           # writes assets/voice/<id>.mp3

The API key is read from the ELEVENLABS_API_KEY environment variable or ~/.config/elevenlabs_key.
It is never stored in the project. Lines whose text, voice and settings have not changed since the
last run are skipped (see assets/voice/manifest.json), so re-running only pays for what changed.
Only the Python standard library is used; ffmpeg (optional) adds the radio and tremor effects.
"""

import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.parse
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LINES_FILE = os.path.join(ROOT, "tools", "voice_lines.json")
CAST_FILE = os.path.join(ROOT, "tools", "voice_cast.json")
OUT_DIR = os.path.join(ROOT, "assets", "voice")
MANIFEST_FILE = os.path.join(OUT_DIR, "manifest.json")
API = "https://api.elevenlabs.io"
MODEL = "eleven_multilingual_v2"
OUTPUT_FORMAT = "mp3_44100_96"

# Say numbers and short forms the way a person would.
PRONOUNCE = [
    (r"\b2190\b", "twenty-one ninety"),
    (r"\b2131\b", "twenty-one thirty-one"),
    (r"\bBoat 07\b", "Boat oh-seven"),
    (r"\bBoat 03\b", "Boat oh-three"),
    (r"\bO2\b", "O-two"),
]

# ffmpeg filters that shape a voice after it is made.
EFFECTS = {
    # A crackly ship-to-diver radio: thin band, a little grit, a soft hiss.
    "radio": "highpass=f=350,lowpass=f=3200,acrusher=bits=10:mix=0.25,volume=1.6",
    # An older voice from a younger one: a touch lower (same speed), a shaky pitch and level, a little grit.
    "aged": "asetrate=44100*0.93,aresample=44100,atempo=1.075,vibrato=f=5.5:d=0.16,tremolo=f=6:d=0.14,"
            "acrusher=bits=12:mix=0.12,highpass=f=90",
    # A lighter version for a voice that is already old: just the shake and the grit.
    "old": "vibrato=f=5:d=0.12,tremolo=f=6:d=0.1,acrusher=bits=12:mix=0.1",
}
# Every clip ends at the same loudness, so no character is much louder than another.
LEVEL = "loudnorm=I=-19:TP=-1.5:LRA=11,aresample=44100"


def api_key():
    key = os.environ.get("ELEVENLABS_API_KEY", "").strip()
    path = os.path.expanduser("~/.config/elevenlabs_key")
    if not key and os.path.exists(path):
        key = open(path).read().strip()
    if not key:
        sys.exit("No API key. Set ELEVENLABS_API_KEY or save it to ~/.config/elevenlabs_key")
    return key


def request(method, path, body=None, params=None, raw=False):
    url = API + path + ("?" + urllib.parse.urlencode(params) if params else "")
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("xi-api-key", api_key())
    if data is not None:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=120) as response:
            payload = response.read()
    except urllib.error.HTTPError as error:
        sys.exit(f"ElevenLabs said {error.code} for {path}: {error.read().decode(errors='replace')[:400]}")
    return payload if raw else json.loads(payload)


def spoken(text):
    for pattern, replacement in PRONOUNCE:
        text = re.sub(pattern, replacement, text)
    return text


# ---- Commands ----

def cmd_voices(args):
    """List the voices on your account, and old voices from the shared Voice Library."""
    print("YOUR VOICES")
    for v in request("GET", "/v2/voices", params={"page_size": 100})["voices"]:
        labels = ", ".join(f"{k}={val}" for k, val in (v.get("labels") or {}).items())
        print(f"  {v['voice_id']}  {v['name']:<28} {labels}")
    for gender in ("female", "male"):
        print(f"\nVOICE LIBRARY: old {gender} voices (add one with: make_voices.py add <owner_id> <voice_id> <name>)")
        found = request("GET", "/v1/shared-voices", params={"page_size": 12, "gender": gender, "age": "old", "language": "en"})
        for v in found.get("voices", []):
            print(f"  {v['public_owner_id']} {v['voice_id']}  {v['name'][:30]:<30} {v.get('accent', '')}: {(v.get('description') or '')[:80]}")


def cmd_add(args):
    """Copy a Voice Library voice into your account so it can be used."""
    owner, voice_id, name = args[0], args[1], " ".join(args[2:]) or "Library voice"
    result = request("POST", f"/v1/voices/add/{owner}/{voice_id}", body={"new_name": name})
    print("added", result.get("voice_id"), name)


def cmd_make(args):
    """Make every clip that is missing or out of date."""
    only = set()
    dry_run = "--dry-run" in args
    for arg in args:
        if arg.startswith("--only="):
            only = set(arg[7:].split(","))
    lines = json.load(open(LINES_FILE))
    cast = json.load(open(CAST_FILE))
    manifest = json.load(open(MANIFEST_FILE)) if os.path.exists(MANIFEST_FILE) else {}
    todo = []
    for line in lines:
        role = cast[line["who"]]
        text = spoken(line["text"])
        stamp = hashlib.sha1(json.dumps([role, text, MODEL], sort_keys=True).encode()).hexdigest()
        path = os.path.join(OUT_DIR, line["id"] + ".mp3")
        if only and line["id"] not in only:
            continue
        if manifest.get(line["id"]) == stamp and os.path.exists(path):
            continue
        todo.append((line, role, text, stamp, path))
    needed = sum(len(t[2]) for t in todo)
    usage = request("GET", "/v1/user/subscription")
    left = usage["character_limit"] - usage["character_count"]
    print(f"{len(todo)} clips to make, {needed} characters; your account has {left} left this month")
    if dry_run or not todo:
        return
    if needed > left:
        sys.exit("Not enough characters left. Use --only=<ids> to make some now and the rest later.")
    os.makedirs(OUT_DIR, exist_ok=True)
    for n, (line, role, text, stamp, path) in enumerate(todo, 1):
        audio = request("POST", f"/v1/text-to-speech/{role['voice_id']}", raw=True, params={"output_format": OUTPUT_FORMAT},
                        body={"text": text, "model_id": MODEL, "voice_settings": role.get("settings", {})})
        with open(path, "wb") as f:
            f.write(audio)
        for effect in role.get("effects", []):
            apply_effect(path, EFFECTS[effect])
        apply_effect(path, LEVEL)
        manifest[line["id"]] = stamp
        json.dump(manifest, open(MANIFEST_FILE, "w"), indent=1, sort_keys=True)     # saved as we go
        print(f"  [{n}/{len(todo)}] {line['id']:<16} {line['who']:<9} {line['text'][:60]}")
    print("done. Run the Godot import (godot --headless --path . --import) so the game picks them up.")


def apply_effect(path, audio_filter):
    if not shutil.which("ffmpeg"):
        print("    (ffmpeg not found: skipped an effect)")
        return
    with tempfile.NamedTemporaryFile(suffix=".mp3", delete=False) as tmp:
        temp_path = tmp.name
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", path, "-af", audio_filter, "-b:a", "96k", temp_path], check=True)
    shutil.move(temp_path, path)


COMMANDS = {"voices": cmd_voices, "add": cmd_add, "make": cmd_make}

if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] not in COMMANDS:
        sys.exit(__doc__)
    COMMANDS[sys.argv[1]](sys.argv[2:])
