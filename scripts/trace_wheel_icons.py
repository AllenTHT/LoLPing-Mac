#!/usr/bin/env python3
"""Rebuild scalable silhouettes from the game's wheel atlas, not minimap pixels.

Optional asset maintenance script (Pillow + NumPy). The packaged app has no
Python dependency. Keep atlas provenance and selected/normal colors separately.
"""
import json
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "Resources/Artwork"
# Coordinates are source-atlas pixels, with origin at top left.
REGIONS = {
    "retreat": ("radialwheel_atlas_2.png", (112, 156, 188, 227), "red"),
    "push": ("radialwheel_atlas_2.png", (270, 681, 342, 759), "green"),
    "onMyWay": ("radialwheel_atlas_2.png", (787, 819, 862, 891), "blue"),
    "allIn": ("radialwheel_atlas_2.png", (268, 880, 344, 950), "yellow"),
    "assist": ("radialwheel_atlas_2.png", (562, 788, 633, 862), "green"),
    "needVision": ("radialwheelalt_atlas_2.png", (594, 324, 666, 388), "green"),
    "missing": ("radialwheel_atlas_2.png", (164, 392, 224, 459), "yellow"),
    "enemyVision": ("radialwheelalt_atlas_2.png", (125, 754, 196, 814), "red"),
    "generic": ("radialwheel_atlas_2.png", (840, 59, 897, 115), "blue"),
}

def simplify(points, epsilon=1.0):
    if len(points) <= 2:
        return points
    a, b = np.array(points[0]), np.array(points[-1])
    delta = b - a
    if np.linalg.norm(delta) == 0:
        distances = [np.linalg.norm(np.array(p)-a) for p in points]
    else:
        distances = [abs(delta[0]*(p[1]-a[1])-delta[1]*(p[0]-a[0]))/np.linalg.norm(delta) for p in points]
    index = int(np.argmax(distances))
    if distances[index] <= epsilon:
        return [points[0], points[-1]]
    return simplify(points[:index+1], epsilon)[:-1] + simplify(points[index:], epsilon)

def contours(mask):
    # Trace each exposed pixel edge, including interior holes. Even-odd fill
    # retains cutouts in the eye, warning triangle and blue location marker.
    edges = {}
    height, width = mask.shape
    for y, x in zip(*np.where(mask)):
        sides = [((x,y),(x+1,y), y==0 or not mask[y-1,x]),
                 ((x+1,y),(x+1,y+1), x==width-1 or not mask[y,x+1]),
                 ((x+1,y+1),(x,y+1), y==height-1 or not mask[y+1,x]),
                 ((x,y+1),(x,y), x==0 or not mask[y,x-1])]
        for a,b,exposed in sides:
            if exposed:
                edges.setdefault(a, []).append(b)
    result = []
    while edges:
        start = next(iter(edges))
        point, loop = start, [start]
        while True:
            next_point = edges[point].pop()
            if not edges[point]:
                del edges[point]
            loop.append(next_point)
            point = next_point
            if point == start:
                break
        if len(loop) >= 8:
            result.append(simplify(loop))
    return result

vectors = {}
for name, (atlas, box, color) in REGIONS.items():
    pixels = np.array(Image.open(ART / atlas).convert("RGBA"))[box[1]:box[3],box[0]:box[2]]
    r,g,b = [pixels[:,:,i].astype(float)/255 for i in range(3)]
    if color == "red":
        mask = (r > .65) & (r > 1.6*g)
    elif color == "green":
        mask = (g > .65) & (g > 1.35*b) & (r < .5)
    elif color == "yellow":
        mask = (r > .7) & (g > .45) & (b < .45)
    else:
        mask = (b > .75) & (b > 1.15*g) & (r < .5)
    mask &= pixels[:,:,3] > 100
    # The shipped texture is block-compressed. A majority pass removes its
    # single-pixel edge noise before tracing; these pixels aren't design detail.
    padded = np.pad(mask.astype(int), 1)
    neighbors = sum(padded[dy:dy+mask.shape[0],dx:dx+mask.shape[1]] for dy in range(3) for dx in range(3))
    mask = neighbors >= 5
    ys,xs = np.where(mask)
    if not len(xs):
        raise ValueError(f"No silhouette: {name}")
    min_x,min_y,max_x,max_y = int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)
    mask = mask[min_y:max_y,min_x:max_x]
    h,w = mask.shape
    extent = max(w,h)
    loops = contours(mask)
    vectors[name] = {
        "atlas": atlas, "sourceBounds": [box[0]+min_x,box[1]+min_y,w,h],
        "contours": [[[round((x+(extent-w)/2)/extent,5),round((h-y+(extent-h)/2)/extent,5)]
                      for x,y in loop[:-1]] for loop in loops]
    }
    print(name, (w,h), sum(len(c) for c in vectors[name]["contours"]), "vertices")
(ART / "ping-vectors.json").write_text(json.dumps(vectors, indent=2)+"\n")
