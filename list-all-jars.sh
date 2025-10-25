#!/bin/bash

# Simple JAR Listing Script - Shows all JARs currently in Spark containers

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}📦 Apache Sedona JAR Inventory${NC}"
echo "==============================="

# Find running containers
CONTAINERS=$(docker ps --filter "label=com.docker.compose.project=apache-sedona" --format "{{.Names}}")

if [ -z "$CONTAINERS" ]; then
    echo -e "${RED}❌ No running Sedona containers found.${NC}"
    echo -e "${YELLOW}Start services with: ./sedona.sh start${NC}"
    exit 1
fi

echo -e "${GREEN}Found containers: $CONTAINERS${NC}"
echo ""

# Check first container
CONTAINER=$(echo $CONTAINERS | cut -d' ' -f1)
echo -e "${BLUE}📋 Checking JARs in container: $CONTAINER${NC}"

docker exec $CONTAINER bash -c '
echo "🔍 COMPLETE JAR INVENTORY"
echo "========================"
cd /opt/spark/jars/

echo "📊 TOTAL JAR COUNT:"
ls -1 *.jar | wc -l

echo ""
echo "📦 ALL JARS (sorted alphabetically):"
echo "====================================="
ls -1 *.jar | sort

echo ""
echo "🎯 SEDONA-SPECIFIC JARS:"
echo "======================="
ls -1 *sedona*.jar 2>/dev/null || echo "No Sedona JARs found"

echo ""
echo "🌍 GEOTOOLS JARS:"
echo "================="
ls -1 gt-*.jar geotools*.jar 2>/dev/null || echo "No GeoTools JARs found"

echo ""
echo "🗺️ GEOAPI JARS:"
echo "==============="
ls -1 geoapi*.jar 2>/dev/null || echo "No GeoAPI JARs found"

echo ""
echo "🔧 JTS GEOMETRY JARS:"
echo "===================="
ls -1 jts*.jar 2>/dev/null || echo "No JTS JARs found"

echo ""
echo "📏 UNIT/MEASUREMENT JARS:"
echo "========================="
ls -1 *unit*.jar *measure*.jar *uom*.jar 2>/dev/null || echo "No unit/measurement JARs found"

echo ""
echo "🔍 SPATIAL-RELATED JARS (comprehensive search):"
echo "=============================================="
ls -1 *.jar | grep -E "(spatial|geo|jts|opengis|referenc|coord|proj)" || echo "No spatial JARs found with pattern"

echo ""
echo "🎯 SEARCHING FOR PROBLEMATIC CLASSES:"
echo "===================================="

echo "Looking for FactoryException..."
for jar in *.jar; do
    if jar -tf "$jar" 2>/dev/null | grep -q "org/opengis/referencing/FactoryException.class"; then
        echo "✅ FactoryException found in: $jar"
    fi
done

echo ""
echo "Looking for NoSuchAuthorityCodeException..."
for jar in *.jar; do
    if jar -tf "$jar" 2>/dev/null | grep -q "org/opengis/referencing/NoSuchAuthorityCodeException.class"; then
        echo "✅ NoSuchAuthorityCodeException found in: $jar"
    fi
done

echo ""
echo "📊 SUMMARY STATISTICS:"
echo "====================="
echo "Total JARs: $(ls -1 *.jar | wc -l)"
echo "Sedona JARs: $(ls -1 *sedona*.jar 2>/dev/null | wc -l)"
echo "GeoTools JARs: $(ls -1 gt-*.jar geotools*.jar 2>/dev/null | wc -l)"
echo "GeoAPI JARs: $(ls -1 geoapi*.jar 2>/dev/null | wc -l)"
echo "JTS JARs: $(ls -1 jts*.jar 2>/dev/null | wc -l)"

echo ""
echo "🔍 CHECKING JAR SIZES (largest JARs first):"
echo "==========================================="
ls -la *.jar | sort -k5 -nr | head -10

echo ""
echo "📅 NEWEST JARS (by modification time):"
echo "======================================"
ls -lat *.jar | head -10
'

echo ""
echo -e "${BLUE}🐍 Python Environment Check:${NC}"
docker exec $CONTAINER python3 -c "
import sys
import os

print('🔍 PYTHON ENVIRONMENT:')
print('=' * 25)
print(f'Python version: {sys.version}')
print(f'Python executable: {sys.executable}')
print('')

# Check environment variables
env_vars = ['JAVA_HOME', 'SPARK_HOME', 'PYSPARK_PYTHON', 'PYTHONPATH']
for var in env_vars:
    value = os.environ.get(var, 'Not set')
    print(f'{var}: {value}')

print('')
print('🔍 PYTHON PACKAGES:')
print('=' * 20)
try:
    import pkg_resources
    packages = ['pyspark', 'apache-sedona', 'geopandas', 'shapely']
    for pkg in packages:
        try:
            version = pkg_resources.get_distribution(pkg).version
            print(f'✅ {pkg}: {version}')
        except pkg_resources.DistributionNotFound:
            print(f'❌ {pkg}: Not installed')
except ImportError:
    print('pkg_resources not available')
"

echo ""
echo -e "${GREEN}✅ JAR inventory complete!${NC}"
echo ""
echo -e "${YELLOW}💡 Key things to look for:${NC}"
echo "• Sedona JARs should be present (sedona-spark-shaded, sedona-viz, etc.)"
echo "• GeoTools JARs (gt-referencing, gt-metadata, gt-opengis)"
echo "• FactoryException should be found in one of the JARs"
echo "• No duplicate or conflicting versions"