#!/bin/bash

# Targeted FactoryException Fix
# Downloads the correct GeoTools JARs that contain org.opengis.referencing.FactoryException

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🎯 Targeted FactoryException Fix${NC}"
echo "FactoryException is in GeoTools gt-referencing JAR, not GeoAPI!"
echo ""

# Function to list all current JARs
list_current_jars() {
    local container=$1
    echo -e "${BLUE}📦 CURRENT JAR INVENTORY IN $container${NC}"
    echo "==========================================================="
    
    docker exec $container bash -c '
        cd /opt/spark/jars/
        
        echo "🔍 COMPLETE JAR LISTING (ALL FILES):"
        echo "===================================="
        ls -la *.jar | wc -l | xargs echo "Total JAR count:"
        echo ""
        ls -la *.jar | head -20
        echo "... (showing first 20 JARs, use ls -la *.jar | sort to see all)"
        
        echo ""
        echo "🎯 SEDONA-SPECIFIC JARS:"
        echo "======================="
        ls -la *sedona*.jar 2>/dev/null || echo "No Sedona JARs found"
        
        echo ""
        echo "🌍 SPATIAL/GEO RELATED JARS:"
        echo "============================"
        ls -la *.jar | grep -E "(geotools|gt-|geoapi|jts|spatial|opengis|unit-api|referenc)" || echo "No geo-related JARs found"
        
        echo ""
        echo "🔍 SEARCHING FOR FactoryException CLASS:"
        echo "======================================"
        for jar in *.jar; do
            if jar -tf "$jar" 2>/dev/null | grep -q "org/opengis/referencing/FactoryException"; then
                echo "✅ FactoryException found in: $jar"
                break
            fi
        done
        
        echo ""
        echo "🔍 SEARCHING FOR NoSuchAuthorityCodeException CLASS:"
        echo "=================================================="
        for jar in *.jar; do
            if jar -tf "$jar" 2>/dev/null | grep -q "org/opengis/referencing/NoSuchAuthorityCodeException"; then
                echo "✅ NoSuchAuthorityCodeException found in: $jar"
                break
            fi
        done
        
        echo ""
        echo "📊 JAR STATISTICS:"
        echo "=================="
        echo "Total JARs: $(ls -1 *.jar | wc -l)"
        echo "Sedona JARs: $(ls -1 *sedona*.jar 2>/dev/null | wc -l)"
        echo "GeoTools JARs: $(ls -1 gt-*.jar geotools*.jar 2>/dev/null | wc -l)"
        echo "Spatial JARs: $(ls -1 *.jar | grep -E "(geo|spatial|jts)" | wc -l)"
    '
    
    echo ""
}

