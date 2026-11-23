"""Build the offline walking graph from the pinned Geofabrik OSM extract.

Requires osmium==4.3.0. Run from this directory with source.osm.pbf present.
Edges connect consecutive OSM node IDs, never visual crossings or tile seams.
"""
import array
import gzip
import hashlib
import json
import math
from pathlib import Path
import struct
import sys

import osmium

ROOT = Path(__file__).resolve().parent
OUT = ROOT / 'cache'
SOURCE = ROOT / 'source.osm.pbf'
ALLOWED = {'primary', 'primary_link', 'secondary', 'secondary_link',
           'tertiary', 'tertiary_link', 'unclassified', 'residential',
           'living_street', 'service', 'pedestrian', 'footway', 'path',
           'steps', 'track', 'road', 'bridleway'}
YES = {'yes', 'designated', 'permissive', 'official'}
NO = {'no', 'private', 'military', 'customers', 'delivery'}


def distance(a, b):
    a, b = [x / 1e7 for x in a], [x / 1e7 for x in b]
    lat1, lat2 = math.radians(a[0]), math.radians(b[0])
    h = math.sin((lat2-lat1)/2)**2 + math.cos(lat1)*math.cos(lat2)*math.sin(math.radians(b[1]-a[1])/2)**2
    return 12742000 * math.asin(math.sqrt(min(1, h)))


class Graph(osmium.SimpleHandler):
    def __init__(self):
        super().__init__()
        self.ids = {}
        self.coords = []
        self.edges = []
        self.blocked = set()
        self.parent = []
        self.ways = 0

    def node(self, node):
        tags = node.tags
        foot = tags.get('foot', '')
        if foot in NO or (foot not in YES and (
                tags.get('access', '') in NO or tags.get('barrier', '') in {'wall', 'fence'})):
            self.blocked.add(node.id)

    def root(self, i):
        while self.parent[i] != i:
            self.parent[i] = self.parent[self.parent[i]]
            i = self.parent[i]
        return i

    def index(self, node):
        if node.ref not in self.ids:
            i = len(self.coords)
            self.ids[node.ref] = i
            self.coords.append((round(node.lat * 1e7), round(node.lon * 1e7)))
            self.parent.append(i)
        return self.ids[node.ref]

    def way(self, way):
        tags = way.tags
        highway = tags.get('highway', '')
        foot = tags.get('foot', '')
        if (highway not in ALLOWED and not (highway in {'trunk', 'trunk_link', 'cycleway'} and foot in YES)):
            return
        if foot in NO or (tags.get('access', '') in NO and foot not in YES):
            return
        if tags.get('area', '') == 'yes' or tags.get('construction', ''):
            return
        forward = tags.get('oneway:foot', '') not in {'-1', 'reverse'}
        backward = tags.get('oneway:foot', '') not in {'yes', '1', 'true'}
        self.ways += 1
        for a, b in zip(way.nodes, list(way.nodes)[1:]):
            if a.ref in self.blocked or b.ref in self.blocked:
                continue
            if not a.location.valid() or not b.location.valid() or a.ref == b.ref:
                continue
            if not all(17.3 <= n.lat <= 20 and -74.6 <= n.lon <= -68.2 for n in (a,b)):
                continue
            aa = (round(a.lat * 1e7), round(a.lon * 1e7))
            bb = (round(b.lat * 1e7), round(b.lon * 1e7))
            length = distance(aa, bb)
            if length <= 0:
                continue
            i, j = self.index(a), self.index(b)
            # Round upward: geometric A* heuristic remains a lower bound.
            length = math.ceil(length * 100) / 100
            if forward:
                self.edges.append((i, j, length))
            if backward:
                self.edges.append((j, i, length))
            ri, rj = self.root(i), self.root(j)
            if ri != rj:
                self.parent[rj] = ri


def main():
    if sys.byteorder != 'little':
        raise RuntimeError('Build requires little endian')
    graph = Graph()
    print('Reading walking ways...', flush=True)
    graph.apply_file(str(SOURCE), locations=True, idx='flex_mem')
    graph.edges.sort()
    edges = []
    last = None
    for edge in graph.edges:
        if edge[:2] != last:
            edges.append(edge)
            last = edge[:2]
    graph.edges = edges
    n, m = len(graph.coords), len(edges)
    print(f'{n} nodes, {m} directed edges, {graph.ways} ways', flush=True)
    offsets = array.array('I', [0]) * (n + 1)
    targets = array.array('I')
    weights = array.array('f')
    for a, b, w in edges:
        offsets[a+1] += 1
        targets.append(b)
        weights.append(w)
    for i in range(n):
        offsets[i+1] += offsets[i]
    coords = array.array('i', (v for pair in graph.coords for v in pair))
    components = array.array('I', (graph.root(i) for i in range(n)))
    counts = {}
    for component in components:
        counts[component] = counts.get(component, 0) + 1
    OUT.mkdir(parents=True, exist_ok=True)
    output = OUT / 'island-walking.rdi'
    with output.open('wb') as raw, gzip.GzipFile(fileobj=raw, mode='wb', mtime=0, filename='') as stream:
        stream.write(struct.pack('<4sII', b'RDI1', n, m))
        for section in (coords, offsets, targets, weights, components):
            stream.write(section.tobytes())
    manifest = dict(
        source='https://download.geofabrik.de/central-america/haiti-and-domrep-261118.osm.pbf',
        sourceSha256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        attribution='OpenStreetMap contributors; Geofabrik extract; ODbL 1.0',
        dataDate='2026-11-18', format='RDI1 little-endian, gzip',
        nodes=n, directedEdges=m, ways=graph.ways, bytes=output.stat().st_size,
        sha256=hashlib.sha256(output.read_bytes()).hexdigest(),
        weakComponents=sorted(counts.values(), reverse=True),
        policy='Walking ways; no motorway; trunk/cycleway only with explicit foot permission; restricted access excluded unless foot permitted; oneway:foot respected; barriers wall/fence and forbidden foot nodes excluded; no synthetic edges. OSM crossing IDs retain topology.',
        limitations='Not field-verified. No routing through ferries, buildings or restricted/private access; no border opening information or walking turn restrictions. A snap approach is not a verified access path.',
    )
    (OUT / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({k: manifest[k] for k in ('nodes','directedEdges','bytes','sha256')}, indent=2), flush=True)


if __name__ == '__main__':
    main()
