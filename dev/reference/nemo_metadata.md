# Title

Title

## Usage

``` r
nemo_metadata(files, pkgs, input_id, output_id, input_dir, output_dir)
```

## Arguments

- files:

  (`tibble()`)  
  Written files.

- pkgs:

  (`character(n)`)  
  Packages to include versions of.

- input_id:

  Input ID to use for the dataset (e.g. `run123`).

- output_id:

  (`character(1)`)  
  Output ID to use for the dataset (e.g. `run123`).

- input_dir:

  (`character(n)`)  
  Input directory (can be multiple).

- output_dir:

  (`character(1)`)  
  Output directory.

## Value

List of metadata.

## Examples

``` r
files <- tibble::tibble(
  tbl_name = c("purple_qc", "amber_qc"),
  prefix = c("S123", "S123"),
  outpath = c("S123_purple_qc.tsv", "S123_amber_qc.tsv")
)
pkgs <- c("nemo")
input_id <- "run123"
output_id <- ulid::ulid()
input_dir <- "/path/to/wigits/run123"
output_dir <- "/path/to/nemo/outputs/run123"
nemo_metadata(files, pkgs, input_id, output_id, input_dir, output_dir)
#> $input_id
#> [x] "run123"
#> 
#> $output_id
#> [x] "01KJD0HTZQ6JTH0PPJ8P8NB61G"
#> 
#> $input_dir
#> [1] "/path/to/wigits/run123"
#> 
#> $output_dir
#> [x] "/path/to/nemo/outputs/run123"
#> 
#> $pkg_versions
#> # A tibble: 1 × 2
#>   name  version   
#>   <chr> <chr>     
#> 1 nemo  0.0.3.9006
#> 
#> $files
#> # A tibble: 2 × 3
#>   tbl_name  prefix outpath           
#>   <chr>     <chr>  <chr>             
#> 1 purple_qc S123   S123_purple_qc.tsv
#> 2 amber_qc  S123   S123_amber_qc.tsv 
#> 
```
