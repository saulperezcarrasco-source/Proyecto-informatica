"""Build mode-specific RD graphs from the pinned OSM extract; no remote runtime.

RDI2 adds node-via prohibited (previous, via, next) turns to the RDI1 sections.
Complex via-way and conditional restrictions are avoided conservatively.
"""
import array
import gzip
import hashlib
import json
import math
from pathlib import Path
import struct
import sys

import numpy as np
import osmium
import shapely

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'tools/island_routing/source.osm.pbf'
OUT = ROOT / 'assets/routing'
GEOMETRY = shapely.geometry.shape(json.loads((ROOT / 'assets/national/dominican-republic.geojson').read_text(encoding='utf-8'))['geometry'])
shapely.prepare(GEOMETRY)
INTERIOR = shapely.geometry.shape(json.loads((ROOT / 'assets/national/label-interior.geojson').read_text(encoding='utf-8'))['geometry'])
shapely.prepare(INTERIOR)
YES = {'yes', 'designated', 'permissive', 'official'}
NO = {'no', 'private', 'military', 'customers', 'delivery', 'destination', 'agricultural', 'forestry', 'permit', 'dismount', 'use_sidepath'}
ROADS = {'primary', 'primary_link', 'secondary', 'secondary_link', 'tertiary', 'tertiary_link', 'unclassified', 'residential', 'living_street', 'service', 'road', 'track'}
MOTOR = ROADS | {'motorway', 'motorway_link', 'trunk', 'trunk_link'}
BIKE = ROADS | {'cycleway', 'path'}


def access(tags, mode):
    keys = ['bicycle', 'vehicle', 'access'] if mode == 'bicycle' else [mode, 'motor_vehicle', 'vehicle', 'access']
    for key in keys:
        value = tags.get(key, '')
        if value:
            return value
    return ''


def allowed(tags, mode, node=False):
    value = access(tags, mode)
    specific = ['bicycle', 'vehicle'] if mode == 'bicycle' else [mode, 'motor_vehicle', 'vehicle']
    explicit = next((tags.get(k) for k in specific if tags.get(k)), '') in YES
    if value in NO or any(tags.get(k + ':conditional') for k in [mode, 'access', 'vehicle', 'motor_vehicle']):
        return False
    if node:
        barriers = {'wall', 'fence', 'stile', 'turnstile'}
        if mode != 'bicycle':
            barriers |= {'bollard', 'block', 'cycle_barrier', 'bus_trap'}
        return explicit or (tags.get('barrier', '') not in barriers and tags.get('locked') != 'yes')
    highway = tags.get('highway', '')
    if tags.get('area') == 'yes' or tags.get('construction') or tags.get('impassable') == 'yes':
        return False
    base = BIKE if mode == 'bicycle' else MOTOR
    return highway in base or (explicit and highway in {'footway', 'pedestrian', 'path', 'bridleway', 'cycleway', 'trunk', 'trunk_link'})


def directions(tags, mode):
    specific = tags.get('oneway:' + mode)
    if specific is None and mode != 'bicycle':
        specific = tags.get('oneway:motor_vehicle')
    value = specific if specific is not None else tags.get('oneway', '')
    if not value and (tags.get('junction') == 'roundabout' or tags.get('highway') == 'motorway'):
        value = 'yes'
    return value not in {'-1', 'reverse'}, value not in {'yes', '1', 'true'}


def restriction(tags, mode):
    if mode in tags.get('except', '').split(';') or (mode != 'bicycle' and 'motor_vehicle' in tags.get('except', '').split(';')):
        return ''
    keys = [f'restriction:{mode}']
    if mode != 'bicycle': keys.append('restriction:motor_vehicle')
    keys.append('restriction')
    for key in keys:
        value = tags.get(key) or tags.get(key + ':conditional', '')
        if value:
            return value.split('@')[0].strip()
    return ''


