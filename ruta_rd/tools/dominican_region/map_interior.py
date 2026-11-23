"""A conservative fast interior for label filtering; exact border is fallback."""
from pathlib import Path
import json
import shapely

ROOT = Path(__file__).resolve().parents[2] / 'assets/national'
country = shapely.geometry.shape(json.loads((ROOT / 'dominican-republic.geojson').read_text(encoding='utf-8'))['geometry'])
# Retain a substantial margin: no approximation is allowed to admit Haiti.
interior = country.simplify(.01, preserve_topology=True).buffer(-.022, join_style='mitre')
assert not interior.is_empty and country.covers(interior)
assert country.boundary.distance(interior) > .01
feature = dict(type='Feature', properties=dict(
    source='OSM relation 307828; same pinned boundary as dominican-republic.geojson',
    attribution='© OpenStreetMap contributors', license='ODbL 1.0',
    notice='Conservative interior only; false results always fall back to full boundary',
    vertices=int(shapely.get_num_coordinates(interior)), minimumBoundaryDistanceDegrees=country.boundary.distance(interior)),
    geometry=shapely.geometry.mapping(interior))
(ROOT / 'label-interior.geojson').write_text(json.dumps(feature, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
print('LABEL_INTERIOR vertices=',shapely.get_num_coordinates(interior),'; subset RD=true; exact border fallback; minimum margin degrees=',country.boundary.distance(interior))
