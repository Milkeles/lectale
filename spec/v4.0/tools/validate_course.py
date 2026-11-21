#!/usr/bin/env python3
"""Read-only v3 course.yaml validator; safe loader, JSON Schema + key semantic checks.
Usage: python tools/validate_course.py path/to/course.yaml [--check-paths]
Do not treat this sample as a complete authorization validator; the Worker does all ACL checks.
"""
import argparse, json, sys, re, os
from pathlib import Path
from urllib.parse import urlparse
import yaml
from jsonschema import Draft202012Validator, FormatChecker
ROOT = Path(__file__).resolve().parents[1]
class NoDuplicateSafeLoader(yaml.SafeLoader):
    pass

def map_constructor(loader, node):
    pairs = loader.construct_pairs(node, deep=True)
    result = {}
    for k,v in pairs:
        if not isinstance(k,(int,float,str,bool)) or k in result:
            raise ValueError(f'Duplicate/unsafe YAML key: {k!r}')
        result[k]=v
    return result
NoDuplicateSafeLoader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, map_constructor)

def safe_read(path):
    raw=Path(path).read_bytes()
    if len(raw)>1024*1024:raise ValueError('Manifest exceeds 1 MiB')
    txt=raw.decode('utf-8','strict')
    for event in yaml.parse(txt):
        if isinstance(event,yaml.events.AliasEvent) or getattr(event,'anchor',None):
            raise ValueError('YAML aliases and anchors are forbidden')
        if getattr(event,'tag',None) and event.tag.startswith('!'):
            raise ValueError('Explicit custom YAML tags are forbidden')
    docs=list(yaml.load_all(txt,Loader=NoDuplicateSafeLoader))
    if len(docs)!=1 or not isinstance(docs[0],dict):
        raise ValueError('Exactly one YAML mapping is required')
    return docs[0]

def inspect(o,root,check_paths):
    errors=[]; seen=set(); counted=[0,0]; assignment_ids={a['id'] for a in o['assignments']}; refs=[]
    if len(assignment_ids)!=len(o['assignments']):errors.append('Duplicate assignment IDs')
    def pathcheck(resource):
        p=resource.get('path')
        if p is None:return
        parts=p.split('/')
        if p.startswith('/') or any(x in ('','.', '..') for x in parts) or '\\' in p:
            errors.append(f'Invalid resource path: {p}');return
        if any(x.startswith('.') and x not in ('.well-known',) for x in parts): errors.append(f'Hidden path not allowed: {p}')
        if any(x in ('.git','.github') for x in parts): errors.append(f'Unsafe directory path: {p}')
        if check_paths:
            pp=(root/p)
            if not pp.exists():errors.append(f'Missing referenced resource path: {p}')
            elif pp.is_symlink():errors.append(f'Symlink resource forbidden: {p}')
            elif not pp.resolve().is_relative_to(root.resolve()):errors.append(f'Path escapes repository: {p}')
    def resources(items):
        counted[1]+=len(items)
        ids=[r['id'] for r in items]
        if len(ids)!=len(set(ids)):errors.append('Duplicate resource id within resource list')
        for r in items:
            pathcheck(r)
            if r['type']=='video' and 'url' in r:
                u=urlparse(r['url']);h=(u.hostname or '').lower()
                pv=r.get('provider')
                if pv=='youtube' and h not in ('youtube.com','www.youtube.com','youtu.be','www.youtube-nocookie.com'):
                    errors.append(f'Provider mismatch: {pv}, {h}')
                if pv=='vimeo' and h not in ('vimeo.com','www.vimeo.com','player.vimeo.com'):
                    errors.append(f'Provider mismatch: {pv}, {h}')
            if r['type']=='folder' and check_paths:
                pp=root/r['path']
                if pp.exists() and not pp.is_dir():errors.append(f'Expected folder at {r["path"]}')
    def nodes(items, depth=1):
        if depth>5:errors.append('Max outline nesting depth 5 exceeded')
        counted[0]+=len(items)
        for n in items:
            if n['id'] in seen:errors.append(f'Duplicate outline node ID {n["id"]}')
            seen.add(n['id'])
            if n['kind']=='module':nodes(n['children'],depth+1)
            if n['kind']=='lesson':resources(n['resources'])
            if n['kind']=='assignment':refs.append(n['assignmentId'])
    nodes(o['outline'])
    for a in o['assignments']:
        resources(a['materials'])
        r=a['submission'];
        if r['maxAttemptBytes']<r['maxFileBytes']:
            errors.append(f'Invalid attempt size limit for {a["id"]}')
        from datetime import datetime
        ts=[]
        for key in ('openAt','dueAt','closeAt'):
            if r.get(key): ts.append((key,datetime.fromisoformat(r[key].replace('Z','+00:00'))))
        if any(ts[i][1]>ts[i+1][1] for i in range(len(ts)-1)):
            errors.append(f'Dates out of order for {a["id"]}')
    if counted[0]>2000:errors.append('More than 2,000 outline nodes')
    if counted[1]>10000:errors.append('More than 10,000 resources')
    for ref in refs:
        if ref not in assignment_ids:errors.append(f'Unknown referenced assignment {ref}')
    for k in assignment_ids-set(refs):errors.append(f'Assignment not referenced in outline: {k}')
    return errors

def main():
    ap=argparse.ArgumentParser();ap.add_argument('manifest',type=Path);ap.add_argument('--check-paths',action='store_true');a=ap.parse_args()
    try:
        o=safe_read(a.manifest)
        s=json.loads((ROOT/'schemas/course-v3.schema.json').read_text())
        problems=[]
        for e in Draft202012Validator(s,format_checker=FormatChecker()).iter_errors(o):
            problems.append(f'Schema /{ "/".join(map(str,e.absolute_path)) }: {e.message}')
        if not problems: problems+=inspect(o,a.manifest.parent,a.check_paths)
        if problems:
            print('\n'.join('ERROR: '+p for p in problems),file=sys.stderr);sys.exit(1)
        print('OK: valid course.yaml v3'+(' with checked paths' if a.check_paths else ' (referenced paths not checked)'))
    except Exception as e:
        print(f'ERROR: {e}',file=sys.stderr);sys.exit(2)
if __name__=='__main__':main()
