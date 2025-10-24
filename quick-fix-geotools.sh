#!/bin/bash

# Quick GeoTools Fix Script - Downloads JARs to running container
# This avoids rebuilding the entire Docker image

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 Quick GeoTools Fix for Running Container${NC}"

# Find running Sedona containers
CONTAINERS=$(docker ps --filter "label=com.docker.compose.project=apache-sedona" --format "{{.Names}}")

if [ -z "$CONTAINERS" ]; then
    echo -e "${RED}❌ No running Sedona containers found.${NC}"
    echo -e "${YELLOW}Start the services first: ./sedona.sh start${NC}"
    exit 1
fi

echo -e "${GREEN}Found containers: $CONTAINERS${NC}"

# Function to fix container
fix_container() {
    local container=$1
    echo -e "${YELLOW}Fixing container: $container${NC}"
    
    # Download essential JARs directly to the container
    docker exec $container bash -c "
        echo 'Downloading GeoTools JARs...'
        cd /opt/spark/jars/
        
        # Download JTS Core (essential for spatial operations)
        wget -q https://repo1.maven.org/maven2/org/locationtech/jts/jts-core/1.19.0/jts-core-1.19.0.jar || echo 'JTS download failed'
        
        # Download complete GeoAPI package (contains ALL OpenGIS interfaces including FactoryException)
        wget -q https://repo1.maven.org/maven2/org/opengis/geoapi/3.0.2/geoapi-3.0.2.jar || echo 'GeoAPI 3.0.2 download failed'
        
        # Download GeoAPI pending (contains additional interfaces)
        wget -q https://repo1.maven.org/maven2/org/opengis/geoapi-pending/3.0.2/geoapi-pending-3.0.2.jar || echo 'GeoAPI pending download failed'
        
        # Download Unit API (required by GeoAPI)
        wget -q https://repo1.maven.org/maven2/javax/measure/unit-api/2.1.3/unit-api-2.1.3.jar || echo 'Unit API download failed'
        
        # Download Systems Common (Unit system implementation)  
        wget -q https://repo1.maven.org/maven2/systems/uom/systems-common/2.1/systems-common-2.1.jar || echo 'Systems common download failed'
        
        echo 'Listing downloaded JARs:'
        ls -la *.jar | grep -E '(jts|geoapi|opengis)' || echo 'No spatial JARs found'
        
        echo 'Fix completed for container'
    "
}

# Fix all running containers
for container in $CONTAINERS; do
    fix_container $container
done

echo ""
echo -e "${GREEN}✅ Quick fix applied to all containers!${NC}"
echo -e "${BLUE}📝 Next steps:${NC}"
echo "1. Restart your Jupyter kernel (Kernel -> Restart)"  
echo "2. Re-run your notebook cells"
echo "3. If issues persist, try: docker-compose restart"

echo ""
echo -e "${YELLOW}🧪 Test the fix:${NC}"
echo "docker exec \$(docker ps -q --filter 'label=com.docker.compose.project=apache-sedona' | head -1) python3 -c \"
from pyspark.sql import SparkSession
from sedona.register import SedonaRegistrator
spark = SparkSession.builder.appName('Test').getOrCreate()
SedonaRegistrator.registerAll(spark)
print('✅ Sedona works!')
spark.stop()
\""