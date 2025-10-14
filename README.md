# Apache Sedona Docker Environment

This repository provides a complete Docker environment for Apache Sedona, a cluster computing system for processing large-scale spatial data with Apache Spark.

## Features

- **Apache Spark 3.4.0** with Hadoop 3 support
- **Apache Sedona 1.4.1** with all core modules
- **Python/PySpark integration** with spatial libraries
- **Jupyter Notebook** environment for interactive development
- **Multi-service setup** with Docker Compose
- **Example notebooks** and spatial data processing workflows

## Quick Start

### Option 1: Using Docker Compose (Recommended)

```bash
# Start all services (Master, Worker, Jupyter)
docker-compose up -d

# Access Jupyter Notebook
open http://localhost:8888

# Access Spark Master UI
open http://localhost:8080

# Access Spark Worker UI
open http://localhost:8081
```

### Option 2: Using Docker directly

```bash
# Build the image
docker build -t apache-sedona .

# Run different services
docker run -p 8888:8888 apache-sedona jupyter     # Jupyter Notebook
docker run -p 8080:8080 apache-sedona master      # Spark Master
docker run -it apache-sedona pyspark              # Interactive PySpark shell
docker run -it apache-sedona shell                # Spark Scala shell
```

## Available Services

### 1. Jupyter Notebook Environment
- **URL**: http://localhost:8888
- **Features**: Interactive notebooks with Sedona pre-configured
- **Usage**: Perfect for data exploration and analysis

### 2. Spark Master/Worker Cluster
- **Master UI**: http://localhost:8080
- **Worker UI**: http://localhost:8081
- **Features**: Distributed processing capabilities

### 3. Interactive Shells
- **PySpark**: Python shell with Sedona
- **Spark Shell**: Scala shell with Sedona

## Directory Structure

```
apache-sedona/
├── Dockerfile              # Main container definition
├── docker-compose.yml      # Multi-service orchestration
├── .dockerignore           # Docker build optimization
├── notebooks/              # Jupyter notebooks
│   └── sedona-example.ipynb
├── data/                   # Spatial data files
└── README.md              # This file
```

## Example Usage

### 1. Start the Environment
```bash
docker-compose up -d
```

### 2. Open Jupyter Notebook
Navigate to http://localhost:8888 and open `sedona-example.ipynb`

### 3. Run Spatial Queries
```python
from pyspark.sql import SparkSession
from sedona.register import SedonaRegistrator

# Initialize Spark with Sedona
spark = SparkSession.builder.appName("SedonaApp").getOrCreate()
SedonaRegistrator.registerAll(spark)

# Create spatial data
df = spark.sql("""
    SELECT ST_Point(CAST(RAND() * 360 - 180 AS DECIMAL(10,6)), 
                    CAST(RAND() * 180 - 90 AS DECIMAL(10,6))) as geometry
    FROM range(1000)
""")

# Spatial operations
df.createOrReplaceTempView("points")
result = spark.sql("""
    SELECT ST_X(geometry) as lon, ST_Y(geometry) as lat 
    FROM points 
    WHERE ST_Within(geometry, ST_PolygonFromEnvelope(-10, -10, 10, 10))
""")
result.show()
```

## Spatial Data Formats Supported

- **Shapefile** (.shp, .shx, .dbf)
- **GeoJSON** (.geojson, .json)
- **CSV with WKT** (Well-Known Text geometry)
- **Parquet with spatial columns**
- **PostGIS databases** (with additional configuration)

## Development Workflow

### 1. Add Your Data
Place spatial data files in the `data/` directory:
```bash
data/
├── cities.shp
├── countries.geojson
└── points.csv
```

### 2. Create Notebooks
Add your analysis notebooks to the `notebooks/` directory.

### 3. Access from Container
Data and notebooks are automatically mounted and accessible from all services.

## Advanced Configuration

### Custom Spark Configuration
Edit the Spark configuration in the Dockerfile or mount a custom `spark-defaults.conf`:

```bash
docker run -v ./custom-spark.conf:/opt/spark/conf/spark-defaults.conf apache-sedona pyspark
```

### Memory and CPU Limits
Adjust resources in `docker-compose.yml`:
```yaml
services:
  spark-master:
    deploy:
      resources:
        limits:
          memory: 4G
          cpus: '2'
```

## Troubleshooting

### Common Issues

1. **Port conflicts**: Change ports in `docker-compose.yml` if already in use
2. **Memory issues**: Increase Docker memory allocation
3. **Data access**: Ensure data files are in the `data/` directory

### Logs and Debugging
```bash
# View service logs
docker-compose logs spark-master
docker-compose logs jupyter

# Interactive debugging
docker run -it apache-sedona bash
```

## Contributing

1. Fork the repository
2. Create your feature branch
3. Add/modify Dockerfile or configurations
4. Test with sample spatial data
5. Submit a pull request

## Resources

- [Apache Sedona Documentation](https://sedona.apache.org/)
- [Apache Spark Documentation](https://spark.apache.org/docs/latest/)
- [Spatial SQL Reference](https://sedona.apache.org/api/sql/Overview/)
- [Python API Documentation](https://sedona.apache.org/api/python/)

## License

This Docker configuration is provided under the Apache License 2.0, consistent with Apache Sedona's licensing.
