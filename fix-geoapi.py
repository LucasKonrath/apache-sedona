#!/usr/bin/env python3
"""
Direct fix for NoClassDefFoundError: org/opengis/referencing/FactoryException
This script runs inside the container to diagnose and fix the issue.
"""

import os
import sys
import subprocess
import urllib.request
from pathlib import Path

def download_jar(url, filename):
    """Download a JAR file if it doesn't exist"""
    spark_jars = Path("/opt/spark/jars")
    jar_path = spark_jars / filename
    
    if jar_path.exists():
        print(f"✅ {filename} already exists")
        return True
    
    try:
        print(f"⬇️  Downloading {filename}...")
        urllib.request.urlretrieve(url, jar_path)
        print(f"✅ Downloaded {filename}")
        return True
    except Exception as e:
        print(f"❌ Failed to download {filename}: {e}")
        return False

def fix_geoapi_dependencies():
    """Download all required GeoAPI dependencies"""
    
    # Essential JARs to fix FactoryException and related issues
    required_jars = [
        {
            'url': 'https://repo1.maven.org/maven2/org/opengis/geoapi/3.0.2/geoapi-3.0.2.jar',
            'filename': 'geoapi-3.0.2.jar'
        },
        {
            'url': 'https://repo1.maven.org/maven2/org/opengis/geoapi-pending/3.0.2/geoapi-pending-3.0.2.jar', 
            'filename': 'geoapi-pending-3.0.2.jar'
        },
        {
            'url': 'https://repo1.maven.org/maven2/org/locationtech/jts/jts-core/1.19.0/jts-core-1.19.0.jar',
            'filename': 'jts-core-1.19.0.jar'
        },
        {
            'url': 'https://repo1.maven.org/maven2/javax/measure/unit-api/2.1.3/unit-api-2.1.3.jar',
            'filename': 'unit-api-2.1.3.jar'
        },
        {
            'url': 'https://repo1.maven.org/maven2/systems/uom/systems-common/2.1/systems-common-2.1.jar',
            'filename': 'systems-common-2.1.jar'
        }
    ]
    
    print("🔧 Fixing GeoAPI dependencies for Apache Sedona...")
    
    success_count = 0
    for jar_info in required_jars:
        if download_jar(jar_info['url'], jar_info['filename']):
            success_count += 1
    
    print(f"\n📊 Downloaded {success_count}/{len(required_jars)} JAR files")
    
    # List all spatial-related JARs
    spark_jars = Path("/opt/spark/jars")
    spatial_jars = []
    
    for jar_file in spark_jars.glob("*.jar"):
        jar_name = jar_file.name.lower()
        if any(keyword in jar_name for keyword in ['sedona', 'geoapi', 'jts', 'geotools', 'opengis', 'spatial']):
            spatial_jars.append(jar_file.name)
    
    print(f"\n📦 Found {len(spatial_jars)} spatial-related JARs:")
    for jar in sorted(spatial_jars):
        print(f"  - {jar}")

def test_sedona():
    """Test if Sedona works after fixing dependencies"""
    print("\n🧪 Testing Sedona functionality...")
    
    try:
        from pyspark.sql import SparkSession
        from sedona.register import SedonaRegistrator
        
        # Create minimal Spark session
        spark = SparkSession.builder \
            .appName("GeoAPITest") \
            .config("spark.serializer", "org.apache.spark.serializer.KryoSerializer") \
            .config("spark.kryo.registrator", "org.apache.sedona.core.serde.SedonaKryoRegistrator") \
            .getOrCreate()
        
        # Register Sedona
        SedonaRegistrator.registerAll(spark)
        
        # Test basic spatial operation
        result = spark.sql("SELECT ST_Point(1.0, 1.0) as point").collect()
        
        print(f"✅ Success! Created point: {result[0]['point']}")
        
        # Test more complex operation that uses referencing
        result2 = spark.sql("SELECT ST_Distance(ST_Point(0.0, 0.0), ST_Point(1.0, 1.0)) as distance").collect()
        print(f"✅ Distance calculation works: {result2[0]['distance']}")
        
        spark.stop()
        return True
        
    except Exception as e:
        print(f"❌ Test failed: {e}")
        return False

def main():
    print("🚀 Apache Sedona GeoAPI Fix Tool")
    print("=" * 50)
    
    # Check if we're in the right environment
    if not os.path.exists("/opt/spark/jars"):
        print("❌ Not running in Spark container. This script should run inside the container.")
        sys.exit(1)
    
    # Fix dependencies
    fix_geoapi_dependencies()
    
    # Test Sedona
    if test_sedona():
        print("\n🎉 Apache Sedona is now working correctly!")
        print("💡 You can now use Sedona in your notebooks without NoClassDefFoundError")
    else:
        print("\n😞 Sedona test failed. You may need to:")
        print("1. Restart the Spark context in your notebook")
        print("2. Try running this script again")
        print("3. Check if all JAR files downloaded successfully")

if __name__ == "__main__":
    main()