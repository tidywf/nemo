# Write data

Writes tabular data in the given format.

## Usage

``` r
nemo_write(d, fpfix = NULL, format = "tsv", dbconn = NULL, dbtab = NULL)
```

## Arguments

- d:

  ([`data.frame()`](https://rdrr.io/r/base/data.frame.html))  
  A data.frame (or tibble) with tidy data.

- fpfix:

  (`character(1)`)  
  File prefix. The file extension is generated automatically via the
  `format` argument. For a format of db, this is inserted into the
  `nemo_pfix` column.

- format:

  (`character(1)`)  
  Output format. One of tsv, csv, parquet, rds, or db.

- dbconn:

  (`DBIConnection(1)`)  
  Database connection object (see
  [`DBI::dbConnect`](https://dbi.r-dbi.org/reference/dbConnect.html)).
  Used only when format is db.

- dbtab:

  (`character(1)`)  
  Database table name (see
  [`DBI::dbWriteTable`](https://dbi.r-dbi.org/reference/dbWriteTable.html)).
  Used only when format is db.

## Examples

``` r
d <- tibble::tibble(name = "foo", data = 123)
fpfix <- file.path(tempdir(), "data_test1")
format <- "csv"
nemo_write(d = d, fpfix = fpfix, format = format)
(res <- readr::read_csv(glue::glue("{fpfix}.csv.gz"), show_col_types = FALSE))
#> # A tibble: 1 × 2
#>   name   data
#>   <chr> <dbl>
#> 1 foo     123
if (FALSE) { # RPostgres::postgresHasDefault()
# for database writing
con <- DBI::dbConnect(RPostgres::Postgres())
tbl_nm <- "awesome_tbl"
nemo_write(d = d, fpfix = basename(fpfix), format = "db", dbconn = con, dbtab = tbl_nm)
DBI::dbListTables(con)
DBI::dbReadTable(con, tbl_nm)
DBI::dbDisconnect(con)
}
```
