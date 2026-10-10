#!/usr/bin/env python3
"""Immediate callers of hot functions in a `perf record --call-graph fp` profile.

Usage: tools/perf/callers.py <perf.data> <regex> [--depth N] [--top N]
For every sample whose leaf (self) frame matches <regex>, counts the caller chain of N frames
(default 1) above the matching frames; prints the share of all samples."""
import re, subprocess, sys, collections
data, pat = sys.argv[1], re.compile(sys.argv[2])
depth = int(sys.argv[sys.argv.index("--depth") + 1]) if "--depth" in sys.argv else 1
top = int(sys.argv[sys.argv.index("--top") + 1]) if "--top" in sys.argv else 15
out = subprocess.run(["perf", "script", "-i", data, "-F", "ip,sym", "--no-demangle"], capture_output=True, text=True).stdout
dem = {}
def demangle(names):
    todo = [n for n in names if n not in dem]
    if todo:
        r = subprocess.run(["c++filt"], input="\n".join(todo), capture_output=True, text=True).stdout.split("\n")
        for a, b in zip(todo, r):
            b = re.sub(r"\(.*\)", "", b) if "_hx_Closure" not in b else b
            dem[a] = b.replace("hx::ObjectPtr<", "").replace("_obj::", ".").replace("::", ".")
total = 0; hits = collections.Counter(); matched = 0
for block in out.split("\n\n"):
    frames = [l.strip().split(" ", 1)[-1] for l in block.strip().split("\n") if l.strip()]
    if not frames:
        continue
    total += 1
    demangle(frames[:40])
    fr = [dem[f] for f in frames[:40]]
    if not pat.search(fr[0]):
        continue
    matched += 1
    i = 0
    while i < len(fr) and pat.search(fr[i]):
        i += 1
    hits[" <- ".join(fr[i:i + depth]) or "(none)"] += 1
print(f"{100 * matched / total:.2f}% of {total} samples match")
for k, n in hits.most_common(top):
    print(f"{100 * n / total:6.2f}%  {k}")
