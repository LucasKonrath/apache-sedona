#!/bin/bash

# Apache Sedona GeoTools Troubleshooting Script
# This script helps diagnose and fix NoClassDefFoundError issues

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 Apache Sedona GeoTools Diagnostic Tool${NC}"
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker is not running. Please start Docker first.${NC}"
    exit 1
fi

# Function to check JARs in container
check_jars_in_container() {
    echo -e "${YELLOW}Checking GeoTools JARs in running container...${NC}"
    
    # Try to find a running Sedona container
    CONTAINER_ID=$(docker ps --filter "label=com.docker.compose.project=apache-sedona" --format "{{.ID}}" | head -1)
    
    if [ -z "$CONTAINER_ID" ]; then
        echo -e "${YELLOW}No running containers found. Starting temporary container...${NC}"
        docker run --rm apache-sedona_pyspark ls -la /opt/spark/jars/ | grep -E "(geotools|gt-|opengis)" || echo "No GeoTools JARs found"
    else
        echo -e "${GREEN}Found running container: $CONTAINER_ID${NC}"
        docker exec $CONTAINER_ID ls -la /opt/spark/jars/ | grep -E "(geotools|gt-|opengis)" || echo "No GeoTools JARs found"
    fi
}

# Function to download missing JARs manually
download_missing_jars() {
    echo -e "${YELLOW}Downloading missing GeoTools JARs...${NC}"
    
    # Create temporary directory
    mkdir -p ./temp_jars
    
    # Download essential GeoTools JARs
    GEOTOOLS_VERSION="28.2"
    JARS=(
        "https://repo1.maven.org/maven2/org/geotools/gt-opengis/${GEOTOOLS_VERSION}/gt-opengis-${GEOTOOLS_VERSION}.jar"
        "https://repo1.maven.org/maven2/org/geotools/gt-referencing/${GEOTOOLS_VERSION}/gt-referencing-${GEOTOOLS_VERSION}.jar"
        "https://repo1.maven.org/maven2/org/geotools/gt-metadata/${GEOTOOLS_VERSION}/gt-metadata-${GEOTOOLS_VERSION}.jar"
        "https://repo1.maven.org/maven2/org/geotools/gt-main/${GEOTOOLS_VERSION}/gt-main-${GEOTOOLS_VERSION}.jar"
        "https://repo1.maven.org/maven2/org/geotools/gt-epsg-hsql/${GEOTOOLS_VERSION}/gt-epsg-hsql-${GEOTOOLS_VERSION}.jar"
        "https://repo1.maven.org/maven2/org/hsqldb/hsqldb/2.7.1/hsqldb-2.7.1.jar"
        "https://repo1.maven.org/maven2/javax/measure/unit-api/2.1.3/unit-api-2.1.3.jar"
        "https://repo1.maven.org/maven2/systems/uom/systems-common/2.1/systems-common-2.1.jar"
    )
    
    for jar_url in "${JARS[@]}"; do
        jar_name=$(basename "$jar_url")
        echo -e "Downloading ${jar_name}..."
        wget -q -O "./temp_jars/$jar_name" "$jar_url" || echo "Failed to download $jar_name"
    done
    
    echo -e "${GREEN}✅ JARs downloaded to ./temp_jars/${NC}"
    echo -e "${BLUE}💡 You can copy these to your Spark container manually if needed${NC}"
}

# Function to fix via container volume mount
fix_via_volume_mount() {
    echo -e "${YELLOW}Setting up volume mount for JARs...${NC}"
    
    if [ ! -d "./temp_jars" ]; then
        download_missing_jars
    fi
    
    # Update docker-compose with volume mount
    cat >> docker-compose.override.yml << EOF
version: '3.8'
services:
  jupyter:
    volumes:
      - ./temp_jars:/opt/spark/extra-jars
    environment:
      - SPARK_CLASSPATH=/opt/spark/extra-jars/*
  
  pyspark:
    volumes:
      - ./temp_jars:/opt/spark/extra-jars
    environment:
      - SPARK_CLASSPATH=/opt/spark/extra-jars/*
EOF
    
    echo -e "${GREEN}✅ Created docker-compose.override.yml${NC}"
    echo -e "${BLUE}Restart services with: docker-compose down && docker-compose up -d${NC}"
}

# Main menu
echo "Choose an option:"
echo "1) Check JARs in running container"
echo "2) Download missing JARs manually"
echo "3) Fix via volume mount (quick fix)"
echo "4) Rebuild image completely"
echo "5) Test Sedona in container"
echo "6) Exit"

read -p "Enter your choice (1-6): " choice

case $choice in
    1)
        check_jars_in_container
        ;;
    2)
        download_missing_jars
        ;;
    3)
        fix_via_volume_mount
        ;;
    4)
        echo -e "${YELLOW}Rebuilding Docker image with fixed GeoTools...${NC}"
        docker-compose down
        docker-compose build --no-cache
        docker-compose up -d
        echo -e "${GREEN}✅ Image rebuilt and services restarted${NC}"
        ;;
    5)
        echo -e "${YELLOW}Testing Sedona in container...${NC}"
        docker run --rm apache-sedona_pyspark python3 -c "
from pyspark.sql import SparkSession
from sedona.register import SedonaRegistrator

try:
    spark = SparkSession.builder.appName('Test').getOrCreate()
    SedonaRegistrator.registerAll(spark)
    result = spark.sql('SELECT ST_Point(1.0, 1.0) as point').collect()
    print('✅ Sedona is working correctly!')
    spark.stop()
except Exception as e:
    print(f'❌ Error: {e}')
"
        ;;
    6)
        echo -e "${BLUE}Goodbye!${NC}"
        exit 0
        ;;
    *)
        echo -e "${RED}Invalid option${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${BLUE}🎯 Troubleshooting Tips:${NC}"
echo "• If issues persist, try option 4 (rebuild image)"
echo "• Check logs with: docker-compose logs jupyter"
echo "• Verify Java version compatibility"
echo "• Make sure you're using the latest Dockerfile"