#!/usr/bin/env python3
"""Report of an allocation profile written by tools/perf/alloc/hook.cpp.

Usage: tools/perf/allocreport.py <hxperf-alloc.txt> <Tsgo binary> [--top N] [--class NAME] [--folded FILE]
Prints: allocations per class (exact), sampled bytes per allocating function (innermost frame in
ts/go/haxe code, i.e. the site that allocates), inclusive bytes per function, and the top stacks of
--class NAME. --folded writes folded stacks (flamegraph.pl input)."""
import bisect, subprocess, sys, collections

args = sys.argv[1:]
data, binary = args[0], args[1]
top = int(args[args.index("--top") + 1]) if "--top" in args else 30
cls = args[args.index("--class") + 1] if "--class" in args else None
folded = args[args.index("--folded") + 1] if "--folded" in args else None

syms = []
for line in subprocess.run(["nm", "-C", "-n", "--defined-only", binary], capture_output=True, text=True).stdout.splitlines():
    parts = line.split(" ", 2)
    if len(parts) == 3 and parts[1] in "tTwW":
        syms.append((int(parts[0], 16), parts[2]))
addrs = [a for a, _ in syms]
cache = {}
def sym(pc):
    if pc not in cache:
        i = bisect.bisect_right(addrs, pc) - 1
        n = syms[i][1] if i >= 0 else "?"
        # shorten: drop argument lists and hxcpp suffixes
        p = n.find("(")
        if p > 0 and not n.startswith("operator"):
            n = n[:p] + n[n.rfind(")") + 1:] if "::_hx_Closure" not in n else n
        cache[pc] = n.replace("hx::ObjectPtr<", "").replace("_obj::", ".").replace("::", ".")
    return cache[pc]

RUNTIME = ("hxperf_", "__wrap_", "hx.", "Array_obj", "Array_", "String.", "StringBuf", "cpp.", "Dynamic.", "(anonymous namespace)")
def is_runtime(n):
    return n.startswith(RUNTIME) or n.startswith("ArrayBase") or n.startswith("String ") or n == "?"

classes = []
stacks = []
sample = 0
for line in open(data):
    if line.startswith("class "):
        _, c, b, name = line.rstrip("\n").split(" ", 3)
        classes.append((int(b), int(c), name))
    elif line.startswith("stack "):
        head, name = line.rstrip("\n").split(" | ", 1)
        f = head.split()
        stacks.append((int(f[1]), [sym(int(x, 16)) for x in f[2:]], name))
    elif line.startswith("sample "):
        sample = int(line.split()[1])

tb = sum(b for b, _, _ in classes); tc = sum(c for _, c, _ in classes)
print(f"total {tc:,} allocations, {tb / 1e6:,.0f} MB (sample every {sample} bytes, {len(stacks)} distinct stacks)\n")
print("== allocations per class (exact)")
print(f"{'MB':>8} {'%':>5} {'count':>12}  class")
for b, c, n in sorted(classes, reverse=True)[:top]:
    print(f"{b / 1e6:8.1f} {100 * b / tb:5.1f} {c:12,}  {n}")

sb = sum(w for w, _, _ in stacks)
site = collections.Counter(); incl = collections.Counter(); sitecls = collections.defaultdict(collections.Counter)
for w, fr, name in stacks:
    s = next((f for f in fr if not is_runtime(f)), fr[0] if fr else "?")
    site[s] += w; sitecls[s][name] += w
    for f in set(fr):
        incl[f] += w
print("\n== sampled bytes per allocating site (innermost non-runtime frame)")
for s, w in site.most_common(top):
    cl = ", ".join(f"{n} {100 * x / w:.0f}%" for n, x in sitecls[s].most_common(3))
    print(f"{100 * w / sb:5.1f}%  {s}   [{cl}]")
print("\n== sampled bytes per function, inclusive")
for s, w in incl.most_common(top):
    print(f"{100 * w / sb:5.1f}%  {s}")
if cls:
    print(f"\n== top stacks of class {cls}")
    st = collections.Counter()
    for w, fr, name in stacks:
        if name == cls:
            st[" <- ".join([f for f in fr if not is_runtime(f)][:6])] += w
    tot = sum(st.values()) or 1
    for s, w in st.most_common(top):
        print(f"{100 * w / tot:5.1f}%  {s}")
if folded:
    with open(folded, "w") as out:
        agg = collections.Counter()
        for w, fr, name in stacks:
            agg[";".join(reversed(fr)) + ";" + name] += w
        for k, w in agg.items():
            out.write(f"{k} {w}\n")
