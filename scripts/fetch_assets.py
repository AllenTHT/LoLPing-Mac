#!/usr/bin/env python3
"""Fetch only the documented image/audio assets; never executes downloaded code."""
import concurrent.futures
import json
from pathlib import Path
import urllib.request

ROOT = Path(__file__).resolve().parent.parent
BASE = "https://raw.communitydragon.org/15.24/game/assets/ux/minimap/pings/"
ICONS = ["retreat", "push", "on_my_way_new", "all_in", "assist", "need_ward",
         "mia_new", "area_is_warded_small_red_new", "ping", "ring", "ring2",
         "ring_danger", "ring2_yellow", "ring_green", "ring_red"]
SOUNDS = ["retreat", "push", "on_my_way", "all_in", "assist_me", "need_vision",
          "q_mark", "enemy_vision", "alert"]

def read(url):
    request = urllib.request.Request(url, headers={"User-Agent": "LoLPing-local-asset-fetch/1.0"})
    with urllib.request.urlopen(request, timeout=45) as response:
        return response.read()

def main():
    manifest_path = ROOT / "Resources" / "asset-sources.json"
    manifest = None
    if manifest_path.exists():
        manifest = json.loads(manifest_path.read_text())
        revision = manifest["soundRevision"]
    else:
        revision = json.loads(read("https://api.github.com/repos/alibaztomars/lol-ping-overlay/commits/main"))["sha"]
    sound_base = f"https://raw.githubusercontent.com/alibaztomars/lol-ping-overlay/{revision}/sounds/"
    jobs = [("Icons", name + ".png", BASE + name + ".png") for name in ICONS]
    jobs += [("Sounds", name + ".mp3", sound_base + name + ".mp3") for name in SOUNDS]
    if manifest:
        jobs += [("Artwork", Path(item["path"]).name, item["url"]) for item in manifest["files"] if item["path"].startswith("Artwork/")]
    def fetch(job):
        folder, name, url = job
        destination = ROOT / "Resources" / folder / name
        if destination.exists() and destination.stat().st_size > 0:
            return
        payload = read(url)
        if folder in ("Icons", "Artwork") and not payload.startswith(b"\x89PNG\r\n\x1a\n"):
            raise RuntimeError(f"Invalid PNG: {name}")
        if folder == "Sounds" and len(payload) < 1000:
            raise RuntimeError(f"Invalid audio: {name}")
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(payload)
    with concurrent.futures.ThreadPoolExecutor(max_workers=5) as pool:
        list(pool.map(fetch, jobs))
    if manifest is None:
        manifest_path.write_text(json.dumps({
        "imageVersion": "15.24", "imageSource": BASE,
        "officialReference": "https://support.riotgames.com/en-us/league-of-legends/gameplay/smart-ping",
        "soundRevision": revision, "soundSource": sound_base,
        "soundNotice": "Community audio; equivalence to original Riot recordings is unverified.",
        "files": [{"path": f"{folder}/{name}", "url": url} for folder, name, url in jobs]
        }, indent=2) + "\n")
    print(f"Ready: {len(ICONS)} images and {len(SOUNDS)} sounds; audio revision {revision[:12]}")

if __name__ == "__main__":
    main()
