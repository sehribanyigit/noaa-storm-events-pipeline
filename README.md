# NOAA Storm Events Pipeline

A one-command pipeline that downloads a year of NOAA Storm Events data, converts it to GeoParquet, and lands it ready for analysis in DuckDB, GeoPandas, or QGIS.

## What it does

`pipeline.sh` takes a year (default: 2025), pulls the raw `details` file from NOAA's public archive, decompresses it, and converts it into a single analysis-ready GeoParquet dataset at `data/processed/storm_events_{YEAR}.parquet`.

> **Note:** This pipeline is configured for the current 2025 NOAA Storm Events archive. NOAA periodically republishes archive files with updated filenames (`CREATED_DATE`). If the archive filename changes, you may need to update the `CREATED_DATE` variable in `pipeline.sh`.

Typical runtime:

- First run: about 1–2 minutes (download + conversion)
- Subsequent runs: a few seconds thanks to the idempotent pipeline design

## The data

- **Source:** [NOAA Storm Events Database](https://www.ncei.noaa.gov/data/storm-events/)
- **License:** Public domain (US federal data)
- **What's in it:** every recorded storm event in the United States for the given year, including type, location, and damages

## How to run it

Requires:

- GDAL (`ogr2ogr`)
- curl
- gunzip
- DuckDB (used for output validation)

```bash
git clone https://github.com/sehribanyigit/noaa-storm-events-pipeline.git
cd noaa-storm-events-pipeline
chmod +x pipeline.sh
./pipeline.sh
```

To process a specific year:

```bash
./pipeline.sh YEAR

# Example
./pipeline.sh 2025
```


## What I learned

- Building an automated pipeline is more than downloading and converting data. I learned that making the workflow idempotent so it can be safely rerun without repeating unnecessary work.

- Validating the GeoParquet output with DuckDB revealed that only about **44K of 72K** records contained coordinates that were successfully converted into point geometries. This reinforced the importance of verifying data quality instead of assuming every record can be converted into a spatial feature.

- NOAA occasionally republishes annual datasets with updated filenames, which can break automated downloads. Keeping configuration values explicit made the pipeline easier to maintain and adapt when the source data changed.

## Stack

- Bash
- Git
- curl
- GDAL / ogr2ogr
- GeoParquet
- DuckDB

## Project structure

```
noaa-storm-events-pipeline/
├── pipeline.sh
├── README.md
├── LICENSE
├── .gitignore
└── data/
    ├── raw/
    └── processed/
```