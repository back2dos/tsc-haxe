#!/usr/bin/env python3
"""Compare generated skeleton signatures with a hand-ported Haxe package.

usage: compare.py <pkg> <generated dir> <hand dir> [-v]
  e.g. compare.py binder bin/skeleton/binder/ts/binder src/ts/binder

Identity of every Go func comes from the generated `throw "unported: pkg.Recv.Name (...)"`.
A function is keyed by (receiver Haxe class or "<pkg>", Go name). Hand-port functions are keyed the
same way: instance method → its class; static → package func if Go has one with that name, else
an extension method when the first parameter type is a receiver Go has that method on.
"""
import os
import re
import sys
from collections import defaultdict


def strip_comments_strings(src):
    out = []
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if src.startswith('//', i):
            j = src.find('\n', i)
            j = n if j < 0 else j
            out.append(' ' * (j - i))
            i = j
        elif src.startswith('/*', i):
            j = src.find('*/', i + 2)
            j = n if j < 0 else j + 2
            out.append(re.sub(r'[^\n]', ' ', src[i:j]))
            i = j
        elif c in '"\'':
            j = i + 1
            while j < n and src[j] != c:
                j += 2 if src[j] == '\\' else 1
            out.append(c + ' ' * (j - i - 1) + c)
            i = j + 1
        else:
            out.append(c)
            i += 1
    return ''.join(out)


DECL = re.compile(r'\b(class|interface|abstract|typedef|enum)\s+([A-Za-z_]\w*)')


def balanced(s, i, open_, close):
    depth = 0
    for j in range(i, len(s)):
        if s[j] == open_:
            depth += 1
        elif s[j] == close:
            depth -= 1
            if depth == 0:
                return j
    return len(s) - 1


def split_top(s):
    parts, depth, cur = [], 0, ''
    for ch in s:
        if ch in '(<[{':
            depth += 1
        elif ch in ')>]}':
            depth -= 1
        if ch == ',' and depth == 0:
            parts.append(cur)
            cur = ''
        else:
            cur += ch
    if cur.strip():
        parts.append(cur)
    return parts


def norm_type(t):
    t = re.sub(r'\s+', '', t)
    t = t.replace('->', '→')
    t = re.sub(r'(?<![\w.])(?:[a-z_]\w*\.)+(?=[A-Z])', '', t)  # package path
    for _ in range(3):
        t = re.sub(r'\b([A-Z]\w*)\.(?=[A-Z])', '', t)  # Module.Type
    t = re.sub(r'Null<([^<>]*(?:<[^<>]*>)?)>', r'\1', t)
    t = re.sub(r'([(,])(?:\.\.\.)?\??\w+:', r'\1', t)  # parameter names in function types
    t = t.replace('()→', 'Void→')
    t = re.sub(r'^\(([^(),]*)\)→', r'\1→', t)
    return t


def parse_params(p):
    res = []
    for part in split_top(p):
        part = part.strip()
        if not part:
            continue
        rest = part.startswith('...')
        part = part.lstrip('.').lstrip('?')
        m = re.match(r'(\w+)\s*(?::(.*?))?(?:=.*)?$', part, re.S)
        name, typ = m.group(1), (m.group(2) or 'Dynamic')
        res.append((name, ('...' if rest else '') + norm_type(typ)))
    return res


