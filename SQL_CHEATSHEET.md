# Apache Sedona SQL Cheat Sheet

Quick copy-paste SQL patterns for Apache Sedona spatial analysis.

---

## 🎯 Basic Spatial Queries

### Create Points from Coordinates
```sql
SELECT 
    id,
    ST_Point(longitude, latitude) as point_geom
FROM locations
```

### Create Polygons
```sql
SELECT 
    ST_PolygonFromEnvelope(min_x, min_y, max_x, max_y) as poly_geom
FROM boundaries
```

### Point in Polygon
```sql
SELECT 
    p.id,
    z.zone_name
FROM points p
JOIN zones z 
ON ST_Contains(z.zone_geom, p.point_geom)
```

### Distance Filter
```sql
SELECT *
FROM locations
WHERE ST_Distance(geom, ST_Point(-73.985, 40.758)) < 0.01
ORDER BY ST_Distance(geom, ST_Point(-73.985, 40.758))
```

---

## 📏 Measurements

### Calculate Area
```sql
SELECT 
    zone_name,
    ST_Area(zone_geom) as area_sq_degrees
FROM zones
```

### Calculate Distance Between All Pairs
```sql
SELECT 
    a.id as from_id,
    b.id as to_id,
    ST_Distance(a.geom, b.geom) as distance
FROM locations a
CROSS JOIN locations b
WHERE a.id < b.id
```

### Perimeter
```sql
SELECT 
    ST_Perimeter(zone_geom) as perimeter
FROM zones
```

---

## 🔄 Transformations

### Create Buffer (500m ≈ 0.005 degrees)
```sql
SELECT 
    id,
    ST_Buffer(point_geom, 0.005) as buffer_geom
FROM locations
```

### Get Centroid
```sql
SELECT 
    zone_id,
    ST_Centroid(zone_geom) as center_point
FROM zones
```

### Simplify Geometry
```sql
SELECT 
    id,
    ST_SimplifyPreserveTopology(complex_geom, 0.001) as simple_geom
FROM complex_features
```

---

## 🎯 Spatial Joins

### Basic Spatial Join
```sql
SELECT 
    p.id,
    z.zone_name
FROM points p
JOIN zones z 
ON ST_Contains(z.zone_geom, p.point_geom)
```

### With Broadcast Hint
```sql
SELECT /*+ BROADCAST(zones) */
    p.id,
    z.zone_name
FROM large_points p
JOIN zones z 
ON ST_Contains(z.zone_geom, p.point_geom)
```

### Multi-Condition Join
```sql
SELECT *
FROM origins o
JOIN destinations d 
    ON ST_Distance(o.geom, d.geom) < 0.1
    AND ST_Contains(
        (SELECT zone_geom FROM zones WHERE id = 1),
        d.geom
    )
```

---

## 📊 Aggregations

### Count Points per Zone
```sql
SELECT 
    z.zone_name,
    COUNT(p.id) as point_count
FROM zones z
LEFT JOIN points p ON ST_Contains(z.zone_geom, p.point_geom)
GROUP BY z.zone_name
```

### Convex Hull by Group
```sql
SELECT 
    category,
    ST_ConvexHull(ST_Collect(point_geom)) as hull_geom
FROM points
GROUP BY category
```

### Union All Geometries
```sql
SELECT 
    ST_Union(zone_geom) as merged_geom
FROM zones
WHERE region = 'Downtown'
```

---

## 🗺️ Grid Analysis

### Create Grid Cells
```sql
SELECT 
    CAST(ST_X(point_geom) / 0.01 AS INT) as grid_x,
    CAST(ST_Y(point_geom) / 0.01 AS INT) as grid_y,
    COUNT(*) as point_count
FROM points
GROUP BY grid_x, grid_y
```

### Spatial Binning
```sql
SELECT 
    ST_MakeEnvelope(
        grid_x * 0.01,
        grid_y * 0.01,
        (grid_x + 1) * 0.01,
        (grid_y + 1) * 0.01
    ) as cell_geom,
    COUNT(*) as count
FROM (
    SELECT 
        CAST(ST_X(geom) / 0.01 AS INT) as grid_x,
        CAST(ST_Y(geom) / 0.01 AS INT) as grid_y
    FROM points
)
GROUP BY grid_x, grid_y
```

---

## 🎪 Window Functions

### Nearest Neighbors
```sql
SELECT 
    id,
    neighbor_id,
    distance,
    rank
FROM (
    SELECT 
        p1.id,
        p2.id as neighbor_id,
        ST_Distance(p1.geom, p2.geom) as distance,
        ROW_NUMBER() OVER (
            PARTITION BY p1.id 
            ORDER BY ST_Distance(p1.geom, p2.geom)
        ) as rank
    FROM points p1
    CROSS JOIN points p2
    WHERE p1.id != p2.id
)
WHERE rank <= 5
```

### Spatial Ranking
```sql
SELECT 
    zone_name,
    trip_count,
    ROW_NUMBER() OVER (ORDER BY trip_count DESC) as rank,
    PERCENT_RANK() OVER (ORDER BY trip_count) as percentile
FROM zone_stats
```

---

## 🔍 Outlier Detection

### Z-Score Method
```sql
WITH stats AS (
    SELECT 
        AVG(value) as mean_val,
        STDDEV(value) as stddev_val
    FROM measurements
)
SELECT 
    id,
    value,
    ABS(value - stats.mean_val) / stats.stddev_val as z_score
FROM measurements, stats
WHERE ABS(value - stats.mean_val) / stats.stddev_val > 3
```

