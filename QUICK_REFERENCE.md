# Apache Sedona Quick Reference Guide

A concise reference for common spatial analysis patterns with Apache Sedona.

## 🚀 Quick Start

```python
from pyspark.sql import SparkSession
from sedona.register import SedonaRegistrator
from sedona.utils import SedonaKryoRegistrator, KryoSerializer

# Initialize Spark with Sedona
spark = SparkSession.builder \
    .appName("SedonaApp") \
    .config("spark.serializer", KryoSerializer.getName) \
    .config("spark.kryo.registrator", SedonaKryoRegistrator.getName) \
    .config("spark.sql.extensions", "org.apache.sedona.sql.SedonaSqlExtensions") \
    .getOrCreate()

# Register Sedona functions
SedonaRegistrator.registerAll(spark)
```

---

## 📍 Common Patterns

### 1. Point-in-Polygon (Geofencing)

```sql
-- Find which zone each point belongs to
SELECT 
    p.id,
    p.point_geom,
    z.zone_name
FROM points p
JOIN zones z ON ST_Contains(z.zone_geom, p.point_geom)
```

### 2. Distance Filtering

```sql
-- Find all points within 1km of a location
SELECT 
    id,
    name,
    ST_Distance(point_geom, ST_Point(-73.985, 40.758)) as distance
FROM locations
WHERE ST_Distance(point_geom, ST_Point(-73.985, 40.758)) < 0.01
ORDER BY distance
```

### 3. Buffer Analysis

```sql
-- Create 500m buffer and find intersecting features
SELECT 
    l.name,
    COUNT(p.id) as point_count
FROM locations l
CROSS JOIN points p
WHERE ST_Intersects(ST_Buffer(l.point_geom, 0.005), p.point_geom)
GROUP BY l.name
```

### 4. Nearest Neighbor

```sql
-- Find 5 nearest neighbors for each point
SELECT 
    p1.id as point_id,
    p2.id as neighbor_id,
    ST_Distance(p1.geom, p2.geom) as distance,
    ROW_NUMBER() OVER (PARTITION BY p1.id ORDER BY ST_Distance(p1.geom, p2.geom)) as rank
FROM points p1
CROSS JOIN points p2
WHERE p1.id != p2.id
QUALIFY rank <= 5
```

### 5. Convex Hull by Group

```sql
-- Calculate convex hull for each category
SELECT 
    category,
    ST_ConvexHull(ST_Collect(point_geom)) as hull_geom,
    COUNT(*) as point_count
FROM points
GROUP BY category
```

### 6. Spatial Join with Multiple Conditions

```sql
-- Join based on containment AND distance
SELECT 
    o.id as origin_id,
    d.id as dest_id,
    ST_Distance(o.geom, d.geom) as distance
FROM origins o
JOIN destinations d 
    ON ST_DWithin(o.geom, d.geom, 0.1)
    AND ST_Contains(
        (SELECT zone_geom FROM zones WHERE zone_id = 'AREA_1'),
        d.geom
    )
```

### 7. Grid Aggregation

```sql
-- Aggregate points into 0.01° grid cells
SELECT 
    CAST(ST_X(point_geom) / 0.01 AS INT) as grid_x,
    CAST(ST_Y(point_geom) / 0.01 AS INT) as grid_y,
    COUNT(*) as point_count,
    AVG(value) as avg_value
FROM points
GROUP BY grid_x, grid_y
HAVING COUNT(*) > 10
```

### 8. Origin-Destination Matrix

```sql
-- Calculate trip flows between zones
SELECT 
    oz.zone_name as origin,
    dz.zone_name as destination,
    COUNT(*) as trip_count,
    AVG(trip_distance) as avg_distance
FROM trips t
JOIN zones oz ON ST_Contains(oz.zone_geom, t.origin_geom)
JOIN zones dz ON ST_Contains(dz.zone_geom, t.dest_geom)
WHERE oz.zone_id != dz.zone_id
GROUP BY oz.zone_name, dz.zone_name
ORDER BY trip_count DESC
```

### 9. Spatial Outlier Detection

