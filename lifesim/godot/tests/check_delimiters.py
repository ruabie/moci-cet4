#!/usr/bin/env python3
"""Best-effort delimiter checker for GDScript files (not a parser)."""
from pathlib import Path
import sys
root=Path(__file__).resolve().parents[1]
problems=[]
for f in (root/'scripts').glob('*.gd'):
    s=f.read_text()
    stack=[]
    line=1
    inside=None
    comment=False
    backslash=False
    for ch in s:
        if ch=='\n':
            line+=1; comment=False; backslash=False
            if inside is None: continue
        if comment: continue
        if inside:
            if backslash: backslash=False; continue
            if ch=='\\': backslash=True; continue
            if ch==inside: inside=None
            continue
        if ch=='#': comment=True; continue
        if ch in '"\'': inside=ch; continue
        if ch in '([{': stack.append((ch,line))
        if ch in ')]}':
            pairs={')':'(',']':'[','}':'{'}
            if not stack or stack[-1][0]!=pairs[ch]: problems.append(f'{f.name}:{line}: unexpected {ch}')
            else: stack.pop()
    if stack: problems.append(f'{f.name}: unmatched {stack!r}')
for p in problems: print('ERROR:',p)
if problems: sys.exit(1)
print('PASS: GDScript delimiter sanity check (not actual Godot parser)')