def distance(a, b):
    lat1, lat2 = math.radians(a[0] / 1e7), math.radians(b[0] / 1e7)
    h = math.sin((lat2-lat1)/2)**2 + math.cos(lat1)*math.cos(lat2)*math.sin(math.radians((b[1]-a[1])/1e7)/2)**2
    return math.ceil(12742000 * math.asin(math.sqrt(min(1, h))) * 100) / 100


class Graph(osmium.SimpleHandler):
    def __init__(self, mode):
        super().__init__()
        self.mode, self.ids, self.coords, self.edges, self.blocked, self.rules = mode, {}, [], [], set(), []

    def node(self, node):
        if not node.tags: return
        if not allowed(node.tags, self.mode, node=True): self.blocked.add(node.id)

    def index(self, node):
        if node.ref not in self.ids:
            self.ids[node.ref] = len(self.coords)
            self.coords.append((round(node.lat*1e7), round(node.lon*1e7)))
        return self.ids[node.ref]

    def way(self, way):
        if not allowed(way.tags, self.mode): return
        forward, backward = directions(way.tags, self.mode)
        for a, b in zip(way.nodes, list(way.nodes)[1:]):
            if a.ref in self.blocked or b.ref in self.blocked or not a.location.valid() or not b.location.valid() or a.ref == b.ref: continue
            if not all(17.3 <= n.lat <= 20.1 and -72.05 <= n.lon <= -68.2 for n in (a,b)): continue
            i, j = self.index(a), self.index(b)
            length = distance(self.coords[i], self.coords[j])
            if length <= 0: continue
            if forward: self.edges.append((i,j,length,way.id))
            if backward: self.edges.append((j,i,length,way.id))

    def relation(self, rel):
        if rel.tags.get('type') != 'restriction': return
        kind = restriction(rel.tags, self.mode)
        if not kind: return
        source = [m.ref for m in rel.members if m.role == 'from' and m.type == 'w']
        target = [m.ref for m in rel.members if m.role == 'to' and m.type == 'w']
        via = [m.ref for m in rel.members if m.role == 'via' and m.type == 'n']
        viaways = [m.ref for m in rel.members if m.role == 'via' and m.type == 'w']
        self.rules.append((kind, source, target, via, viaways))


