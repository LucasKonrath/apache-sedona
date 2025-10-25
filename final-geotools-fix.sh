#!/bin/bash

echo "🔧 FINAL GeoTools FactoryException Fix"
echo "====================================="

# GeoTools version compatible with Sedona 1.4.1
GEOTOOLS_VERSION="27.2"
BASE_URL="https://repo1.maven.org/maven2/org/geotools"

# Required GeoTools JARs containing the missing classes
JARS=(
    "gt-referencing/${GEOTOOLS_VERSION}/gt-referencing-${GEOTOOLS_VERSION}.jar"
    "gt-metadata/${GEOTOOLS_VERSION}/gt-metadata-${GEOTOOLS_VERSION}.jar"
    "gt-opengis/${GEOTOOLS_VERSION}/gt-opengis-${GEOTOOLS_VERSION}.jar"
)

echo "📦 Downloading missing GeoTools JARs..."
mkdir -p geotools-jars
cd geotools-jars

for jar in "${JARS[@]}"; do
    filename=$(basename "$jar")
    url="${BASE_URL}/${jar}"
    
    echo "  📥 Downloading $filename..."
    curl -L -s -o "$filename" "$url"
    
    if [ -f "$filename" ] && [ -s "$filename" ]; then
        echo "  ✅ Downloaded $filename ($(ls -lh "$filename" | awk '{print $5}'))"
    else
        echo "  ❌ Failed to download $filename"
        exit 1
    fi
done

echo ""
echo "🚀 Copying JARs to all containers..."

# Copy to all Spark containers
for container in sedona-worker sedona-master sedona-pyspark sedona-jupyter; do
    echo "  📦 Copying to $container..."
    
    for jar_file in *.jar; do
        docker cp "$jar_file" "${container}:/opt/spark/jars/"
        if [ $? -eq 0 ]; then
            echo "    ✅ $jar_file → $container"
        else
            echo "    ❌ Failed: $jar_file → $container"
        fi
    done
done

cd ..
rm -rf geotools-jars

echo ""
echo "🔍 Verifying GeoTools JARs are now present..."
docker exec sedona-worker ls -la /opt/spark/jars/ | grep -E "gt-" | head -5

echo ""
echo "🧪 Testing FactoryException fix..."
docker exec sedona-pyspark python3 -c "
import os
os.environ['PYSPARK_PYTHON'] = 'python3'

from pyspark.sql import SparkSession
from sedona.register import SedonaRegistrator
from sedona.utils import SedonaKryoRegistrator, KryoSerializer

try:
    # Create Spark session with Sedona
    spark = (SparkSession.builder
             .appName('FactoryException Test')
             .config('spark.serializer', KryoSerializer.getName)
             .config('spark.kryo.registrator', SedonaKryoRegistrator.getName)
             .config('spark.jars.packages', 'org.apache.sedona:sedona-python-adapter-3.0_2.12:1.4.1,org.apache.sedona:sedona-viz-3.0_2.12:1.4.1')
             .getOrCreate())
    
    print('✅ Spark session created')
    
    # Register Sedona functions
    SedonaRegistrator.registerAll(spark)
    print('✅ Sedona registered')
    
    # Test the function that triggers FactoryException
    spark.sql(\"SELECT ST_Distance(ST_Point(0.0, 0.0), ST_Point(1.0, 1.0)) as distance\").show()
    print('✅ ST_Distance test passed - FactoryException FIXED!')
    
    spark.stop()
    
except Exception as e:
    print(f'❌ Test failed: {str(e)[:200]}...')
    import traceback
    traceback.print_exc()
"

echo ""
echo "🎯 Fix complete! GeoTools JARs should now be loaded."