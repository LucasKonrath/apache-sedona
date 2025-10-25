#!/bin/bash

echo "🔧 CORRECT GeoTools Download & Fix"
echo "================================="

# Delete the incorrect 404 files
echo "🧹 Cleaning up 404 error files..."
for container in sedona-worker sedona-master sedona-pyspark sedona-jupyter; do
    docker exec $container rm -f /opt/spark/jars/gt-*.jar
done

# Use the correct Maven Central URLs for GeoTools 27.2
echo "📦 Downloading REAL GeoTools 27.2 JARs..."
mkdir -p real-geotools
cd real-geotools

# These are the correct URLs for GeoTools 27.2
echo "  📥 Downloading gt-referencing-27.2.jar..."
curl -L -s -o "gt-referencing-27.2.jar" "https://repo1.maven.org/maven2/org/geotools/gt-referencing/27.2/gt-referencing-27.2.jar"

echo "  📥 Downloading gt-metadata-27.2.jar..."  
curl -L -s -o "gt-metadata-27.2.jar" "https://repo1.maven.org/maven2/org/geotools/gt-metadata/27.2/gt-metadata-27.2.jar"

echo "  📥 Downloading gt-opengis-27.2.jar..."
curl -L -s -o "gt-opengis-27.2.jar" "https://repo1.maven.org/maven2/org/geotools/gt-opengis/27.2/gt-opengis-27.2.jar"

# Verify downloads
echo ""
echo "🔍 Verifying downloads..."
for jar in *.jar; do
    size=$(ls -lh "$jar" | awk '{print $5}')
    if [[ $size == *"K"* ]] || [[ $size == *"M"* ]]; then
        echo "  ✅ $jar: $size"
    else
        echo "  ❌ $jar: $size (too small - likely error)"
        head -2 "$jar"
        exit 1
    fi
done

echo ""
echo "🚀 Copying REAL JARs to all containers..."

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
rm -rf real-geotools

echo ""
echo "🔍 Verifying REAL GeoTools JARs are now present..."
docker exec sedona-worker ls -lah /opt/spark/jars/ | grep -E "gt-"

echo ""
echo "🧪 Testing FactoryException fix with REAL JARs..."
docker exec sedona-pyspark python3 -c "
import os
os.environ['PYSPARK_PYTHON'] = 'python3'

from pyspark.sql import SparkSession
from sedona.register import SedonaRegistrator
from sedona.utils import SedonaKryoRegistrator, KryoSerializer

try:
    # Create Spark session with Sedona
    spark = (SparkSession.builder
             .appName('FactoryException Test Final')
             .config('spark.serializer', KryoSerializer.getName)
             .config('spark.kryo.registrator', SedonaKryoRegistrator.getName)
             .getOrCreate())
    
    print('✅ Spark session created')
    
    # Register Sedona functions
    SedonaRegistrator.registerAll(spark)
    print('✅ Sedona registered')
    
    # Test the function that triggers FactoryException
    result = spark.sql(\"SELECT ST_Distance(ST_Point(0.0, 0.0), ST_Point(1.0, 1.0)) as distance\").collect()
    print(f'✅ ST_Distance test PASSED! Result: {result[0][\"distance\"]}')
    print('🎉 FactoryException is FIXED!')
    
    spark.stop()
    
except Exception as e:
    print(f'❌ Test still failed: {str(e)[:200]}...')
    import traceback
    traceback.print_exc()
"

echo ""
echo "🎯 GeoTools fix complete!"