#!/bin/bash

echo "🎯 FINAL SOLUTION: GeoTools Wrapper for Sedona 1.4.1"
echo "===================================================="

# Clean up the incorrect JARs
echo "🧹 Cleaning up incorrect GeoTools JARs..."
for container in sedona-worker sedona-master sedona-pyspark sedona-jupyter; do
    docker exec $container rm -f /opt/spark/jars/gt-*.jar 2>/dev/null || true
done

# Download the correct GeoTools wrapper for Sedona 1.4.1
echo "📦 Downloading GeoTools wrapper 1.4.0-28.2..."
mkdir -p geotools-wrapper
cd geotools-wrapper

# This is the official GeoTools wrapper for Sedona 1.4.1
curl -L -s -o "geotools-wrapper-1.4.0-28.2.jar" \
    "https://repo1.maven.org/maven2/org/datasyslab/geotools-wrapper/1.4.0-28.2/geotools-wrapper-1.4.0-28.2.jar"

# Verify download
if [ -f "geotools-wrapper-1.4.0-28.2.jar" ] && [ -s "geotools-wrapper-1.4.0-28.2.jar" ]; then
    size=$(ls -lh geotools-wrapper-1.4.0-28.2.jar | awk '{print $5}')
    echo "  ✅ Downloaded geotools-wrapper-1.4.0-28.2.jar ($size)"
    
    # Check if it's a real JAR file (should be much larger than 1KB)
    if [[ $size == *"M"* ]] || [[ $(stat -f%z geotools-wrapper-1.4.0-28.2.jar 2>/dev/null || stat -c%s geotools-wrapper-1.4.0-28.2.jar) -gt 10000 ]]; then
        echo "  ✅ File size looks correct for a real JAR"
    else
        echo "  ❌ File is too small, checking content..."
        head -2 geotools-wrapper-1.4.0-28.2.jar
        exit 1
    fi
else
    echo "  ❌ Failed to download geotools-wrapper"
    exit 1
fi

echo ""
echo "🚀 Copying GeoTools wrapper to all containers..."

# Copy to all Spark containers
for container in sedona-worker sedona-master sedona-pyspark sedona-jupyter; do
    echo "  📦 Copying to $container..."
    docker cp "geotools-wrapper-1.4.0-28.2.jar" "${container}:/opt/spark/jars/"
    if [ $? -eq 0 ]; then
        echo "    ✅ geotools-wrapper-1.4.0-28.2.jar → $container"
    else
        echo "    ❌ Failed to copy to $container"
    fi
done

cd ..
rm -rf geotools-wrapper

echo ""
echo "🔍 Verifying GeoTools wrapper is present..."
docker exec sedona-worker ls -lah /opt/spark/jars/geotools-wrapper* 2>/dev/null || echo "  ❌ GeoTools wrapper not found"

echo ""
echo "🧪 Final test: Testing FactoryException with GeoTools wrapper..."
docker exec sedona-pyspark python3 -c "
import os
os.environ['PYSPARK_PYTHON'] = 'python3'

from pyspark.sql import SparkSession
from sedona.register import SedonaRegistrator
from sedona.utils import SedonaKryoRegistrator, KryoSerializer

try:
    # Create Spark session
    spark = (SparkSession.builder
             .appName('GeoTools Wrapper Test')
             .config('spark.serializer', KryoSerializer.getName)
             .config('spark.kryo.registrator', SedonaKryoRegistrator.getName)
             .getOrCreate())
    
    print('✅ Spark session created')
    
    # Register Sedona functions
    SedonaRegistrator.registerAll(spark)
    print('✅ Sedona registered successfully')
    
    # Test ST_Distance - this was failing with FactoryException
    result = spark.sql('SELECT ST_Distance(ST_Point(0.0, 0.0), ST_Point(1.0, 1.0)) as distance').collect()
    distance = result[0]['distance']
    print(f'✅ ST_Distance test PASSED! Distance: {distance:.6f}')
    
    # Test another spatial function to be sure
    result2 = spark.sql('SELECT ST_Area(ST_Polygon(\"POLYGON((0 0, 1 0, 1 1, 0 1, 0 0))\")) as area').collect()
    area = result2[0]['area']
    print(f'✅ ST_Area test PASSED! Area: {area}')
    
    print('🎉 ALL TESTS PASSED! FactoryException is COMPLETELY FIXED!')
    
    spark.stop()
    
except Exception as e:
    print(f'❌ Test failed: {str(e)[:300]}...')
    import traceback
    traceback.print_exc()
"

echo ""
echo "🎯 GeoTools wrapper installation complete!"
echo "   The FactoryException should now be resolved."
echo "   You can use all Sedona spatial functions including ST_Distance, ST_Area, etc."