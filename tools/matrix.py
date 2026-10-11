#!/usr/bin/env python3
# Renders the test matrix (docs/MATRIX.md) from the logs of tools/matrix.sh. It parses the result
# tables that the gates print; it does not compare anything itself.
# Usage: matrix.py <runs.txt> <versions.txt> <commit> <command line> <targets> <out.md>
import datetime
import re
import sys

ALL = ['js', 'cpp', 'jvm', 'cs', 'py']
KINDS = ['errors', 'types', 'symbols', 'js', 'map', 'sourcemap', 'trace']
ROWS = [('unit', 'unit tests (checks)')] + \
    [('scanner-normal', 'scanner (files)'), ('scanner-trivia', 'scanner -trivia (files)'),
     ('parser', 'parser (files)'), ('binder', 'binder (files)'), ('printer', 'printer (files)')] + \
    [('checker-' + k, f'checker {k} (cases)') for k in KINDS] + \
    [('tsc', 'tsc + tsc -b (scenarios)'), ('realworld', 'real projects (compiler runs)')]
KNOWN_TSC = 'show-help-with-ExitStatus.DiagnosticsPresent_OutputsSkipped'

runs_file, versions_file, commit, cmdline, targets, out = sys.argv[1:7]
targets = targets.split()
cells = {}  # (row, target) -> dict(pass, total, ms, note, bad)


def put(row, t, passed, total, ms, sample, note='', bad=None):
    if bad is None:
        bad = passed != total
    cells[(row, t)] = dict(passed=passed, total=total, ms=ms, sample=int(sample), note=note, bad=bad)


def lines(path):
    try:
        with open(path, encoding='utf-8', errors='replace') as f:
            return f.read().split('\n')
    except OSError:
        return []


for line in open(runs_file):
    suite, ts, sample, path = line.split()
    ts = ts.split(',')
    text = lines(path)
    if suite == 'unit':
        t = ts[0]
        ms = None
        for l in text:
            m = re.match(r'^(\d+) checks, (\d+) failures', l)
            if m:
                n, f = int(m.group(1)), int(m.group(2))
                put('unit', t, n - f, n, None, sample)
            m = re.match(r'^time \S+ (\d+)$', l)
            if m:
                ms = int(m.group(1))
        if ('unit', t) in cells:
            cells[('unit', t)]['ms'] = ms
    elif suite == 'scanner':
        for l in text:
            m = re.match(r'^(normal|trivia)\s+(\w+)\s+(\d+)\s+(\d+)\s+(\d+)\s*$', l)
            if m and m.group(2) in ts:
                files, diffs = int(m.group(3)), int(m.group(4))
                go = [g for g in text if re.match(rf'^{m.group(1)}\s+go\s+', g)]
                total = int(go[0].split()[2]) if go else files
                put('scanner-' + m.group(1), m.group(2), min(files, total) - diffs, total, int(m.group(5)), sample)
    elif suite in ('parser', 'binder', 'printer'):
        go = [g for g in text if re.match(r'^go\s+\d+\s+-', g)]
        total = int(go[0].split()[1]) if go else None
        for l in text:
            m = re.match(r'^(\w+)\s+(\d+)\s+(\d+)\s+(\d+)', l)
            if m and m.group(1) in ts:
                files, diffs = int(m.group(2)), int(m.group(3))
                tot = total if total is not None else files
                put(suite, m.group(1), min(files, tot) - diffs, tot, int(m.group(4)), sample)
    elif suite == 'checker':
        cur = None
        for l in text:
            m = re.match(r'^== (\w+)$', l)
            if m:
                cur = m.group(1)
                continue
            m = re.match(r'^(\w+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s*$', l)
            if m and cur in ts and m.group(1) in KINDS:
                cases, p, f, c, s = (int(x) for x in m.groups()[1:])
                note = ''
                if f or c:
                    note = f'{f} fail, {c} crash'
                put('checker-' + m.group(1), cur, p, cases - s, None, sample, note, bool(f or c))
            m = re.match(r'^time (\w+) (\d+)$', l)
            if m and m.group(1) in ts:
                for k in KINDS:
                    if ('checker-' + k, m.group(1)) in cells:
                        cells[('checker-' + k, m.group(1))]['ms'] = int(m.group(2))
    elif suite == 'tsc':
        cur = None
        fails = {}
        for l in text:
            m = re.match(r'^(\w+): scenarios=(\d+) pass=(\d+) fail=(\d+) crash=(\d+) \((\d+) ms\)', l)
            if m and m.group(1) in ts:
                cur = m.group(1)
                fails[cur] = []
                put('tsc', cur, int(m.group(3)), int(m.group(2)), int(m.group(6)), sample)
                continue
            m = re.match(r'^\s+(FAIL|CRASH) (\S+)', l)
            if m and cur:
                fails[cur].append(m.group(2))
        for t, fl in fails.items():
            if fl and all(KNOWN_TSC in f for f in fl):
                cells[('tsc', t)]['note'] = 'known¹'
                cells[('tsc', t)]['bad'] = False
    elif suite == 'realworld':
        acc = {}
        for l in text:
            f = l.split()
            if len(f) == 10 and f[3] in ts and re.match(r'^[\d.]+$', f[4]):
                a = acc.setdefault(f[3], [0, 0, 0.0])
                a[1] += 1
                a[2] += float(f[4])
                if f[8] == '0' and f[9] == 'yes':
                    a[0] += 1
        for t, (p, n, secs) in acc.items():
            put('realworld', t, p, n, int(secs * 1000), sample, 'tsc-extension only' if int(sample) > 1 else '')