```sql
-- Find geometries far from cluster centers
WITH centroids AS (
    SELECT 
        category,
        ST_Centroid(ST_Collect(geom)) as center_geom
    FROM features
    GROUP BY category
)
SELECT 
    f.id,
    f.category,
    ST_Distance(f.geom, c.center_geom) as distance_from_center
FROM features f
JOIN centroids c ON f.category = c.category
WHERE ST_Distance(f.geom, c.center_geom) > (
    SELECT AVG(ST_Distance(f2.geom, c2.center_geom)) * 3
    FROM features f2
    JOIN centroids c2 ON f2.category = c2.category
    WHERE f2.category = f.category
)
```

### 10. Time-Windowed Spatial Analysis

```sql
-- Analyze spatial patterns by hour
SELECT 
    hour(timestamp) as hour,
    z.zone_name,
    COUNT(*) as event_count,
    ST_Centroid(ST_Collect(e.geom)) as activity_center
FROM events e
JOIN zones z ON ST_Contains(z.zone_geom, e.geom)
GROUP BY hour(timestamp), z.zone_name
ORDER BY hour, event_count DESC
```

---

## 🔧 Performance Patterns

### Broadcast Small Dimension Tables

```python
# Python/PySpark
zones_df.createOrReplaceTempView("zones")
spark.sql("CACHE TABLE zones")

result = spark.sql("""
    SELECT /*+ BROADCAST(zones) */
        p.id,
        z.zone_name
    FROM large_points_table p
    JOIN zones z ON ST_Contains(z.geom, p.geom)
""")
```

### Spatial Partitioning

```python
# Partition by spatial hash
df_partitioned = df.repartition(
    100,
    expr("CAST(ST_X(geom) * 100 AS INT)"),
    expr("CAST(ST_Y(geom) * 100 AS INT)")
)
```

### Geometry Simplification

```sql
-- Simplify complex polygons
CREATE OR REPLACE TEMP VIEW simplified_zones AS
SELECT 
    zone_id,
    zone_name,
    ST_SimplifyPreserveTopology(zone_geom, 0.005) as zone_geom
FROM zones
WHERE ST_NumPoints(zone_geom) > 1000
```

### Bounding Box Pre-filtering

```sql
-- Use bounding box for quick filtering before expensive operations
SELECT *
FROM features f
JOIN zones z ON ST_Contains(z.geom, f.geom)
WHERE ST_Intersects(
    ST_Envelope(z.geom),
    ST_Envelope(f.geom)
)
```

---

## 📊 Common Calculations

### Area and Density

```sql
SELECT 
    zone_name,
    ST_Area(zone_geom) as area,
    COUNT(p.id) as point_count,
    COUNT(p.id) / ST_Area(zone_geom) as density
FROM zones z
LEFT JOIN points p ON ST_Contains(z.zone_geom, p.geom)
GROUP BY zone_name, zone_geom
```

### Centroid Distance

```sql
SELECT 
    id,
    ST_Distance(
        geom,
        ST_Centroid((SELECT ST_Collect(geom) FROM features))
    ) as distance_from_center
FROM features
```

### Perimeter to Area Ratio (Compactness)

```sql
SELECT 
    zone_id,
    ST_Perimeter(zone_geom) / ST_Area(zone_geom) as compactness_ratio
FROM zones
ORDER BY compactness_ratio
```

---

## 🎨 Visualization Patterns

### Export to GeoJSON

```python
# Convert to Pandas and export
gdf = df.selectExpr(
    "ST_AsText(geom) as geometry",
    "id",
    "name",
    "value"
).toPandas()

import geopandas as gpd
from shapely import wkt

gdf['geometry'] = gdf['geometry'].apply(wkt.loads)
geo_df = gpd.GeoDataFrame(gdf, geometry='geometry')
geo_df.to_file("output.geojson", driver="GeoJSON")
```

### Create Folium Heatmap

```python
import folium
from folium.plugins import HeatMap

# Get coordinates and values
heat_data = df.selectExpr(
    "ST_Y(geom) as lat",
    "ST_X(geom) as lon",
    "value"
).toPandas()

# Create map
m = folium.Map(location=[40.7, -74.0], zoom_start=11)
HeatMap(heat_data[['lat', 'lon', 'value']].values.tolist()).add_to(m)
m
```

### Matplotlib Scatter with Color

```python
import matplotlib.pyplot as plt

plot_data = df.selectExpr(
    "ST_X(geom) as x",
    "ST_Y(geom) as y",
    "value"
).toPandas()

plt.figure(figsize=(12, 8))
plt.scatter(
    plot_data['x'],
    plot_data['y'],
    c=plot_data['value'],
    cmap='YlOrRd',
    alpha=0.6,
    s=50
)
plt.colorbar(label='Value')
plt.xlabel('Longitude')
plt.ylabel('Latitude')
plt.title('Spatial Distribution')
plt.show()
```

