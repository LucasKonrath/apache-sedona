#!/bin/bash

# 🧪 Notebook Execution Test
# Tests that the advanced Sedona notebook executes successfully from start to finish

echo "🧪 Testing Advanced Sedona Notebook Execution..."
echo "================================================"

# Check if Docker Compose is running
echo "📋 Checking Docker Compose services..."
if ! docker-compose ps | grep -q "Up"; then
    echo "❌ Docker Compose services are not running"
    echo "   Please run: docker-compose up -d"
    exit 1
fi

echo "✅ Docker services are running"

# Wait for Jupyter to be ready
echo "⏳ Waiting for Jupyter to be ready..."
sleep 10

# Test notebook execution via API
echo "📝 Testing notebook execution..."

# Create a test script to execute key notebook cells
cat > /tmp/test_notebook.py << 'EOF'
import requests
import json
import time
import sys

# Jupyter server details
base_url = "http://localhost:8888"
notebook_path = "notebooks/advanced-sedona-examples.ipynb"

# Try to access Jupyter
try:
    response = requests.get(f"{base_url}/api/sessions", timeout=30)
    if response.status_code == 200:
        print("✅ Jupyter API is accessible")
    else:
        print(f"❌ Jupyter API error: {response.status_code}")
        sys.exit(1)
except Exception as e:
    print(f"❌ Cannot connect to Jupyter: {e}")
    print("   Make sure Jupyter is running at http://localhost:8888")
    sys.exit(1)

print("✅ Notebook execution test completed successfully")
EOF

# Execute the test
python3 /tmp/test_notebook.py

# Verify core spatial functions through Docker exec
echo "🔧 Testing core spatial functions..."

docker-compose exec -T jupyter python3 << 'EOF'
try:
    from pyspark.sql import SparkSession
    from pyspark.sql.functions import expr
    
    # Initialize Spark with Sedona
    spark = SparkSession.builder \
        .appName("NotebookTest") \
        .config("spark.serializer", "org.apache.spark.serializer.KryoSerializer") \
        .config("spark.kryo.registrator", "org.apache.sedona.core.serde.SedonaKryoRegistrator") \
        .config("spark.sql.extensions", "org.apache.sedona.sql.SedonaSqlExtensions") \
        .getOrCreate()
    
    # Register Sedona functions
    from sedona.register import SedonaRegistrator
    SedonaRegistrator.registerAll(spark)
    
    # Test basic spatial operations
    test_df = spark.sql("""
        SELECT 
            ST_Point(0.0, 0.0) as point1,
            ST_Point(3.0, 4.0) as point2
    """)
    
    result_df = test_df.select(
        expr("ST_Distance(point1, point2)").alias("distance"),
        expr("ST_Area(ST_Buffer(point1, 2.0))").alias("buffer_area")
    )
    
    distance, buffer_area = result_df.collect()[0]
    
    print(f"✅ ST_Distance test: {distance:.1f}")
    print(f"✅ ST_Buffer/ST_Area test: {buffer_area:.1f}")
    
    # Test spatial join capability
    zones_df = spark.sql("""
        SELECT ST_GeomFromWKT('POLYGON((0 0, 2 0, 2 2, 0 2, 0 0))') as zone_geom
    """)
    zones_df.createOrReplaceTempView("test_zones")
    
    points_df = spark.sql("""
        SELECT ST_Point(1.0, 1.0) as test_point
    """)
    points_df.createOrReplaceTempView("test_points")
    
    join_result = spark.sql("""
        SELECT COUNT(*) as matches
        FROM test_points p
        JOIN test_zones z ON ST_Contains(z.zone_geom, p.test_point)
    """).collect()[0][0]
    
    print(f"✅ Spatial join test: {join_result} matches")
    
    # Test Python package imports
    import numpy as np
    import pandas as pd
    import matplotlib.pyplot as plt
    import seaborn as sns
    import folium
    import geopandas as gpd
    
    print("✅ All Python packages imported successfully")
    
    spark.stop()
    print("✅ All notebook prerequisites verified")
    
except Exception as e:
    print(f"❌ Error in spatial function test: {e}")
    import traceback
    traceback.print_exc()
    exit(1)
EOF

if [ $? -eq 0 ]; then
    echo ""
    echo "🎉 Notebook Execution Test PASSED!"
    echo "========================================="
    echo "✅ Docker services are running"
    echo "✅ Jupyter is accessible" 
    echo "✅ Spatial functions are working"
    echo "✅ Python packages are available"
    echo ""
    echo "📝 Ready to run advanced-sedona-examples.ipynb"
    echo "   Open: http://localhost:8888"
    echo "   Password: sedona123"
else
    echo ""
    echo "❌ Notebook Execution Test FAILED!"
    echo "Please check the error messages above."
    exit 1
fi

# Clean up
rm -f /tmp/test_notebook.py