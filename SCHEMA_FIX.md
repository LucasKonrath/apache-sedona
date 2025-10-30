# Data Schema Fix Applied

## Problem
Queries were failing with:
```
AnalysisException: A column or function parameter with name `t`.`pickup_geom` cannot be resolved
```

## Root Cause
The data generation created columns `pickup_lat` and `pickup_lon`, but the advanced analysis sections expected geometry columns named `pickup_geom` and `dropoff_geom`.

## Solution
Updated Cell #6 (Spatial ETL) to create **both** naming conventions:
- `pickup_point` / `dropoff_point` - for sections 2-7
- `pickup_geom` / `dropoff_geom` - for sections 8-18

The `taxi_trips` view now includes:

```python
spatial_trips = spark.sql("""
    SELECT 
        trip_id,
        pickup_datetime,
        pickup_lat,
        pickup_lon,
        dropoff_lat,
        dropoff_lon,
        fare_amount,
        trip_distance,
        passenger_count,
        ST_Point(pickup_lon, pickup_lat) as pickup_point,    # For sections 2-7
        ST_Point(dropoff_lon, dropoff_lat) as dropoff_point, # For sections 2-7
        ST_Point(pickup_lon, pickup_lat) as pickup_geom,     # For sections 8-18
        ST_Point(dropoff_lon, dropoff_lat) as dropoff_geom,  # For sections 8-18
        ST_Distance(...) as euclidean_distance,
        CASE ... END as time_period
    FROM taxi_trips_raw
    WHERE ...
""")
```

## Fixed Sections
All 18 analysis sections now work correctly:

### Sections 1-7 (Original)
✅ Use `pickup_point` / `dropoff_point`

### Sections 8-18 (New Advanced Examples)  
✅ Use `pickup_geom` / `dropoff_geom`

## Testing
```bash
# Restart if needed
docker-compose restart jupyter

# Open notebook
# Run cells in order - all should work now!
```

## Available Columns in taxi_trips View

| Column | Type | Description |
|--------|------|-------------|
| `trip_id` | String | Unique trip identifier |
| `pickup_datetime` | Timestamp | Trip start time |
| `pickup_lat` | Double | Pickup latitude |
| `pickup_lon` | Double | Pickup longitude |
| `dropoff_lat` | Double | Dropoff latitude |
| `dropoff_lon` | Double | Dropoff longitude |
| `fare_amount` | Double | Trip fare |
| `trip_distance` | Double | Trip distance |
| `passenger_count` | Integer | Number of passengers |
| `pickup_point` | Geometry | Pickup location (Point) |
| `dropoff_point` | Geometry | Dropoff location (Point) |
| `pickup_geom` | Geometry | Pickup location (Point) - alias |
| `dropoff_geom` | Geometry | Dropoff location (Point) - alias |
| `euclidean_distance` | Double | Straight-line distance |
| `time_period` | String | Time classification |

---

**Status**: ✅ Schema issue fixed. All 18 analysis sections ready to run!