---

## 🔍 Data Quality Checks

### Check for Invalid Geometries

```sql
SELECT 
    id,
    ST_IsValid(geom) as is_valid,
    ST_IsSimple(geom) as is_simple
FROM geometries
WHERE NOT ST_IsValid(geom)
```

### Find Duplicate Geometries

```sql
SELECT 
    ST_AsText(geom) as geom_text,
    COUNT(*) as duplicate_count
FROM features
GROUP BY ST_AsText(geom)
HAVING COUNT(*) > 1
```

### Detect Outlier Coordinates

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

## 🎯 Advanced Patterns

### Spatial Join with Statistics

```python
from pyspark.sql.functions import *

result = spark.sql("""
    SELECT 
        z.zone_id,
        COUNT(*) as point_count,
        AVG(p.value) as avg_value,
        STDDEV(p.value) as stddev_value,
        PERCENTILE(p.value, 0.5) as median_value
    FROM zones z
    LEFT JOIN points p ON ST_Contains(z.geom, p.geom)
    GROUP BY z.zone_id
""")
```

### Recursive Spatial Expansion

```sql
-- Find all zones within 3 hops of a starting zone
WITH RECURSIVE zone_network AS (
    SELECT zone_id, zone_geom, 0 as hop_count
    FROM zones
    WHERE zone_id = 'START_ZONE'
    
    UNION ALL
    
    SELECT z.zone_id, z.zone_geom, zn.hop_count + 1
    FROM zones z
    JOIN zone_network zn ON ST_Touches(z.zone_geom, zn.zone_geom)
    WHERE zn.hop_count < 3
)
SELECT DISTINCT zone_id, hop_count
FROM zone_network
```

### Moving Window Aggregation

```python
from pyspark.sql.window import Window

window_spec = Window.partitionBy("zone_id").orderBy("timestamp").rowsBetween(-2, 2)

df_with_moving_avg = df.withColumn(
    "moving_avg_value",
    avg("value").over(window_spec)
)
```

---

## 📚 Function Categories Quick Lookup

### Creation Functions
- `ST_Point(x, y)`, `ST_Polygon(coords)`, `ST_MakeEnvelope()`, `ST_MakeLine()`

### Predicates (Returns Boolean)
- `ST_Contains()`, `ST_Intersects()`, `ST_Within()`, `ST_Touches()`, `ST_Crosses()`

### Measurements
- `ST_Distance()`, `ST_Area()`, `ST_Length()`, `ST_Perimeter()`

### Transformations
- `ST_Buffer()`, `ST_Centroid()`, `ST_ConvexHull()`, `ST_Simplify()`

### Aggregations
- `ST_Union()`, `ST_Collect()`, `ST_Intersection()`

### Accessors
- `ST_X()`, `ST_Y()`, `ST_XMin()`, `ST_XMax()`, `ST_YMin()`, `ST_YMax()`

### Validation
- `ST_IsValid()`, `ST_IsSimple()`, `ST_IsEmpty()`

### Outputs
- `ST_AsText()`, `ST_AsGeoJSON()`, `ST_AsBinary()`

---

## 💡 Common Gotchas

1. **Distance Units**: Remember distances are in degrees for lat/lon data
   - ~0.01 degrees ≈ 1 km at mid-latitudes
   - Use projected CRS for accurate metric distances

2. **Coordinate Order**: Sedona uses (X, Y) = (Lon, Lat)
   - ST_Point(longitude, latitude) not (lat, lon)

3. **Performance**: Always use spatial predicates in WHERE clause when possible
   - Filter before joining when possible

4. **Null Geometries**: Check for null geometries before spatial operations
   - Use `WHERE geom IS NOT NULL`

5. **Topology**: Use `ST_SimplifyPreserveTopology()` instead of `ST_Simplify()`
   - Preserves topological relationships

---

## 🔗 Useful Resources

- [Official Documentation](https://sedona.apache.org/)
- [SQL Functions Reference](https://sedona.apache.org/latest-snapshot/api/sql/Function/)
- [Performance Tuning Guide](https://sedona.apache.org/latest-snapshot/tutorial/sql/#performance-tuning)

---

**Version**: Apache Sedona 1.8.0  
**Last Updated**: October 2025
