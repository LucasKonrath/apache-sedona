# Apache Sedona Upgrade to 1.8.0

## Summary
This project has been upgraded from Apache Sedona 1.4.1 to 1.8.0.

## Changes Made

### 1. Dockerfile
- **SEDONA_VERSION**: Updated from `1.4.1` to `1.8.0`
- **GeoTools wrapper**: Updated from `1.4.0-28.2` to `1.6.1-28.2`
- All Sedona JARs will now download version 1.8.0

### 2. Documentation Updates

#### README.md
- Updated version reference from 1.4.1 to 1.8.0

#### README_COMPREHENSIVE.md
- Updated badge from 1.4.1 to 1.8.0
- Updated Core Technologies section from 1.4.1 to 1.8.0
- Updated GeoTools wrapper reference from 1.4.0-28.2 to 1.6.1-28.2
- Updated System Specifications table from 1.4.1 to 1.8.0

### 3. Notebook Updates

#### notebooks/real-sedona-example-dataset.ipynb
- Updated prerequisites section from 1.4.1 to 1.8.0

## Next Steps

### To apply the upgrade:

1. **Rebuild the Docker image:**
   ```bash
   docker-compose down
   docker-compose build --no-cache
   docker-compose up -d
   ```

2. **Verify the installation:**
   ```bash
   ./verify-setup.sh
   ```

3. **Test notebooks:**
   - Access Jupyter at http://localhost:8888
   - Run the notebooks to ensure compatibility

## What's New in Sedona 1.8.0

Apache Sedona 1.8.0 includes:
- Performance improvements for spatial operations
- Enhanced spatial SQL functions
- Bug fixes and stability improvements
- Better integration with newer Spark versions
- Improved GeoTools compatibility

## Compatibility Notes

- **Apache Spark**: 3.4.0 (unchanged)
- **GeoTools wrapper**: Updated to 1.6.1-28.2 for better compatibility
- **Python packages**: apache-sedona will automatically install version 1.8.0
- **Deprecated functions**: The notebooks may still show deprecation warnings for `SedonaRegistrator.registerAll()` - consider using `SedonaContext.create()` instead

## Rollback

If you need to rollback to version 1.4.1:

1. In `Dockerfile`, change:
   - `ENV SEDONA_VERSION=1.8.0` → `ENV SEDONA_VERSION=1.4.1`
   - GeoTools wrapper URL to use `1.4.0-28.2`

2. Rebuild the Docker image as shown above

## References

- [Apache Sedona Documentation](https://sedona.apache.org/)
- [Sedona 1.8.0 Release Notes](https://sedona.apache.org/latest-snapshot/setup/release-notes/)
- [GeoTools Compatibility Matrix](https://repo1.maven.org/maven2/org/datasyslab/geotools-wrapper/)
