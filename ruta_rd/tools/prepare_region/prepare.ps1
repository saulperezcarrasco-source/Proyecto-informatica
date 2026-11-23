$ErrorActionPreference = 'Stop'
[xml]$osm = Get-Content -Raw -Encoding UTF8 (Join-Path $PSScriptRoot 'source.osm')
$output = Join-Path $PSScriptRoot '../../assets/regions/zona_piloto'
New-Item -ItemType Directory -Force $output | Out-Null
$nodes = @{}
$places = @()
$culture = [Globalization.CultureInfo]::InvariantCulture
foreach ($n in $osm.osm.node) {
  $lat = [double]::Parse($n.lat, $culture)
  $lon = [double]::Parse($n.lon, $culture)
  if ($lat -lt 18.4700 -or $lat -gt 18.4780 -or $lon -lt -69.8900 -or $lon -gt -69.8800) { continue }
  $tags = @{}; foreach ($t in $n.tag) { $tags[$t.k] = $t.v }
  $nodes[$n.id] = @{id=$n.id; coordinate=@{lat=$lat; lon=$lon}; blocked=($tags.ContainsKey('barrier') -and $tags.foot -ne 'yes')}
  if ($tags.name -and ($tags.amenity -or $tags.tourism -or $tags.shop)) {
    $aliases = @(); foreach ($key in @('alt_name','short_name','name:es','name:en')) { if($tags[$key]) { $aliases += @($tags[$key] -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ -and $_ -ne $tags.name }) } }
    $places += @{id=$n.id; name=$tags.name; category='place'; coordinate=@{lat=$lat; lon=$lon}; aliases=@($aliases | Sort-Object -Unique)}
  }
}
$features = @(); $edges = @(); $used = @{}; $areas = @()
foreach ($w in $osm.osm.way) {
  $tags = @{}; foreach ($t in $w.tag) { $tags[$t.k] = $t.v }
  if ($w.nd.Count -ge 4 -and $w.nd[0].ref -eq $w.nd[$w.nd.Count-1].ref -and ($tags.building -or $tags.landuse -or $tags.leisure)) {
    $ring = @(); $complete = $true
    foreach ($ref in $w.nd) { if (-not $nodes[$ref.ref]) { $complete=$false; break }; $p=$nodes[$ref.ref].coordinate; $ring += ,@($p.lon,$p.lat) }
    if ($complete) { $areas += @{coordinates=$ring} }
  }
  if ($tags.highway -notin @('residential','living_street','pedestrian','footway','path','steps','service','tertiary','secondary','primary','unclassified')) { continue }
  if ($tags.foot -in @('no','private') -or ($tags.access -in @('no','private') -and $tags.foot -notin @('yes','designated','permissive'))) { continue }
  for ($i=1; $i -lt $w.nd.Count; $i++) {
    $a=$nodes[$w.nd[$i-1].ref]; $b=$nodes[$w.nd[$i].ref]
    if (-not $a -or -not $b -or $a.blocked -or $b.blocked) { continue }
    $rad=[Math]::PI/180
    $dlat=($b.coordinate.lat-$a.coordinate.lat)*$rad; $dlon=($b.coordinate.lon-$a.coordinate.lon)*$rad
    $h=[Math]::Pow([Math]::Sin($dlat/2),2)+[Math]::Cos($a.coordinate.lat*$rad)*[Math]::Cos($b.coordinate.lat*$rad)*[Math]::Pow([Math]::Sin($dlon/2),2)
    $distance=6371000*2*[Math]::Asin([Math]::Sqrt($h))
    if ($distance -le 0) { continue }
    $used[$a.id]=$a; $used[$b.id]=$b
    if ($tags.'oneway:foot' -ne '-1') { $edges += @{from=$a.id; to=$b.id; distanceMeters=$distance} }
    if ($tags.'oneway:foot' -ne 'yes') { $edges += @{from=$b.id; to=$a.id; distanceMeters=$distance} }
    $features += @{type='Feature'; properties=@{osmWay=$w.id; name=$tags.name}; geometry=@{type='LineString'; coordinates=@(@($a.coordinate.lon,$a.coordinate.lat),@($b.coordinate.lon,$b.coordinate.lat))}}
  }
}
function Save($name,$data) { [IO.File]::WriteAllText((Join-Path $output $name), ($data | ConvertTo-Json -Depth 20), [Text.UTF8Encoding]::new($false)) }
$graphNodes=@($used.Values | Sort-Object id | ForEach-Object { @{id=$_.id; coordinate=$_.coordinate} })
Save 'graph.json' @{nodes=$graphNodes; edges=$edges}
Save 'places.json' @($places | Sort-Object id)
Save 'map.geojson' @{type='FeatureCollection'; features=$features}
Save 'areas.json' @($areas)
Save 'manifest.json' @{id='zona_piloto'; name='Ciudad Colonial'; version='0.1.0'; bounds=@{south=18.4700; north=18.4780; west=-69.8900; east=-69.8800}; source='https://api.openstreetmap.org/api/0.6/map?bbox=-69.8900,18.4700,-69.8800,18.4780'; attribution='© OpenStreetMap contributors · ODbL 1.0'; generatedAt='2026-11-19T00:00:00Z'; isDemo=$false}
Write-Output "Nodes: $($graphNodes.Count); edges: $($edges.Count); places: $($places.Count)"
$adj=@{}; foreach ($n in $graphNodes) { $adj[$n.id]=[Collections.Generic.List[string]]::new() }
foreach ($e in $edges) { $adj[$e.from].Add($e.to); $adj[$e.to].Add($e.from) }
$seen=[Collections.Generic.HashSet[string]]::new(); $components=@()
foreach ($n in $graphNodes) {
  if (-not $seen.Add($n.id)) { continue }
  $queue=[Collections.Generic.Queue[string]]::new(); $queue.Enqueue($n.id); $count=0
  while ($queue.Count) { $id=$queue.Dequeue(); $count++; foreach ($next in $adj[$id]) { if($seen.Add($next)){$queue.Enqueue($next)} } }
  $components += $count
}
Save 'validation.json' @{nodes=$graphNodes.Count; edges=$edges.Count; places=$places.Count; weakComponents=@($components | Sort-Object -Descending); note='No artificial connections. Directed reachability is checked per route.'}
