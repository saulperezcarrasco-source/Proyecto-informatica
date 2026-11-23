"""Conservative final pass: omit roads whose direction depends on time and
motorroad=yes for bicycles without explicit permission. Reuses base RDI2 so
this small policy pass need not rebuild all OSM node callbacks.
"""
import gzip
import hashlib
import json
from pathlib import Path
import struct
import sys
import numpy as np
import osmium

ROOT = Path(__file__).resolve().parents[2]
MODES = ['bicycle','motorcar','motorcycle']


def exclude(tags, mode):
    keys = ['oneway', 'oneway:' + mode, 'oneway:vehicle']
    if mode != 'bicycle': keys.append('oneway:motor_vehicle')
    if any(tags.get(k + ':conditional') for k in keys): return True
    if any(tags.get(k) in {'reversible','alternating'} for k in keys): return True
    return mode == 'bicycle' and tags.get('motorroad') == 'yes' and tags.get('bicycle') not in {'yes','designated','official','permissive'}


def key(lat, lon): return ((lat & 0xffffffff) << 32) | (lon & 0xffffffff)


class Scan(osmium.SimpleHandler):
    def __init__(self):
        super().__init__()
        self.pairs = {m:set() for m in MODES}
        self.ways = {m:set() for m in MODES}
    def way(self, way):
        if not way.tags.get('highway'): return
        modes = [m for m in MODES if exclude(way.tags,m)]
        if not modes: return
        for a,b in zip(way.nodes,list(way.nodes)[1:]):
            if not a.location.valid() or not b.location.valid(): continue
            ka,kb=key(round(a.lat*1e7),round(a.lon*1e7)),key(round(b.lat*1e7),round(b.lon*1e7))
            for mode in modes:
                self.pairs[mode].update(((ka,kb),(kb,ka)))
                self.ways[mode].add(way.id)


def rewrite(mode, pairs, ways):
    folder=ROOT/'assets/routing'
    path=folder/f'dominican-{mode}.rdi'
    raw=gzip.decompress(path.read_bytes())
    magic,n,m=struct.unpack_from('<4sII',raw)
    if magic != b'RDI2': raise ValueError('Expected RDI2')
    at=12
    coords=np.frombuffer(raw,dtype='<i4',count=n*2,offset=at).reshape(n,2);at+=n*8
    offsets=np.frombuffer(raw,dtype='<u4',count=n+1,offset=at);at+=(n+1)*4
    targets=np.frombuffer(raw,dtype='<u4',count=m,offset=at);at+=m*4
    weights=np.frombuffer(raw,dtype='<f4',count=m,offset=at);at+=m*4
    components=np.frombuffer(raw,dtype='<u4',count=n,offset=at);at+=n*4
    turncount=struct.unpack_from('<I',raw,at)[0];at+=4
    turns=np.frombuffer(raw,dtype='<u4',count=turncount*3,offset=at).reshape(turncount,3)
    keys=(coords[:,0].astype(np.uint64)<<32) | coords[:,1].astype(np.uint32).astype(np.uint64)
    wanted=np.array(list({k for p in pairs for k in p}),dtype=np.uint64)
    matched=np.flatnonzero(np.isin(keys,wanted))
    nodes={int(keys[i]):int(i) for i in matched}
    bad=np.array([nodes[a]*n+nodes[b] for a,b in pairs if a in nodes and b in nodes],dtype=np.int64)
    sources=np.repeat(np.arange(n,dtype=np.uint32),np.diff(offsets))
    keep=~np.isin(sources.astype(np.int64)*n+targets,bad)
    removed=int((~keep).sum())
    if removed:
        sources,targets,weights=sources[keep],targets[keep],weights[keep]
        used=np.zeros(n,dtype=bool);used[sources]=True;used[targets]=True
        mapping=np.full(n,-1,dtype=np.int32)
        n=int(used.sum());mapping[used]=np.arange(n,dtype=np.int32)
        sources,targets,coords=mapping[sources],mapping[targets],coords[used]
        turns=mapping[turns[np.all(used[turns],axis=1)]]
        offsets=np.zeros(n+1,dtype='<u4');offsets[1:]=np.cumsum(np.bincount(sources,minlength=n),dtype=np.uint32)
        parent=list(range(n))
        def root(i):
            while parent[i]!=i: parent[i]=parent[parent[i]];i=parent[i]
            return i
        for a,b in zip(sources,targets):
            ra,rb=root(int(a)),root(int(b))
            if ra!=rb:parent[rb]=ra
        components=np.fromiter((root(i) for i in range(n)),dtype='<u4',count=n)
        with path.open('wb') as output,gzip.GzipFile(fileobj=output,mode='wb',mtime=0,filename='') as stream:
            stream.write(struct.pack('<4sII',b'RDI2',n,len(targets)))
            for section in (coords,offsets,targets.astype('<u4'),weights,components):stream.write(section.tobytes())
            stream.write(struct.pack('<I',len(turns)));stream.write(turns.astype('<u4').tobytes())
    manifest_path=folder/f'manifest-{mode}.json'
    record=json.loads(manifest_path.read_text(encoding='utf-8'))
    record.update(nodes=n,directedEdges=len(targets),prohibitedTurns=len(turns),bytes=path.stat().st_size,sha256=hashlib.sha256(path.read_bytes()).hexdigest(),temporalFilterRevision=1,temporallyFilteredEdges=record.get('temporallyFilteredEdges',0)+removed,avoidedTimeDependentWays=sorted(ways))
    suffix = ' Time-dependent/reversible direction ways omitted. Bicycles on motorroad require explicit permission.'
    if suffix not in record['policy']: record['policy'] += suffix
    manifest_path.write_text(json.dumps(record,indent=2),encoding='utf-8')
    print(f'{mode}: temporal policy removed {removed} edges; nodes={n}; edges={len(targets)}',flush=True)


def main(modes=None):
    scan=Scan()
    scan.apply_file(str(ROOT/'tools/island_routing/source.osm.pbf'),locations=True,idx='flex_mem')
    for mode in modes or MODES: rewrite(mode,scan.pairs[mode],scan.ways[mode])


if __name__=='__main__': main(sys.argv[1:] or None)
