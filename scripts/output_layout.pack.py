# env python3
from typing import List, Tuple
outputs: dict[str, dict[str, int]] = {}

def collect_touching() -> List[Tuple[List[str], dict[str, int]]]:
    global outputs
    touching: List[Tuple[List[str], dict[str, int]]] = []
    for k, dim in outputs.items():
        for grp, gbb in touching:
            touch = 0
            for ldim in [ outputs[out] for out in grp]:
                if contains(dim, ldim) or contains(ldim, dim):
                    grp.append(k)
                    extend_with_dim(gbb, dim)
                    break
                elif touches(dim, ldim):
                    touch += 1
                elif intersects(dim, ldim):
                    break
            else:
                if touch > 0:
                    grp.append(k)
                    extend_with_dim(gbb, dim)
            if k in grp:
                break
        else:
            touching.append(([k], {
                "x1": dim["x"],
                "y1": dim["y"],
                "x2": dim["x"] + dim["w"],
                "y2": dim["y"] + dim["h"],
            }))
    touching.sort(key=lambda i: i[1]["y1"])
    touching.sort(key=lambda i: i[1]["x1"])
    return touching




def contains(o: dict[str, int], i: dict[str, int]) -> bool:
    return o["x"] <= i["x"] and o["y"] <= i["y"]\
        and o["x"] + o["w"] >= i["x"] + i["w"]\
        and o["y"] + o["h"] >= i["y"] + i["h"]


def touches(a: dict[str, int], b: dict[str, int]) -> bool:
    # touching, but not at corners
    above = a["x"] + a["w"] == b["x"]
    left  = a["y"] + a["h"] == b["y"]
    below = b["x"] + b["w"] == a["x"]
    right = b["y"] + b["h"] == a["y"]
    return  (above != left) or (below != right)


def intersects(a: dict[str, int], b: dict[str, int]) -> bool:
    # https://www.geeksforgeeks.org/dsa/find-two-rectangles-overlap/
    aw = a["x"] + a["w"]
    ah = a["y"] + a["h"]
    bw = b["x"] + b["w"]
    bh = b["y"] + b["h"]
    return not (a["x"] <= bw and b["x"] <= aw and a["y"] <= bh and b["y"] <= ah)


def extend_with_dim(box: dict[str, int], dim: dict[str, int]):
    box["x1"] = min(box["x1"], dim["x"])
    box["y1"] = min(box["y1"], dim["y"])
    box["x2"] = max(box["x2"], dim["x"] + dim["w"])
    box["y2"] = max(box["y2"], dim["y"] + dim["h"])



def move_bbs(touching: List[Tuple[List[str], dict[str, int]]]) -> List[Tuple[str, int, int]]:
    offsets: List[Tuple[str, int, int]] = [(o, 0, 0) for o in touching[0][0]]

    tbox: dict[str, int] = touching[0][1]
    for outs, dim in touching[1:]:
        dx, dy = minmove(dim, tbox)
        offsets += [(o, dx, dy) for o in outs]
        extend_with_bb(tbox, dim)
    return offsets


def minmove(a: dict[str, int], b: dict[str, int]) -> Tuple[int, int]:
    from math import sqrt
    def dist(x1, y1, x2, y2): return sqrt((x1-x2)**2 + (y1-y2)**2)
    retdx = b["x1"] - a["x1"]
    retdy = b["y2"] - a["y1"]
    mindelt = dist(a["x1"], a["y1"], b["x1"], b["y2"])
    if dist(a["x1"], a["y1"], b["x2"], b["y1"]) < mindelt:
        retdx = b["x2"] - a["x1"]
        retdy = b["y1"] - a["y1"]
        mindelt = dist(a["x1"], a["y1"], b["x2"], b["y1"])
    if dist(a["x1"], a["y2"], b["x1"], b["y1"]) < mindelt:
        retdx = b["x1"] - a["x1"]
        retdy = b["y1"] - a["y2"]
        mindelt = dist(a["x1"], a["y2"], b["x1"], b["y1"])
    if dist(a["x2"], a["y1"], b["x1"], b["y1"]) < mindelt:
        retdx = b["x1"] - a["x2"]
        retdy = b["y1"] - a["y1"]
    return retdx, retdy


def extend_with_bb(a: dict[str, int], b: dict[str, int]):
    a["x1"] = min(a["x1"], b["x1"])
    a["y1"] = min(a["y1"], b["y1"])
    a["x2"] = max(a["x2"], b["x2"])
    a["y2"] = max(a["y2"], b["y2"])


import json
from sys import argv
outputs = json.loads(argv[1])
for out, dx, dy in move_bbs(collect_touching()):
    if dx != 0: print('X["{}"]="{}"'.format(out, outputs[out]["x"] + dx))
    if dy != 0: print('Y["{}"]="{}"'.format(out, outputs[out]["y"] + dy))