def cell(row, t):
    c = cells.get((row, t))
    if c is None:
        return '—'
    s = f"{c['passed']}/{c['total']}"
    if c['bad']:
        s = f'**{s}** ✗'
    extra = []
    if c['sample'] > 1 and row != 'realworld':
        extra.append(f"1/{c['sample']}")
    if c['note']:
        extra.append(c['note'])
    if extra:
        s += ' (' + ', '.join(extra) + ')'
    return s


def tcell(row, t):
    c = cells.get((row, t))
    if c is None or c['ms'] is None:
        return '—'
    return f"{c['ms'] / 1000:.1f}"


# time per suite group: the checker kinds share one run, the scanner modes are separate runs
TIME_ROWS = [('unit', 'unit tests'), ('scanner-normal', 'scanner'), ('scanner-trivia', 'scanner -trivia'),
             ('parser', 'parser'), ('binder', 'binder'), ('printer', 'printer'),
             ('checker-errors', 'checker (all kinds, one run)'), ('tsc', 'tsc + tsc -b'), ('realworld', 'real projects')]

o = []
o.append('# Test matrix')
o.append('')
o.append(f'Generated {datetime.date.today().isoformat()} by `{cmdline.strip()}` at commit `{commit}`.')
o.append('Regenerate: `make matrix` (or `tools/matrix.sh --help`). Only the targets that were run have values.')
o.append('')
o.append('Each cell: passed/total. **Bold** with ✗: failures. "(1/N)": only every N-th input (deterministic sample).')
o.append('"—": not run (see Notes).')
o.append('')
o.append('| Suite | ' + ' | '.join(ALL) + ' |')
o.append('|---|' + '---|' * len(ALL))
for row, label in ROWS:
    o.append(f'| {label} | ' + ' | '.join(cell(row, t) for t in ALL) + ' |')
o.append('')
o.append('## Wall time (seconds)')
o.append('')
o.append('Run time of the target only (no build, no Go reference). The checker gate runs in parallel processes.')
o.append('')
o.append('| Suite | ' + ' | '.join(ALL) + ' |')
o.append('|---|' + '---|' * len(ALL))
for row, label in TIME_ROWS:
    o.append(f'| {label} | ' + ' | '.join(tcell(row, t) for t in ALL) + ' |')
tot = []
for t in ALL:
    ms = [cells[(r, t)]['ms'] for r, _ in TIME_ROWS if (r, t) in cells and cells[(r, t)]['ms'] is not None]
    tot.append(f'{sum(ms) / 1000:.1f}' if ms else '—')
o.append('| **total** | ' + ' | '.join(tot) + ' |')
o.append('')
o.append('## Notes')
o.append('')
o.append(f'¹ tsc: `{KNOWN_TSC}` fails on every target: the upstream reference is stale (upstream\'s own Go test fails on it at the pin; the output is identical to Go\'s actual output).')
o.append('')
for t in ALL:
    if t not in targets:
        o.append(f'- {t}: not selected in this run (`--targets`).')
    else:
        missing = [label for row, label in ROWS if (row, t) not in cells]
        if missing:
            o.append(f'- {t}: no result for ' + ', '.join(missing) + ' (not selected, or the build/run failed: see bin/matrix/*.log).')
if any(c['sample'] > 1 for (r, _), c in cells.items() if r == 'realworld'):
    o.append('- Sampled real projects: only `tsc-extension` (2 compiler runs) is compiled.')
o.append('')
o.append('## Toolchains')
o.append('')
o.append('| Tool | Version |')
o.append('|---|---|')
for l in open(versions_file):
    k, _, v = l.strip().partition(' ')
    o.append(f'| {k} | {v} |')
o.append('')
with open(out, 'w') as f:
    f.write('\n'.join(o))
