# Sedona 1.8.0 API Changes

## Important: Python Import Changes

In **Apache Sedona 1.8.0**, the way spatial functions are accessed has changed from previous versions.

### ❌ Old Way (Sedona 1.4.1 and earlier)
```python
from sedona.sql.st_functions import ST_Buffer, ST_Distance, ST_Intersects

# This will cause ImportError in Sedona 1.8.0
```

### ✅ New Way (Sedona 1.8.0)

**Option 1: Use SQL expressions (Recommended)**
```python
# All spatial functions are accessed via SQL
result = spark.sql("""
    SELECT 
        ST_Buffer(geom, 0.01) as buffer_geom,
        ST_Distance(geom1, geom2) as distance
    FROM my_table
""")
```

**Option 2: Use expr() for DataFrame API**
```python
from pyspark.sql.functions import expr

df = df.withColumn("buffer_geom", expr("ST_Buffer(geom, 0.01)"))
df = df.withColumn("distance", expr("ST_Distance(geom1, geom2)"))
```

**Option 3: Use sedona.sql.st_constructors for geometry creation**
```python
from sedona.sql.st_constructors import ST_Point, ST_PolygonFromEnvelope
from pyspark.sql.functions import expr

# Create geometries
df = df.withColumn("point_geom", ST_Point("lon", "lat"))

# For other operations, use expr()
df = df.withColumn("buffer", expr("ST_Buffer(point_geom, 0.01)"))
```

## Fixed Functions in Notebooks

The following functions are now accessed via SQL only:

### Transformations
- `ST_Buffer()` - Create buffer zones
- `ST_Centroid()` - Find center point
- `ST_ConvexHull()` - Calculate convex hull
- `ST_Simplify()` - Reduce vertices
- `ST_SimplifyPreserveTopology()` - Simplify preserving topology
- `ST_Envelope()` - Get bounding box

### Predicates
- `ST_Contains()` - Point-in-polygon
- `ST_Intersects()` - Check intersection
- `ST_Within()` - Containment check
- `ST_Touches()` - Adjacent features
- `ST_Crosses()` - Line crossings

### Measurements
- `ST_Distance()` - Calculate distance
- `ST_Area()` - Calculate area
- `ST_Perimeter()` - Calculate perimeter
- `ST_Length()` - Calculate length

### Aggregations
- `ST_Union()` - Merge geometries
- `ST_Collect()` - Collect into collection
- `ST_Intersection()` - Get intersection

### Accessors
- `ST_X()`, `ST_Y()` - Get coordinates
- `ST_XMin()`, `ST_XMax()`, `ST_YMin()`, `ST_YMax()` - Bounding box
- `ST_NumPoints()` - Count vertices

## Migration Guide

### Before (Sedona 1.4.1)
```python
from sedona.sql.st_functions import ST_Buffer, ST_Area

# Create buffer
buffered = df.withColumn("buffer", ST_Buffer("geom", 0.01))

# Calculate area  
area_df = df.withColumn("area", ST_Area("geom"))
```

### After (Sedona 1.8.0)
```python
from pyspark.sql.functions import expr

# Create buffer
buffered = df.withColumn("buffer", expr("ST_Buffer(geom, 0.01)"))

# Calculate area
area_df = df.withColumn("area", expr("ST_Area(geom)"))

# Or use SQL directly (recommended for complex queries)
result = spark.sql("""
    SELECT 
        *,
        ST_Buffer(geom, 0.01) as buffer,
        ST_Area(geom) as area
    FROM my_table
""")
```

## Benefits of SQL-Based Approach

1. **Better Performance**: Query optimizer can analyze entire query
2. **Cleaner Code**: Complex spatial queries are more readable in SQL
3. **Standard SQL**: More portable across different Sedona deployments
4. **Type Safety**: SQL parser validates function calls

## Example: Complete Migration

### Old Code
```python
from sedona.sql.st_functions import (
    ST_Buffer, ST_Distance, ST_Contains, 
    ST_Area, ST_Intersects
)

# Create buffers
buffers = points_df.withColumn(
    "buffer_500m", 
    ST_Buffer("point_geom", 0.005)
)

# Find overlaps
overlaps = buffers.alias("b1").join(
    buffers.alias("b2"),
    ST_Intersects(col("b1.buffer_500m"), col("b2.buffer_500m"))
)
```

### New Code
```python
from pyspark.sql.functions import expr

# Register as temp view
points_df.createOrReplaceTempView("points")

# Use SQL for everything
result = spark.sql("""
    SELECT 
        b1.id as id1,
        b2.id as id2,
        ST_Area(ST_Intersection(b1.buffer_500m, b2.buffer_500m)) as overlap_area
    FROM (
        SELECT 
            id,
            ST_Buffer(point_geom, 0.005) as buffer_500m
        FROM points
    ) b1
    CROSS JOIN (
        SELECT 
            id,
            ST_Buffer(point_geom, 0.005) as buffer_500m
        FROM points
    ) b2
    WHERE b1.id < b2.id
    AND ST_Intersects(b1.buffer_500m, b2.buffer_500m)
""")
```

## Constructors Still Work

These constructors can still be imported directly:

```python
from sedona.sql.st_constructors import (
    ST_Point,
    ST_PolygonFromEnvelope,
    ST_LineStringFromText,
    ST_GeomFromWKT,
    ST_GeomFromText
)

# These work in DataFrame API
df = df.withColumn("point", ST_Point("lon", "lat"))
df = df.withColumn("poly", ST_PolygonFromEnvelope("minx", "miny", "maxx", "maxy"))
```

## Troubleshooting

### Error: `ImportError: cannot import name 'ST_Buffer'`

**Solution**: Remove the import and use SQL or `expr()` instead.

```python
# ❌ This doesn't work
from sedona.sql.st_functions import ST_Buffer

# ✅ Do this instead
from pyspark.sql.functions import expr
df = df.withColumn("buffer", expr("ST_Buffer(geom, 0.01)"))

# ✅ Or this
result = spark.sql("SELECT ST_Buffer(geom, 0.01) as buffer FROM table")
```

### Error: Function not recognized in SQL

**Solution**: Ensure Sedona is properly registered:

```python
from sedona.register import SedonaRegistrator

# Register all Sedona functions
SedonaRegistrator.registerAll(spark)

# Or use SedonaContext (preferred in 1.8.0)
from sedona.spark import SedonaContext

config = SedonaContext.builder().getOrCreate()
sedona = SedonaContext.create(config)
```

## Resources

- [Sedona 1.8.0 Release Notes](https://sedona.apache.org/latest-snapshot/setup/release-notes/)
- [SQL API Reference](https://sedona.apache.org/latest-snapshot/api/sql/Function/)
- [Migration Guide](https://sedona.apache.org/latest-snapshot/setup/migration/)

---

**All notebooks in this project have been updated to use the Sedona 1.8.0 API correctly.**
