# Apache Sedona Dockerfile
# This Dockerfile creates a container with Apache Spark and Apache Sedona for spatial data processing

FROM openjdk:11-jre-slim

# Set environment variables
ENV SPARK_VERSION=3.4.0
ENV HADOOP_VERSION=3
ENV SEDONA_VERSION=1.4.1
ENV SPARK_HOME=/opt/spark
ENV JAVA_HOME=/usr/local/openjdk-11
ENV PATH=$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin

# Install system dependencies
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    procps \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Download and install Apache Spark
RUN wget -q https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz \
    && tar -xzf spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz \
    && mv spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION} $SPARK_HOME \
    && rm spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz

# Download Apache Sedona JARs
RUN wget -q -P $SPARK_HOME/jars/ \
    https://repo1.maven.org/maven2/org/apache/sedona/sedona-spark-shaded-3.0_2.12/${SEDONA_VERSION}/sedona-spark-shaded-3.0_2.12-${SEDONA_VERSION}.jar \
    && wget -q -P $SPARK_HOME/jars/ \
    https://repo1.maven.org/maven2/org/apache/sedona/sedona-viz-3.0_2.12/${SEDONA_VERSION}/sedona-viz-3.0_2.12-${SEDONA_VERSION}.jar \
    && wget -q -P $SPARK_HOME/jars/ \
    https://repo1.maven.org/maven2/org/apache/sedona/sedona-python-adapter-3.0_2.12/${SEDONA_VERSION}/sedona-python-adapter-3.0_2.12-${SEDONA_VERSION}.jar

# Download GeoTools dependencies to fix NoClassDefFoundError for OpenGIS classes
RUN wget -q -P $SPARK_HOME/jars/ \
    https://repo1.maven.org/maven2/org/geotools/gt-referencing/29.2/gt-referencing-29.2.jar \
    && wget -q -P $SPARK_HOME/jars/ \
    https://repo1.maven.org/maven2/org/geotools/gt-epsg-hsql/29.2/gt-epsg-hsql-29.2.jar \
    && wget -q -P $SPARK_HOME/jars/ \
    https://repo1.maven.org/maven2/org/geotools/gt-main/29.2/gt-main-29.2.jar \
    && wget -q -P $SPARK_HOME/jars/ \
    https://repo1.maven.org/maven2/org/geotools/gt-metadata/29.2/gt-metadata-29.2.jar \
    && wget -q -P $SPARK_HOME/jars/ \
    https://repo1.maven.org/maven2/org/geotools/gt-opengis/29.2/gt-opengis-29.2.jar \
    && wget -q -P $SPARK_HOME/jars/ \
    https://repo1.maven.org/maven2/org/hsqldb/hsqldb/2.7.1/hsqldb-2.7.1.jar \
    && wget -q -P $SPARK_HOME/jars/ \
    https://repo1.maven.org/maven2/javax/media/jai_core/1.1.3/jai_core-1.1.3.jar

# Install GeoSpark/Sedona Python dependencies
RUN pip3 install --no-cache-dir \
    apache-sedona==${SEDONA_VERSION} \
    pyspark==${SPARK_VERSION} \
    geopandas \
    folium \
    matplotlib \
    jupyter \
    notebook

# Create working directory
WORKDIR /workspace

# Copy any local files (if they exist)
COPY . /workspace/

# Create example Sedona configuration
RUN echo 'spark.serializer org.apache.spark.serializer.KryoSerializer' > $SPARK_HOME/conf/spark-defaults.conf \
    && echo 'spark.kryo.registrator org.apache.sedona.core.serde.SedonaKryoRegistrator' >> $SPARK_HOME/conf/spark-defaults.conf \
    && echo 'spark.sql.extensions org.apache.sedona.viz.sql.SedonaVizExtensions,org.apache.sedona.sql.SedonaSqlExtensions' >> $SPARK_HOME/conf/spark-defaults.conf

# Expose Spark UI port
EXPOSE 4040 8080 8081 7077

# Create entrypoint script
RUN echo '#!/bin/bash\n\
# Start Spark services based on arguments\n\
case "$1" in\n\
  "master")\n\
    echo "Starting Spark Master..."\n\
    $SPARK_HOME/sbin/start-master.sh\n\
    tail -f $SPARK_HOME/logs/spark--org.apache.spark.deploy.master.Master*.out\n\
    ;;\n\
  "worker")\n\
    echo "Starting Spark Worker..."\n\
    $SPARK_HOME/sbin/start-worker.sh ${2:-spark://master:7077}\n\
    tail -f $SPARK_HOME/logs/spark--org.apache.spark.deploy.worker.Worker*.out\n\
    ;;\n\
  "shell")\n\
    echo "Starting Spark Shell with Sedona..."\n\
    $SPARK_HOME/bin/spark-shell\n\
    ;;\n\
  "pyspark")\n\
    echo "Starting PySpark with Sedona..."\n\
    $SPARK_HOME/bin/pyspark\n\
    ;;\n\
  "jupyter")\n\
    echo "Starting Jupyter Notebook..."\n\
    jupyter notebook --ip=0.0.0.0 --port=8888 --no-browser --allow-root --NotebookApp.token='"'"''"'"'\n\
    ;;\n\
  "submit")\n\
    echo "Submitting Spark application..."\n\
    shift\n\
    $SPARK_HOME/bin/spark-submit "$@"\n\
    ;;\n\
  *)\n\
    echo "Usage: $0 {master|worker [master-url]|shell|pyspark|jupyter|submit [spark-submit-args]}"\n\
    echo "Examples:"\n\
    echo "  docker run -it sedona master"\n\
    echo "  docker run -it sedona worker spark://master:7077"\n\
    echo "  docker run -it sedona pyspark"\n\
    echo "  docker run -p 8888:8888 sedona jupyter"\n\
    exit 1\n\
    ;;\n\
esac' > /entrypoint.sh \
    && chmod +x /entrypoint.sh

# Set the entrypoint
ENTRYPOINT ["/entrypoint.sh"]

# Default command
CMD ["pyspark"]