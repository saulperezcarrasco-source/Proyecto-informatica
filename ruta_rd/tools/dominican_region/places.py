"""Offline national gazetteer: named OSM nodes, ways and named areas in RD.

Uses the pinned source.osm.pbf already used for walking routes. No Google data.
Requires the existing osmium/shapely preparation environment.
"""
from pathlib import Path
import collections
import gzip
import hashlib
import json
import math
import osmium
import shapely

PROJECT = Path(__file__).resolve().parents[2]
SOURCE = PROJECT / 'tools/island_routing/source.osm.pbf'
OUT = PROJECT / 'assets/search'
GEOMETRY = shapely.geometry.shape(json.loads(
    (PROJECT / 'assets/national/dominican-republic.geojson').read_text(encoding='utf-8'))['geometry'])
shapely.prepare(GEOMETRY)

SHOPS = {'convenience':'Colmado', 'supermarket':'Supermercado', 'bakery':'Panadería',
         'clothes':'Tienda de ropa', 'hairdresser':'Peluquería', 'beauty':'Salón de belleza',
         'car_repair':'Taller mecánico', 'hardware':'Ferretería', 'butcher':'Carnicería',
         'electronics':'Tienda de electrónica', 'mobile_phone':'Tienda de celulares',
         'furniture':'Mueblería', 'mall':'Centro comercial', 'laundry':'Lavandería'}
SERVICES = {'restaurant':'Restaurante', 'cafe':'Cafetería', 'fast_food':'Comida rápida',
            'pharmacy':'Farmacia', 'bank':'Banco', 'atm':'Cajero automático',
            'fuel':'Estación de combustible', 'clinic':'Clínica', 'hospital':'Hospital',
            'school':'Centro educativo', 'bar':'Bar', 'ice_cream':'Heladería',
            'marketplace':'Mercado', 'post_office':'Oficina de correos'}
TOURISM = {'hotel':'Hotel', 'guest_house':'Alojamiento', 'museum':'Museo',
           'viewpoint':'Mirador', 'attraction':'Atracción turística', 'picnic_site':'Área de picnic',
           'camp_site':'Zona de acampada'}

def feature_name(tags):
    name = tags.get('name:es') or tags.get('name') or tags.get('brand')
    if name: return name, False
    business = tags.get('shop') or tags.get('office') or tags.get('amenity') in SERVICES or tags.get('tourism') in TOURISM
    if business:
        name = tags.get('addr:housename') or tags.get('operator')
        if name: return name, False
    label = SHOPS.get(tags.get('shop')) or SERVICES.get(tags.get('amenity')) or TOURISM.get(tags.get('tourism'))
    return (f'{label} (sin nombre)', True) if label else (None, False)


class Places(osmium.SimpleHandler):
    def __init__(self):
        super().__init__()
        self.entries = {}
        self.cities = []
        self.unnamed = set()

    def save(self, ident, tags, lon, lat):
        name, unnamed = feature_name(tags)
        if not name or not shapely.intersects_xy(GEOMETRY, lon, lat):
            return
        category = ('calle' if tags.get('highway') else
                    'barrio' if tags.get('place') or tags.get('boundary') else
                    'turismo' if tags.get('tourism') or tags.get('historic') else
                    'negocio' if tags.get('shop') or tags.get('office') or tags.get('craft') else
                    tags.get('amenity') or tags.get('leisure') or tags.get('natural') or 'lugar')
        aliases = list(dict.fromkeys(t.v for t in tags
                       if t.k in {'name', 'name:en', 'alt_name', 'loc_name', 'short_name', 'official_name', 'addr:city', 'addr:street', 'ref'}
                       and t.v != name))
        self.entries[ident] = [ident, name, category, round(lat, 7), round(lon, 7), aliases]
        if unnamed: self.unnamed.add(ident)

    def node(self, node):
        if node.tags and node.location.valid():
            self.save(f'rd:node:{node.id}', node.tags, node.location.lon, node.location.lat)
            if node.tags.get('place') in {'city', 'town'} and f'rd:node:{node.id}' in self.entries:
                row = self.entries[f'rd:node:{node.id}']
                self.cities.append((row[3], row[4], row[1], list(row[5])))

    def way(self, way):
        if not feature_name(way.tags)[0]:
            return
        points = [(n.lon, n.lat) for n in way.nodes if n.location.valid()]
        if not points:
            return
        # Roads use a real OSM node, not a centroid off the road.
        lon, lat = points[len(points)//2]
        self.save(f'rd:way:{way.id}', way.tags, lon, lat)

    def area(self, area):
        if area.from_way() or not feature_name(area.tags)[0]:
            return
        try:
            shape = shapely.from_wkb(osmium.geom.WKBFactory().create_multipolygon(area))
            point = shape.representative_point()
            self.save(f'rd:relation:{area.orig_id()}', area.tags, point.x, point.y)
        except (RuntimeError, ValueError):
            pass


def main():
    OUT.mkdir(exist_ok=True)
    handler = Places()
    handler.apply_file(str(SOURCE), locations=True, idx='flex_mem')
    entries = sorted(handler.entries.values(), key=lambda p: p[0])
    # Geographic context is explicitly proximity, not an invented postal city.
    import numpy as np
    cities = np.array([[c[0], c[1]] for c in handler.cities])
    for row in entries:
        dlat = (cities[:, 0] - row[3]) * 111320
        dlon = (cities[:, 1] - row[4]) * 111320 * math.cos(math.radians(row[3]))
        distances = dlat * dlat + dlon * dlon
        nearest = int(np.argmin(distances))
        if distances[nearest] <= 25000**2:
            city = handler.cities[nearest]
            row[5] = list(dict.fromkeys(row[5] + [f'Cerca de {name}' for name in [city[2], *city[3]]]))
    # Popular wording requested by the user, attached to the existing OSM site.
    landmark = handler.entries.get('rd:way:191967205')
    if landmark is not None:
        landmark[5] += ['Monumento de Santiago', 'Monumento Santiago']
    packed = gzip.compress(json.dumps(entries, ensure_ascii=False, separators=(',', ':')).encode(), mtime=0)
    (OUT / 'places.rds').write_bytes(packed)
    manifest = dict(id='dominican-search', version='2026-11-18', count=len(entries),
                    searchRevision=3, unnamedFeatures=len(handler.unnamed), context='Nearest OSM city/town within 25 km; proximity, not postal boundaries',
                    format='gzip-compressed UTF-8 JSON rows; .rds preserves asset name in Flutter APK',
                    categories=dict(collections.Counter(p[2] for p in entries)),
                    source='https://download.geofabrik.de/central-america/haiti-and-domrep.html',
                    sourceSha256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
                    sha256=hashlib.sha256(packed).hexdigest(), bytes=len(packed),
                    attribution='© OpenStreetMap contributors', license='ODbL 1.0',
                    notice='OSM features within RD; unnamed businesses/services explicitly marked sin nombre. Descriptions are categories, not invented business names. Not a complete directory. Road segments may share names. No Google Maps data.')
    (OUT / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps(manifest, ensure_ascii=False), flush=True)


if __name__ == '__main__':
    main()