def parse_file(path):
    raw = open(path, encoding='utf-8').read()
    src = strip_comments_strings(raw)
    funcs = []
    depth = 0
    cls_stack = []  # (depth, name, kind)
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if c == '{':
            depth += 1
            i += 1
            continue
        if c == '}':
            depth -= 1
            while cls_stack and cls_stack[-1][0] > depth:
                cls_stack.pop()
            i += 1
            continue
        if depth == 0:
            m = DECL.match(src, i)
            if m and (i == 0 or not (src[i - 1].isalnum() or src[i - 1] == '_')):
                kind, name = m.group(1), m.group(2)
                if kind == 'enum' and src[m.end():].lstrip().startswith('abstract'):
                    pass
                TYPES.append((name if kind != 'enum' else (re.match(r'enum\s+abstract\s+(\w+)', src[i:]) or m).group(1), 'enum abstract' if src.startswith('enum', i) else kind, os.path.basename(path)))
                if kind in ('class', 'interface', 'abstract') or (kind == 'enum' and 'abstract' in src[i:i + 20]):
                    if kind == 'enum':
                        mm = re.match(r'enum\s+abstract\s+(\w+)', src[i:])
                        name = mm.group(1) if mm else name
                        kind = 'abstract'
                    j = src.find('{', m.end())
                    semi = src.find(';', m.end())
                    if j >= 0 and (semi < 0 or j < semi):
                        cls_stack.append((depth + 1, name, kind))
                        i = j
                        continue
                i = m.end()
                continue
        if depth == 1 and cls_stack and cls_stack[-1][2] == 'class' and (src.startswith('var', i) or src.startswith('final', i)) and not (src[i - 1].isalnum() or src[i - 1] == '_'):
            line_start = src.rfind('\n', 0, i) + 1
            mods = src[line_start:i]
            m = re.match(r'(?:var|final)\s+(\w+)\s*(?:\([^)]*\))?\s*:\s*', src[i:])
            if m and 'static' not in mods:
                j = i + m.end()
                d = 0
                while j < n:
                    ch = src[j]
                    if ch in '(<':
                        d += 1
                    elif ch in ')>' and not (ch == '>' and src[j - 1] == '-'):
                        d -= 1
                    elif ch in '=;' and d <= 0:
                        break
                    j += 1
                FIELDS.append((cls_stack[-1][1], m.group(1), norm_type(src[i + m.end():j]), os.path.basename(path)))
                i = j
                continue
        if depth == 1 and cls_stack and src.startswith('function', i) and not (src[i - 1].isalnum() or src[i - 1] == '_') and not src[i + 8].isalnum():
            line_start = src.rfind('\n', 0, i) + 1
            mods = src[line_start:i]
            m = re.match(r'function\s+(\w+)\s*(<[^(]*>)?\s*\(', src[i:])
            if m:
                p0 = i + m.end() - 1
                p1 = balanced(src, p0, '(', ')')
                params = src[p0 + 1:p1]
                k = p1 + 1
                ret = ''
                rest = src[k:]
                mr = re.match(r'\s*:', rest)
                if mr:
                    # return type until '{' or ';' at depth 0 of () and <>
                    j = k + mr.end()
                    d = 0
                    while j < n:
                        ch = src[j]
                        if ch in '(<':
                            d += 1
                        elif ch in ')>' and not (ch == '>' and src[j - 1] == '-'):
                            d -= 1
                        elif ch in '{;' and d <= 0:
                            break
                        j += 1
                    ret = src[k + mr.end():j]
                else:
                    ret = 'Void?'
                # body text (raw) for the generated identity
                funcs.append({
                    'cls': cls_stack[-1][1], 'clskind': cls_stack[-1][2], 'name': m.group(1),
                    'static': bool(re.search(r'\bstatic\b', mods)),
                    'params': parse_params(params), 'ret': norm_type(ret) if ret != 'Void?' else 'Void?',
                    'file': os.path.basename(path), 'pos': i, 'raw': raw, 'end': p1,
                })
                i = p1 + 1
                continue
        i += 1
    return funcs


TYPES = []
FIELDS = []
UNPORTED = re.compile(r'unported: ([\w.]+) \(([\w.]+):(\d+)\)')


