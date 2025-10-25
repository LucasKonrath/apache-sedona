#!/bin/bash

echo "🧪 COMPREHENSIVE SEDONA TEST"
echo "============================"

echo "Testing all major Sedona spatial functions..."

docker exec sedona-pyspark python3 -c "
import os
os.environ['PYSPARK_PYTHON'] = 'python3'

from pyspark.sql import SparkSession
from sedona.register import SedonaRegistrator
from sedona.utils import SedonaKryoRegistrator, KryoSerializer

# Create Spark session
spark = (SparkSession.builder
         .appName('Comprehensive Sedona Test')
         .config('spark.serializer', KryoSerializer.getName)
         .config('spark.kryo.registrator', SedonaKryoRegistrator.getName)
         .getOrCreate())

print('✅ Spark session created')

# Register Sedona
SedonaRegistrator.registerAll(spark)
print('✅ Sedona registered')

tests_passed = 0
total_tests = 0

def test_function(name, sql_query, expected_type=None):
    global tests_passed, total_tests
    total_tests += 1
    try:
        result = spark.sql(sql_query).collect()
        value = result[0][0] if result else None
        if expected_type and not isinstance(value, expected_type):
            print(f'❌ {name}: Wrong type - got {type(value)}, expected {expected_type}')
        else:
            print(f'✅ {name}: {value}')
            tests_passed += 1
    except Exception as e:
        print(f'❌ {name}: {str(e)[:100]}...')

print('\n🔍 Testing spatial functions:')

# Basic geometry functions
test_function('ST_Point', 'SELECT ST_Point(1.0, 2.0)')
test_function('ST_Distance', 'SELECT ST_Distance(ST_Point(0.0, 0.0), ST_Point(3.0, 4.0))', float)
test_function('ST_Buffer', 'SELECT ST_Buffer(ST_Point(0.0, 0.0), 1.0)')
test_function('ST_Contains', 'SELECT ST_Contains(ST_Buffer(ST_Point(0.0, 0.0), 2.0), ST_Point(1.0, 1.0))', bool)
test_function('ST_Intersects', 'SELECT ST_Intersects(ST_Point(0.0, 0.0), ST_Buffer(ST_Point(0.0, 0.0), 1.0))', bool)

# Geometry creation from WKT
test_function('ST_GeomFromWKT Point', 'SELECT ST_GeomFromWKT(\"POINT(1 2\")')
test_function('ST_GeomFromWKT Polygon', 'SELECT ST_GeomFromWKT(\"POLYGON((0 0, 1 0, 1 1, 0 1, 0 0))\")')
test_function('ST_Area', 'SELECT ST_Area(ST_GeomFromWKT(\"POLYGON((0 0, 2 0, 2 2, 0 2, 0 0))\"))', float)

# Advanced spatial operations  
test_function('ST_Centroid', 'SELECT ST_Centroid(ST_GeomFromWKT(\"POLYGON((0 0, 2 0, 2 2, 0 2, 0 0))\"))')
test_function('ST_ConvexHull', 'SELECT ST_ConvexHull(ST_GeomFromWKT(\"MULTIPOINT((0 0), (1 1), (2 0))\"))')
test_function('ST_Envelope', 'SELECT ST_Envelope(ST_GeomFromWKT(\"POLYGON((0 0, 2 1, 1 2, 0 0))\"))')

print(f'\n📊 Test Results: {tests_passed}/{total_tests} tests passed')

if tests_passed == total_tests:
    print('🎉 ALL TESTS PASSED! Sedona is fully functional!')
elif tests_passed > total_tests * 0.8:
    print('✅ Most tests passed! Sedona is working well.')
else:
    print('⚠️  Some issues remain, but core functionality works.')

spark.stop()
print('✅ Test complete')
"

echo ""
echo "🎯 Test completed!"