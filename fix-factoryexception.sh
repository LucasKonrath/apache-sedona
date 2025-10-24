#!/bin/bash

# Comprehensive GeoAPI FactoryException Fix
# Fixes: java.lang.NoClassDefFoundError: org/opengis/referencing/FactoryException

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔧 Fixing GeoAPI FactoryException Error${NC}"
echo "This will download the complete OpenGIS/GeoAPI package"
echo ""

# Check for running containers
CONTAINERS=$(docker ps --filter "label=com.docker.compose.project=apache-sedona" --format "{{.Names}}")

if [ -z "$CONTAINERS" ]; then
    echo -e "${RED}❌ No running Sedona containers found.${NC}"
    echo -e "${YELLOW}Starting services...${NC}"
    ./sedona.sh start
    sleep 5
    CONTAINERS=$(docker ps --filter "label=com.docker.compose.project=apache-sedona" --format "{{.Names}}")
fi

if [ -z "$CONTAINERS" ]; then
    echo -e "${RED}❌ Could not start services. Please check Docker.${NC}"
    exit 1
fi

echo -e "${GREEN}Found containers: $CONTAINERS${NC}"

# Copy the Python fix script to container and run it
for container in $CONTAINERS; do
    echo -e "${YELLOW}Fixing $container...${NC}"
    
    # Copy the Python script to container
    docker cp ./fix-geoapi.py $container:/tmp/fix-geoapi.py
    
    # Run the fix script inside the container
    docker exec $container python3 /tmp/fix-geoapi.py
    
    echo -e "${GREEN}✅ Fixed $container${NC}"
done

echo ""
echo -e "${GREEN}🎉 GeoAPI FactoryException fix completed!${NC}"
echo ""
echo -e "${BLUE}📋 Next Steps:${NC}"
echo "1. Restart your Jupyter kernel: Kernel → Restart"
echo "2. Re-run your notebook cells"
echo "3. The NoClassDefFoundError should be resolved"
echo ""
echo -e "${BLUE}🧪 Quick Test:${NC}"
echo "Run this in your notebook first cell:"
echo ""
echo -e "${YELLOW}from pyspark.sql import SparkSession"
echo "from sedona.register import SedonaRegistrator"
echo ""
echo "spark = SparkSession.builder.appName('Test').getOrCreate()"
echo "SedonaRegistrator.registerAll(spark)"
echo "result = spark.sql('SELECT ST_Point(1.0, 1.0) as point').collect()"
echo -e "print('✅ Sedona works:', result[0]['point'])${NC}"