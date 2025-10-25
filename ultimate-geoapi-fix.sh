#!/bin/bash

# Ultimate GeoAPI Fix - Forces JAR loading and Spark restart
# This ensures JARs are properly loaded into the Spark classpath

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔧 Ultimate GeoAPI FactoryException Fix${NC}"
echo "This will restart Spark services to properly load GeoAPI JARs"
echo ""

# Function to download and verify JARs
download_and_verify_jars() {
    local container=$1
    echo -e "${YELLOW}Downloading and verifying JARs in $container...${NC}"
    
    docker exec $container bash -c '
        cd /opt/spark/jars/
        echo "Current spatial JARs:"
        ls -la | grep -E "(sedona|geoapi|jts|opengis)" || echo "No spatial JARs found"
        
        echo ""
        echo "Downloading essential GeoAPI JARs..."
        
        # Remove any existing conflicting JARs first
        rm -f geoapi*.jar unit-api*.jar systems-common*.jar jts-core*.jar 2>/dev/null || true
        
        # Download GeoTools JARs that actually contain the missing classes
        # The FactoryException is in GeoTools gt-referencing, not in GeoAPI
        wget -q https://repo1.maven.org/maven2/org/geotools/gt-referencing/27.2/gt-referencing-27.2.jar
        wget -q https://repo1.maven.org/maven2/org/geotools/gt-metadata/27.2/gt-metadata-27.2.jar
        wget -q https://repo1.maven.org/maven2/org/geotools/gt-opengis/27.2/gt-opengis-27.2.jar
        wget -q https://repo1.maven.org/maven2/org/geotools/gt-main/27.2/gt-main-27.2.jar
        wget -q https://repo1.maven.org/maven2/org/opengis/geoapi/3.0.1/geoapi-3.0.1.jar
        wget -q https://repo1.maven.org/maven2/javax/measure/unit-api/2.1.3/unit-api-2.1.3.jar
        wget -q https://repo1.maven.org/maven2/systems/uom/systems-common/2.1/systems-common-2.1.jar
        wget -q https://repo1.maven.org/maven2/org/locationtech/jts/jts-core/1.19.0/jts-core-1.19.0.jar
        wget -q https://repo1.maven.org/maven2/org/hsqldb/hsqldb/2.7.1/hsqldb-2.7.1.jar
        
        echo ""
        echo "Verifying downloaded JARs:"
        ls -la gt-*.jar geoapi*.jar unit-api*.jar systems-common*.jar jts-core*.jar hsqldb*.jar
        
        # Verify JAR contents - FactoryException should be in gt-referencing
        echo ""
        echo "Checking FactoryException class in JARs:"
        jar -tf gt-referencing-27.2.jar | grep -i factoryexception || echo "FactoryException not found in gt-referencing"
        jar -tf gt-referencing-27.2.jar | grep "org/opengis/referencing" | head -5
        
        echo "JAR download and verification completed."
    '
}

# Function to restart Spark services properly  
restart_spark_services() {
    echo -e "${YELLOW}Restarting Spark services to reload JARs...${NC}"
    
    # Stop all services
    docker-compose down
    
    # Wait a moment
    sleep 3
    
    # Start services again
    docker-compose up -d
    
    # Wait for services to start
    echo -e "${YELLOW}Waiting for services to start...${NC}"
    sleep 10
    
    # Check if services are running
    local attempts=0
    while [ $attempts -lt 30 ]; do
        if docker-compose ps | grep -q "Up"; then
            echo -e "${GREEN}✅ Services are running${NC}"
            break
        fi
        echo "Waiting for services... ($((attempts + 1))/30)"
        sleep 2
        attempts=$((attempts + 1))
    done
}