def load_dir(d):
    del TYPES[:]
    del FIELDS[:]
    res = []
    for f in sorted(os.listdir(d)):
        if f.endswith('.hx') and f != 'import.hx':
            res += parse_file(os.path.join(d, f))
    return res


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('-')]
    verbose = '-v' in sys.argv
    pkg, gdir, hdir = args
    gen = load_dir(gdir)
    gtypes, gfields = list(TYPES), list(FIELDS)
    hand = load_dir(hdir)
    htypes, hfields = list(TYPES), list(FIELDS)
    gkeys = {}
    for f in gen:
        if f['clskind'] == 'interface':
            f['go'] = pkg + '.' + f['cls'] + '.' + f['name']
            f['goloc'] = 'interface'
            gkeys[(f['cls'], f['name'])] = f
            continue
        m = UNPORTED.search(f['raw'], f['end'], f['end'] + 600)
        if not m or 'function ' in f['raw'][f['end']:m.start()]:
            continue
        ident = m.group(1).split('.')
        f['go'] = m.group(1)
        f['goloc'] = m.group(2) + ':' + m.group(3)
        if len(ident) == 3:
            if f['static']:
                recv = f['params'][0][1]
                f['params'] = f['params'][1:]
                f['ext'] = True
            else:
                recv = f['cls']
            key = (re.sub(r'<.*', '', recv), ident[2])
        else:
            key = ('<pkg>', ident[1])
        gkeys[key] = f
    hkeys = {}
    extra = []
    for f in hand:
        name = f['name']
        if name == 'new' or (f['static'] and name in ('or', 'and', 'not', 'xor') and f['clskind'] == 'abstract'):
            continue
        cands = [name, name.rstrip('_')]
        key = None
        if not f['static'] or f['clskind'] == 'interface':
            for nm in cands:
                if (f['cls'], nm) in gkeys:
                    key = (f['cls'], nm)
                    break
        else:
            for nm in cands:
                if ('<pkg>', nm) in gkeys:
                    key = ('<pkg>', nm)
                    break
            if key is None and f['params']:
                recv = re.sub(r'<.*', '', f['params'][0][1])
                for nm in cands:
                    if (recv, nm) in gkeys and gkeys[(recv, nm)].get('ext', False) or (recv, nm) in gkeys:
                        key = (recv, nm)
                        f['params'] = f['params'][1:]
                        f['ext'] = True
                        break
        if key is None:
            extra.append(f)
        elif key in hkeys:
            extra.append(f)
        else:
            hkeys[key] = f
    total = len(gkeys)
    same = 0
    diffs = defaultdict(list)
    for key, g in sorted(gkeys.items()):
        h = hkeys.get(key)
        if h is None:
            diffs['missing in hand port'].append(f"{g['go']} ({g['goloc']})")
            continue
        problems = []
        if g['cls'] != h['cls'] or g['file'] != h['file']:
            problems.append(f"location gen {g['file']}:{g['cls']} hand {h['file']}:{h['cls']}")
        if bool(g.get('ext')) != bool(h.get('ext')) or g['static'] != h['static']:
            problems.append(f"static/instance gen static={g['static']} hand static={h['static']}")
        gp = [t for _, t in g['params']]
        hp = [t for _, t in h['params']]
        if len(gp) != len(hp):
            problems.append(f"param count gen {len(gp)} {gp} hand {len(hp)} {hp}")
        elif gp != hp:
            problems.append(f"param types gen {gp} hand {hp}")
        if g['ret'] != h['ret']:
            problems.append(f"return gen {g['ret']} hand {h['ret']}")
        sig_ok = not any(p.startswith(('param', 'return', 'static')) for p in problems)
        if not problems:
            same += 1
        for p in problems:
            cat = p.split(' gen ')[0]
            diffs[cat].append(f"{g['go']} ({g['goloc']}): {p}")
        if sig_ok:
            diffs['_sigok'].append(g['go'])
    sig_same = len(diffs.pop('_sigok', []))
    matched = sum(1 for k in gkeys if k in hkeys)
    print(f"{pkg}: Go funcs/methods {total}, found in hand port {matched}, identical incl. location {same} ({100.0 * same / total:.1f}%), "
          f"identical signature {sig_same} ({100.0 * sig_same / total:.1f}%)")
    for cat, items in sorted(diffs.items()):
        print(f"  {cat}: {len(items)}")
        if verbose:
            for it in items:
                print(f"    {it}")
    print(f"  hand-port only (helpers, PORT additions): {len(extra)}")
    if verbose:
        for f in extra:
            print(f"    {f['file']}:{f['cls']}.{f['name']} static={f['static']}")
    # types and fields
    ht = {t[0]: t for t in htypes}
    tdiff = []
    for name, kind, file in gtypes:
        h = ht.get(name)
        if h is None:
            tdiff.append(f"type {name} ({kind}, {file}): missing in hand port")
        elif h[1] != kind or h[2] != file:
            tdiff.append(f"type {name}: gen {kind} {file}, hand {h[1]} {h[2]}")
    hf = {(c, n): t for c, n, t, _ in hfields}
    fsame, fdiff = 0, []
    for c, n, t, _ in gfields:
        h = hf.get((c, n))
        if h is None:
            fdiff.append(f"field {c}.{n}:{t}: missing in hand port")
        elif h != t:
            fdiff.append(f"field {c}.{n}: gen {t} hand {h}")
        else:
            fsame += 1
    print(f"  types: gen {len(gtypes)}, differences {len(tdiff)}; fields: gen {len(gfields)}, identical {fsame}, differences {len(fdiff)}")
    if verbose:
        for d in tdiff + fdiff:
            print(f"    {d}")
    return
    if verbose:
        for f in extra:
            print(f"    {f['file']}:{f['cls']}.{f['name']} static={f['static']}")


if __name__ == '__main__':
    main()