### Spatial Distance Outliers
```sql
WITH centroids AS (
    SELECT 
        category,
        ST_Centroid(ST_Collect(geom)) as center
    FROM features
    GROUP BY category
)
SELECT 
    f.id,
    ST_Distance(f.geom, c.center) as dist_from_center
FROM features f
JOIN centroids c ON f.category = c.category
WHERE ST_Distance(f.geom, c.center) > (
    SELECT AVG(ST_Distance(f2.geom, c2.center)) * 3
    FROM features f2
    JOIN centroids c2 ON f2.category = c2.category
    WHERE f2.category = f.category
)
```

---

## ⏰ Time-Series Spatial

### Hourly Aggregation
```sql
SELECT 
    hour(timestamp) as hour,
    zone_name,
    COUNT(*) as event_count
FROM events e
JOIN zones z ON ST_Contains(z.geom, e.geom)
GROUP BY hour(timestamp), zone_name
ORDER BY hour, event_count DESC
```

### Moving Average
```sql
SELECT 
    zone_id,
    timestamp,
    value,
    AVG(value) OVER (
        PARTITION BY zone_id 
        ORDER BY timestamp 
        ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING
    ) as moving_avg_5
FROM measurements
```

---

## 🔄 Origin-Destination

### Basic O-D Matrix
```sql
SELECT 
    oz.zone_name as origin,
    dz.zone_name as destination,
    COUNT(*) as trip_count
FROM trips t
JOIN zones oz ON ST_Contains(oz.geom, t.origin_geom)
JOIN zones dz ON ST_Contains(dz.geom, t.dest_geom)
WHERE oz.id != dz.id
GROUP BY oz.zone_name, dz.zone_name
ORDER BY trip_count DESC
```

### Flow Imbalance
```sql
SELECT 
    f1.origin,
    f1.destination,
    f1.trip_count as forward,
    COALESCE(f2.trip_count, 0) as reverse,
    f1.trip_count - COALESCE(f2.trip_count, 0) as imbalance
FROM od_flows f1
LEFT JOIN od_flows f2 
    ON f1.origin = f2.destination 
    AND f1.destination = f2.origin
WHERE f1.trip_count > COALESCE(f2.trip_count, 0) * 1.5
```

---

## 🎨 Data Quality

### Find Invalid Geometries
```sql
SELECT 
    id,
    ST_IsValid(geom) as is_valid,
    ST_IsSimple(geom) as is_simple
FROM geometries
WHERE NOT ST_IsValid(geom)
```

### Detect Null Coordinates
```sql
SELECT COUNT(*)
FROM locations
WHERE point_geom IS NULL
   OR ST_X(point_geom) IS NULL
   OR ST_Y(point_geom) IS NULL
```

### Check Coordinate Bounds
```sql
SELECT 
    id,
    ST_X(geom) as lon,
    ST_Y(geom) as lat
FROM points
WHERE ST_X(geom) NOT BETWEEN -180 AND 180
   OR ST_Y(geom) NOT BETWEEN -90 AND 90
```

---

## 🚀 Performance Patterns

### Cache Table
```sql
CACHE TABLE zones;
CACHE TABLE large_points;
```

### Broadcast Small Table
```sql
SELECT /*+ BROADCAST(small_table) */
    large.id,
    small.name
FROM large_table large
JOIN small_table small ON ST_Contains(small.geom, large.geom)
```

### Bounding Box Pre-filter
```sql
SELECT *
FROM large_features f
JOIN zones z 
    ON ST_Intersects(ST_Envelope(z.geom), ST_Envelope(f.geom))
    AND ST_Contains(z.geom, f.geom)
```

---

## 📐 Common Calculations

### Density
```sql
SELECT 
    zone_name,
    COUNT(*) / ST_Area(zone_geom) as density
FROM zones z
LEFT JOIN points p ON ST_Contains(z.zone_geom, p.point_geom)
GROUP BY zone_name, zone_geom
```

### Compactness
```sql
SELECT 
    zone_id,
    ST_Perimeter(zone_geom) / ST_Area(zone_geom) as compactness
FROM zones
```

### Distance to Nearest Feature
```sql
SELECT 
    p.id,
    MIN(ST_Distance(p.geom, f.geom)) as nearest_distance
FROM points p
CROSS JOIN features f
GROUP BY p.id
```

---

## 🎯 Coordinate Accessors

### Extract Coordinates
```sql
SELECT 
    id,
    ST_X(point_geom) as longitude,
    ST_Y(point_geom) as latitude
FROM locations
```

### Bounding Box
```sql
SELECT 
    ST_XMin(geom) as min_lon,
    ST_YMin(geom) as min_lat,
    ST_XMax(geom) as max_lon,
    ST_YMax(geom) as max_lat
FROM zones
```

---

## 💾 Export Formats

### As Text (WKT)
```sql
SELECT 
    id,
    ST_AsText(geom) as wkt_geom
FROM features
```

### As GeoJSON
```sql
SELECT 
    id,
    ST_AsGeoJSON(geom) as geojson
FROM features
```

---

## 🔧 Tips

1. **Distance in degrees**: ~0.01° ≈ 1 km at mid-latitudes
2. **Coordinate order**: ST_Point(lon, lat) not (lat, lon)
3. **Always filter nulls**: Add `WHERE geom IS NOT NULL`
4. **Use topology preservation**: `ST_SimplifyPreserveTopology()` over `ST_Simplify()`
5. **Cache small tables**: Use `CACHE TABLE` for dimension tables
6. **Broadcast joins**: Add `/*+ BROADCAST(table) */` hint for small tables

---

**Quick Copy-Paste Ready!** 🚀
