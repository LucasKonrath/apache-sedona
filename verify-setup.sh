#!/bin/bash

echo "🚀 Apache Sedona Environment Verification"
echo "========================================="

echo ""
echo "📦 Building updated containers with GeoTools wrapper..."
docker-compose build

echo ""
echo "🐳 Starting Apache Sedona services..."
docker-compose up -d

echo ""
echo "⏳ Waiting for services to start..."
sleep 10

echo ""
echo "🧪 Testing Sedona functionality..."
docker exec sedona-pyspark python3 -c "
from pyspark.sql import SparkSession
from sedona.register import SedonaRegistrator
from sedona.utils import SedonaKryoRegistrator, KryoSerializer

# Quick test
spark = (SparkSession.builder
         .appName('Sedona Verification')
         .config('spark.serializer', KryoSerializer.getName)
         .config('spark.kryo.registrator', SedonaKryoRegistrator.getName)
         .getOrCreate())

print('✅ Spark session created')

SedonaRegistrator.registerAll(spark)
print('✅ Sedona registered')

# Test the previously failing function
result = spark.sql('SELECT ST_Distance(ST_Point(0.0, 0.0), ST_Point(3.0, 4.0)) as distance').collect()
distance = result[0]['distance']
print(f'✅ ST_Distance test PASSED! Distance: {distance}')

# Test area calculation
result = spark.sql('SELECT ST_Area(ST_GeomFromWKT(\"POLYGON((0 0, 2 0, 2 2, 0 2, 0 0))\")) as area').collect()
area = result[0]['area']
print(f'✅ ST_Area test PASSED! Area: {area}')

spark.stop()
print('🎉 All tests passed! Apache Sedona is ready to use.')
"

echo ""
echo "📊 Service Status:"
echo "  🌐 Spark Master UI: http://localhost:8080"
echo "  📓 Jupyter Notebook: http://localhost:8888"  
echo "  👨‍💻 PySpark Shell: docker exec -it sedona-pyspark pyspark"

echo ""
echo "✅ Apache Sedona environment is ready!"
echo ""
echo "🎯 Next steps:"
echo "   • Open Jupyter at http://localhost:8888"
echo "   • Use PySpark: docker exec -it sedona-pyspark pyspark"
echo "   • Run spatial queries with ST_Distance, ST_Area, etc."
echo "   • Stop services: docker-compose down"