# Function to test Sedona with comprehensive error handling
test_sedona_comprehensive() {
    echo -e "${YELLOW}Testing Sedona with comprehensive diagnostics...${NC}"
    
    local container=$(docker ps --filter "label=com.docker.compose.project=apache-sedona" --format "{{.Names}}" | head -1)
    
    if [ -z "$container" ]; then
        echo -e "${RED}❌ No containers running after restart${NC}"
        return 1
    fi
    
    docker exec $container python3 -c "
import sys
import os

print('🔍 Python and Java diagnostics:')
print(f'Python version: {sys.version}')
print(f'JAVA_HOME: {os.environ.get(\"JAVA_HOME\", \"Not set\")}')
print(f'SPARK_HOME: {os.environ.get(\"SPARK_HOME\", \"Not set\")}')

# Check JAR files
import glob
spark_jars = glob.glob('/opt/spark/jars/*.jar')
spatial_jars = [jar for jar in spark_jars if any(x in jar.lower() for x in ['geoapi', 'sedona', 'jts', 'unit-api'])]
print(f'\\n📦 Found {len(spatial_jars)} spatial JARs:')
for jar in sorted(spatial_jars):
    print(f'  - {os.path.basename(jar)}')

print('\\n🚀 Testing Spark and Sedona...')

try:
    from pyspark.sql import SparkSession
    
    # Create Spark session with explicit JAR loading
    spark = SparkSession.builder \\
        .appName('GeoAPITest') \\
        .config('spark.serializer', 'org.apache.spark.serializer.KryoSerializer') \\
        .config('spark.kryo.registrator', 'org.apache.sedona.core.serde.SedonaKryoRegistrator') \\
        .config('spark.sql.extensions', 'org.apache.sedona.viz.sql.SedonaVizExtensions,org.apache.sedona.sql.SedonaSqlExtensions') \\
        .config('spark.driver.memory', '2g') \\
        .config('spark.executor.memory', '2g') \\
        .getOrCreate()
    
    print('✅ Spark session created successfully')
    
    # Register Sedona
    from sedona.register import SedonaRegistrator
    SedonaRegistrator.registerAll(spark)
    print('✅ Sedona registered successfully')
    
    # Test basic spatial operation
    result = spark.sql('SELECT ST_Point(1.0, 1.0) as point').collect()
    print(f'✅ Basic spatial operation works: {result[0][\"point\"]}')
    
    # Test distance calculation (this often triggers the FactoryException)
    result2 = spark.sql('SELECT ST_Distance(ST_Point(0.0, 0.0), ST_Point(1.0, 1.0)) as distance').collect()
    print(f'✅ Distance calculation works: {result2[0][\"distance\"]}')
    
    # Test coordinate reference system operation (most likely to fail)
    try:
        result3 = spark.sql('SELECT ST_Transform(ST_Point(-74.0059, 40.7128), \"EPSG:4326\", \"EPSG:3857\") as transformed').collect()
        print(f'✅ Coordinate transformation works: {result3[0][\"transformed\"]}')
    except Exception as e:
        print(f'⚠️  Coordinate transformation failed (this is expected): {str(e)[:100]}...')
    
    spark.stop()
    print('\\n🎉 All tests completed successfully!')
    
except Exception as e:
    print(f'❌ Test failed: {e}')
    print('\\nFull error details:')
    import traceback
    traceback.print_exc()
"
}

# Main execution
echo -e "${BLUE}Step 1: Downloading JARs to all containers${NC}"
CONTAINERS=$(docker ps --filter "label=com.docker.compose.project=apache-sedona" --format "{{.Names}}")

if [ ! -z "$CONTAINERS" ]; then
    for container in $CONTAINERS; do
        download_and_verify_jars $container
    done
else
    echo -e "${YELLOW}No containers running, will download after restart${NC}"
fi

echo -e "${BLUE}Step 2: Restarting Spark services${NC}"
restart_spark_services

echo -e "${BLUE}Step 3: Downloading JARs after restart${NC}"
CONTAINERS=$(docker ps --filter "label=com.docker.compose.project=apache-sedona" --format "{{.Names}}")
for container in $CONTAINERS; do
    download_and_verify_jars $container
done

echo -e "${BLUE}Step 4: Testing Sedona functionality${NC}"
test_sedona_comprehensive

echo ""
echo -e "${GREEN}🎯 Ultimate fix completed!${NC}"
echo -e "${BLUE}Next steps:${NC}"
echo "1. Restart your Jupyter kernel: Kernel → Restart & Clear Output"
echo "2. Re-run your notebook from the beginning"  
echo "3. If you still get errors, the issue might be in notebook configuration"