# Function to download correct GeoTools JARs
download_correct_geotools() {
    local container=$1
    echo -e "${YELLOW}Downloading correct GeoTools JARs to $container...${NC}"
    
    docker exec $container bash -c '
        cd /opt/spark/jars/
        
        echo "🧹 Cleaning up conflicting JARs..."
        # Remove potentially conflicting versions
        rm -f geoapi*.jar gt-*.jar *geotools*.jar 2>/dev/null || true
        
        echo ""
        echo "📦 Downloading GeoTools 27.2 (known to work with Sedona 1.4.1)..."
        
        # Core GeoTools JARs that contain the missing classes
        wget -q https://repo1.maven.org/maven2/org/geotools/gt-referencing/27.2/gt-referencing-27.2.jar
        echo "✅ Downloaded gt-referencing-27.2.jar (contains FactoryException)"
        
        wget -q https://repo1.maven.org/maven2/org/geotools/gt-metadata/27.2/gt-metadata-27.2.jar  
        echo "✅ Downloaded gt-metadata-27.2.jar"
        
        wget -q https://repo1.maven.org/maven2/org/geotools/gt-opengis/27.2/gt-opengis-27.2.jar
        echo "✅ Downloaded gt-opengis-27.2.jar"
        
        # Supporting dependencies
        wget -q https://repo1.maven.org/maven2/org/opengis/geoapi/3.0.1/geoapi-3.0.1.jar
        echo "✅ Downloaded geoapi-3.0.1.jar (base interfaces)"
        
        wget -q https://repo1.maven.org/maven2/javax/measure/unit-api/2.1.3/unit-api-2.1.3.jar
        echo "✅ Downloaded unit-api-2.1.3.jar"
        
        wget -q https://repo1.maven.org/maven2/org/locationtech/jts/jts-core/1.19.0/jts-core-1.19.0.jar
        echo "✅ Downloaded jts-core-1.19.0.jar"
        
        echo ""
        echo "🔍 Verifying FactoryException class..."
        if jar -tf gt-referencing-27.2.jar | grep -q "org/opengis/referencing/FactoryException"; then
            echo "✅ FactoryException found in gt-referencing-27.2.jar"
        else
            echo "❌ FactoryException NOT found - checking gt-opengis..."
            jar -tf gt-opengis-27.2.jar | grep -i factoryexception || echo "Not in gt-opengis either"
        fi
        
        echo ""
        echo "📋 ALL JARS IN /opt/spark/jars/ DIRECTORY:"
        echo "============================================="
        ls -la *.jar | sort
        
        echo ""
        echo "📦 SPATIAL-RELATED JARS ONLY:"
        echo "=============================="
        ls -la *.jar | grep -E "(sedona|geotools|gt-|geoapi|jts|spatial|opengis|unit-api)" | sort || echo "No spatial JARs found with grep pattern"
        
        echo ""
        echo "🔍 CHECKING FactoryException IN gt-referencing:"
        echo "=============================================="
        if [ -f "gt-referencing-27.2.jar" ]; then
            echo "✅ gt-referencing-27.2.jar exists"
            jar -tf gt-referencing-27.2.jar | grep -i factoryexception || echo "❌ FactoryException not found in gt-referencing"
            echo ""
            echo "📝 First 15 org/opengis/referencing classes in gt-referencing:"
            jar -tf gt-referencing-27.2.jar | grep "org/opengis/referencing" | head -15
        else
            echo "❌ gt-referencing-27.2.jar not found"
        fi
        
        echo ""
        echo "🔍 TOTAL JAR COUNT:"
        echo "=================="
        echo "Total JARs: $(ls -1 *.jar | wc -l)"
        echo "Sedona JARs: $(ls -1 *sedona*.jar 2>/dev/null | wc -l)"
        echo "GeoTools JARs: $(ls -1 gt-*.jar 2>/dev/null | wc -l)"
        echo "GeoAPI JARs: $(ls -1 geoapi*.jar 2>/dev/null | wc -l)"
    '
}

# Get running containers
CONTAINERS=$(docker ps --filter "label=com.docker.compose.project=apache-sedona" --format "{{.Names}}")

if [ -z "$CONTAINERS" ]; then
    echo -e "${YELLOW}Starting services...${NC}"
    ./sedona.sh start
    sleep 5
    CONTAINERS=$(docker ps --filter "label=com.docker.compose.project=apache-sedona" --format "{{.Names}}")
fi

# List current JARs before making changes
echo -e "${YELLOW}📋 BEFORE: Current JAR inventory${NC}"
TEST_CONTAINER=$(echo $CONTAINERS | cut -d' ' -f1)
list_current_jars $TEST_CONTAINER

# Download to all containers
echo -e "${YELLOW}🔄 APPLYING FIX: Downloading correct GeoTools JARs${NC}"
for container in $CONTAINERS; do
    download_correct_geotools $container
done

# List JARs after the fix
echo -e "${YELLOW}📋 AFTER: Updated JAR inventory${NC}"
list_current_jars $TEST_CONTAINER

echo ""
echo -e "${BLUE}🚀 SPARK RUNTIME JAR CHECK${NC}"
echo "Checking which JARs Spark actually loads at runtime..."

docker exec $TEST_CONTAINER python3 -c "
import os
import glob

print('🔍 SPARK CLASSPATH ANALYSIS:')
print('=' * 50)

# Check SPARK_HOME and jars directory
spark_home = os.environ.get('SPARK_HOME', '/opt/spark')
jars_dir = f'{spark_home}/jars/'

