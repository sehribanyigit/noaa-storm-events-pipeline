#!/usr/bin/env bash
#
# pipeline.sh — Download a year of NOAA Storm Events, convert to GeoParquet.
#
# Usage:   ./pipeline.sh [YEAR]
# Example: ./pipeline.sh 2025
#
# Requires: bash, curl, gunzip, ogr2ogr (GDAL >= 3.5)



set -euo pipefail

# -----------------------------------------------------------------------------
# Config
# -----------------------------------------------------------------------------

# Year to pull. Override by passing as the first argument.
YEAR="${1:-2025}"

# NOAA file naming pattern. The "c{CREATED_DATE}" portion changes when NOAA
# republishes a year. Look at https://www.ncei.noaa.gov/data/storm-events/files/
# and update CREATED_DATE for the year you want.
CREATED_DATE="20260728"

BASE_URL="https://www.ncei.noaa.gov/pub/data/swdi/stormevents/csvfiles"
FILE_NAME="StormEvents_details-ftp_v1.0_d${YEAR}_c${CREATED_DATE}.csv.gz"
URL="${BASE_URL}/${FILE_NAME}"

RAW_DIR="data/raw"
PROCESSED_DIR="data/processed"
RAW_GZ="${RAW_DIR}/${FILE_NAME}"
RAW_CSV="${RAW_DIR}/${FILE_NAME%.gz}"
OUT_PARQUET="${PROCESSED_DIR}/storm_events_${YEAR}.parquet"
# -----------------------------------------------------------------------------
# Step 1: Set up directories
# -----------------------------------------------------------------------------

echo "[1/4] Setting up directories"

# Create the required project directories.
mkdir -p "$RAW_DIR" "$PROCESSED_DIR"

echo "✓ Directories are ready."
echo

# -----------------------------------------------------------------------------
# Step 2: Download the raw file
# -----------------------------------------------------------------------------

echo "[2/4] Downloading ${FILE_NAME}"

# Download the NOAA archive only if it does not already exist.
# This keeps the pipeline idempotent and avoids unnecessary downloads.
if [[ ! -f "$RAW_GZ" ]]; then
    curl -L --fail -o "$RAW_GZ" "$URL"
    echo "✓ Download completed."
else
    echo "✓ Raw archive already exists. Skipping download."
fi

echo

# -----------------------------------------------------------------------------
# Step 3: Decompress
# -----------------------------------------------------------------------------

echo "[3/4] Decompressing"

# Decompress the CSV only if it does not already exist.
# Keep the original .gz file so the pipeline can be rerun.
if [[ ! -f "$RAW_CSV" ]]; then
    gunzip -k "$RAW_GZ"
    echo "✓ Decompression completed."
else
    echo "✓ CSV already exists. Skipping decompression."
fi

echo

# -----------------------------------------------------------------------------
# Step 4: Convert CSV to GeoParquet
# -----------------------------------------------------------------------------

echo "[4/4] Converting to GeoParquet"

# Convert the CSV into a spatial GeoParquet dataset.
# The CSV stores longitude and latitude as separate columns.
# ogr2ogr creates Point geometries and writes them to a GeoParquet file.
if [[ ! -f "$OUT_PARQUET" ]]; then
    ogr2ogr \
        -f Parquet "$OUT_PARQUET" \
        "$RAW_CSV" \
        -oo X_POSSIBLE_NAMES=BEGIN_LON \
        -oo Y_POSSIBLE_NAMES=BEGIN_LAT \
        -a_srs EPSG:4326

    echo "✓ GeoParquet created successfully."
else
    echo "✓ GeoParquet already exists. Skipping conversion."
fi

# ---------------------------------------------------------------------------
# Step 5: Validate the GeoParquet output
# ---------------------------------------------------------------------------

echo
echo "[5/5] Validating GeoParquet output"

# Make sure DuckDB is installed before running validation queries.
if ! command -v duckdb >/dev/null 2>&1; then
    echo "Error: DuckDB is not installed or not available in PATH."
    exit 1
fi

# Query the output dataset and return:
#   - total number of records
#   - number of records containing a valid geometry
VALIDATION_RESULT=$(duckdb -csv -noheader -c "
INSTALL spatial;
LOAD spatial;

SELECT
    COUNT(*) AS total_rows,
    COUNT(geometry) AS geometry_rows
FROM read_parquet('${OUT_PARQUET}');
")

# Split the CSV output into two Bash variables.
IFS=',' read -r TOTAL_ROWS GEOMETRY_ROWS <<< "$VALIDATION_RESULT"

# Ensure the output dataset is not empty.
if [[ "$TOTAL_ROWS" -eq 0 ]]; then
    echo "Error: GeoParquet contains no records."
    exit 1
fi

# Ensure geometries were successfully created.
if [[ "$GEOMETRY_ROWS" -eq 0 ]]; then
    echo "Error: No valid geometries were found."
    exit 1
fi

echo "✓ GeoParquet validation completed."
echo "  Total records         : ${TOTAL_ROWS}"
echo "  Records with geometry : ${GEOMETRY_ROWS}"

# ---------------------------------------------------------------------------
# Pipeline summary
# ---------------------------------------------------------------------------

echo
echo "✓ Pipeline completed and validated successfully."
echo "Output file : ${OUT_PARQUET}"
echo "File size   : $(du -h "${OUT_PARQUET}" | cut -f1)"