def build(mode):
    g = Graph(mode)
    print(f'{mode}: reading OSM', flush=True)
    g.apply_file(str(SOURCE), locations=True, idx='flex_mem')
    print(f'{mode}: {len(g.coords)} nodes / {len(g.edges)} edges read; clipping', flush=True)
    coords = np.asarray(g.coords, dtype='<i4')
    sources = np.fromiter((e[0] for e in g.edges), dtype='<u4')
    targets = np.fromiter((e[1] for e in g.edges), dtype='<u4')
    ways = np.fromiter((e[3] for e in g.edges), dtype='<i8')
    weights = np.fromiter((e[2] for e in g.edges), dtype='<f4')
    del g.edges, g.coords
    inside = shapely.intersects_xy(INTERIOR, coords[:,1]/1e7, coords[:,0]/1e7)
    border = np.flatnonzero(~inside)
    inside[border] = shapely.intersects_xy(GEOMETRY, coords[border,1]/1e7, coords[border,0]/1e7)
    keep = inside[sources] & inside[targets]
    avoided = {w for r in g.rules for w in r[4]}
    if avoided: keep &= ~np.isin(ways, list(avoided))
    ids = np.flatnonzero(keep)
    for start in range(0, len(ids), 50000):
        batch = ids[start:start+50000]
        points = np.stack((coords[sources[batch]][:,::-1],coords[targets[batch]][:,::-1]),axis=1)/1e7
        lines = shapely.linestrings(points)
        safe = shapely.covers(INTERIOR, lines)
        safe[~safe] = shapely.covers(GEOMETRY, lines[~safe])
        keep[batch] = safe
    sources, targets, ways, weights = sources[keep], targets[keep], ways[keep], weights[keep]
    used = np.zeros(len(coords), dtype=bool)
    used[sources] = True; used[targets] = True
    mapping = np.full(len(coords), -1, dtype=np.int32)
    n = int(used.sum())
    mapping[used] = np.arange(n, dtype=np.int32)
    sources, targets, coords = mapping[sources], mapping[targets], coords[used]
    incoming, outgoing = {}, {}
    referenced = {w for r in g.rules for w in r[1]+r[2]}
    for i in np.flatnonzero(np.isin(ways, list(referenced))):
        incoming.setdefault((int(ways[i]),int(targets[i])),set()).add(int(sources[i]))
        outgoing.setdefault((int(ways[i]),int(sources[i])),set()).add(int(targets[i]))
    order = np.lexsort((targets,sources))
    sources, targets, weights = sources[order],targets[order],weights[order]
    unique = np.ones(len(sources),dtype=bool)
    unique[1:] = (sources[1:] != sources[:-1]) | (targets[1:] != targets[:-1])
    sources, targets, weights = sources[unique],targets[unique],weights[unique]
    offsets = np.zeros(n+1,dtype='<u4')
    offsets[1:] = np.cumsum(np.bincount(sources,minlength=n),dtype=np.uint32)
    turns = set()
    for kind, fromways, toways, vianodes, viaways in g.rules:
        if viaways: continue
        for osmvia in vianodes:
            old = g.ids.get(osmvia)
            if old is None or mapping[old] < 0: continue
            via = int(mapping[old])
            previous = set().union(*(incoming.get((w,via),set()) for w in fromways))
            nexts = set().union(*(outgoing.get((w,via),set()) for w in toways))
            allnext = set(map(int,targets[offsets[via]:offsets[via+1]]))
            for prev in previous:
                specific = ({prev} & nexts) if kind.endswith('u_turn') else nexts
                forbidden = allnext-specific if kind.startswith('only_') else specific
                for nxt in forbidden: turns.add((prev,via,nxt))
    parent = list(range(n))
    def root(i):
        while parent[i] != i: parent[i] = parent[parent[i]]; i = parent[i]
        return i
    for a,b in zip(sources,targets):
        ra,rb = root(int(a)),root(int(b))
        if ra != rb: parent[rb] = ra
    components = np.fromiter((root(i) for i in range(n)),dtype='<u4',count=n)
    output = OUT / f'dominican-{mode}.rdi'
    with output.open('wb') as raw, gzip.GzipFile(fileobj=raw, mode='wb', mtime=0, filename='') as stream:
        stream.write(struct.pack('<4sII', b'RDI2',n,len(targets)))
        for section in (coords,offsets,targets.astype('<u4'),weights,components): stream.write(section.tobytes())
        stream.write(struct.pack('<I',len(turns)))
        stream.write(array.array('I',(v for t in sorted(turns) for v in t)).tobytes())
    manifest = dict(mode=mode,format='RDI2 little-endian gzip',nodes=n,directedEdges=len(targets),prohibitedTurns=len(turns),avoidedViaWays=len(avoided),bytes=output.stat().st_size,sha256=hashlib.sha256(output.read_bytes()).hexdigest(),sourceSha256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(),dataDate='2026-11-18',attribution='OpenStreetMap contributors, ODbL 1.0',policy='Mode-specific access, barriers and oneway; full node/edge national clipping; node-via turn restrictions; complex via-way restrictions avoided. Shortest distance, not traffic-aware fastest route.',limitations='Conditional access ways excluded; conditional turn restrictions applied conservatively at all times. Destination/private access excluded. OSM may be incomplete. Not field verified; no traffic or live closures.')
    (OUT/f'manifest-{mode}.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    print(json.dumps(manifest),flush=True)


if __name__ == '__main__':
    modes = sys.argv[1:] or ['bicycle','motorcar','motorcycle']
    for mode in modes: build(mode)
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from temporal_filter import main as filter_temporal
    filter_temporal(modes)