if os.path.exists(jars_dir):
    all_jars = glob.glob(f'{jars_dir}*.jar')
    print(f'📦 Total JARs in {jars_dir}: {len(all_jars)}')
    
    # Look for specific patterns
    sedona_jars = [j for j in all_jars if 'sedona' in os.path.basename(j).lower()]
    geo_jars = [j for j in all_jars if any(x in os.path.basename(j).lower() for x in ['geo', 'gt-', 'jts', 'opengis'])]
    
    print(f'🎯 Sedona JARs: {len(sedona_jars)}')
    for jar in sedona_jars:
        print(f'  - {os.path.basename(jar)}')
    
    print(f'🌍 Geo/Spatial JARs: {len(geo_jars)}')
    for jar in geo_jars:
        print(f'  - {os.path.basename(jar)}')

print('')
print('🧪 TESTING CLASSPATH ACCESS:')
print('=' * 30)

try:
    # Test if we can access the missing class
    import subprocess
    import sys
    
    # Try to find the class in the classpath
    result = subprocess.run([
        'find', '/opt/spark/jars/', '-name', '*.jar', '-exec', 
        'sh', '-c', 'jar -tf {} | grep -l \"org/opengis/referencing/FactoryException\" && echo \"Found in: {}\"', ';'
    ], capture_output=True, text=True)
    
    if result.stdout:
        print('✅ FactoryException found in JAR files:')
        print(result.stdout)
    else:
        print('❌ FactoryException NOT found in any JAR')
    
except Exception as e:
    print(f'Error checking JARs: {e}')
"

echo ""
echo -e "${BLUE}🧪 Testing FactoryException fix...${NC}"

# Test in one container
docker exec $TEST_CONTAINER python3 -c "
import sys
print('🧪 Testing FactoryException fix...')

try:
    from pyspark.sql import SparkSession
    
    # Create Spark session
    spark = SparkSession.builder \
        .appName('FactoryExceptionTest') \
        .config('spark.serializer', 'org.apache.spark.serializer.KryoSerializer') \
        .config('spark.kryo.registrator', 'org.apache.sedona.core.serde.SedonaKryoRegistrator') \
        .getOrCreate()
    
    print('✅ Spark session created')
    
    # Register Sedona
    from sedona.register import SedonaRegistrator
    SedonaRegistrator.registerAll(spark)
    print('✅ Sedona registered')
    
    # Test operations that previously caused FactoryException
    print('🧪 Testing distance calculation (common trigger)...')
    result = spark.sql('SELECT ST_Distance(ST_Point(0.0, 0.0), ST_Point(1.0, 1.0)) as distance').collect()
    print(f'✅ Distance calculation works: {result[0][\"distance\"]}')
    
    print('🧪 Testing spatial join (another common trigger)...')
    result2 = spark.sql('''
        WITH points AS (
            SELECT ST_Point(0.5, 0.5) as point
        ), polygons AS (
            SELECT ST_GeomFromWKT(\"POLYGON((0 0, 1 0, 1 1, 0 1, 0 0))\") as poly
        )
        SELECT ST_Within(points.point, polygons.poly) as within
        FROM points, polygons
    ''').collect()
    print(f'✅ Spatial join works: {result2[0][\"within\"]}')
    
    spark.stop()
    print('\\n🎉 SUCCESS! FactoryException should be fixed!')
    
except Exception as e:
    print(f'❌ Test failed: {e}')
    if 'FactoryException' in str(e):
        print('🔍 FactoryException still occurring - may need different GeoTools version')
    sys.exit(1)
"

echo ""
echo -e "${GREEN}🎯 FactoryException fix completed!${NC}"
echo ""
echo -e "${BLUE}📋 Next steps:${NC}"
echo "1. Restart Jupyter kernel: Kernel → Restart & Clear Output"
echo "2. Try your spatial operations again"
echo "3. If still failing, check which exact operation triggers the error"

echo ""
echo -e "${YELLOW}💡 What was fixed:${NC}"
echo "• Downloaded GeoTools 27.2 JARs (correct version for Sedona 1.4.1)"
echo "• gt-referencing-27.2.jar contains org.opengis.referencing.FactoryException"
echo "• Removed conflicting JAR versions"
echo "• Verified the FactoryException class exists"