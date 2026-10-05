

<!-- README.md is generated from README.qmd. Please edit that file -->

<a href="https://tidywf.github.io/nemo"><img src="man/figures/logo.png" alt="logo" align="left" height="100" /></a>

# Tidy and Explore Bioinformatic Pipeline Outputs

[![conda-latest1](https://anaconda.org/tidywf/r-nemo/badges/latest_release_date.svg "Conda Latest Release")](https://anaconda.org/tidywf/r-nemo)
[![gha](https://github.com/tidywf/nemo/actions/workflows/deploy.yaml/badge.svg "GitHub Actions")](https://github.com/tidywf/nemo/actions/workflows/deploy.yaml)

## Contents

- [nemo](#nemo)
- [Documentation](#documentation)
- [Quickstart](#quickstart)
- [Installation](#installation)
- [CLI](#cli)

## nemo

Schema-driven parsing and tidying of bioinformatic pipeline outputs:

- find files via YAML-defined `schema.yaml` patterns
- parse TSV/CSV/headerless/key-value/crazy files
- rename columns to `snake_case`, track column changes across tool
  versions
- write to Parquet, TSV, CSV, RDS or database of your choice, plus a
  `metadata.parquet` for provenance (IDs, paths, pkg versions) per run

Base R6 classes (`Tool`, `Workflow`, `Config`) are extended by
tool-specific packages such as
[tidywigits](https://github.com/tidywf/tidywigits "tidywigits")
([WiGiTS/hmftools](https://github.com/hartwigmedical/hmftools "hmftools"))
and [tidydragen](https://github.com/tidywf/tidydragen "tidydragen")
([Illumina/DRAGEN](https://help.dragen.illumina.com/ "Illumina DRAGEN")).

## Documentation

- Installation: <https://tidywf.github.io/nemo/articles/installation>
- Files supported: <https://tidywf.github.io/nemo/articles/schema_table>
- Output naming: <https://tidywf.github.io/nemo/articles/output_naming>
- Changelog: <https://tidywf.github.io/nemo/articles/NEWS>
- R6 structure: <https://tidywf.github.io/nemo/articles/structure>
- UML: <https://tidywf.github.io/nemo/articles/uml>
- CI/CD: <https://tidywf.github.io/nemo/articles/cicd>

## Quickstart

Raw key-value file:

``` r
library(nemo)

path <- system.file("extdata/tool1/latest", package = "nemo")
writeLines(readLines(file.path(path, "sampleA.tool1.table3.tsv")))
#> SampleID sampleA
#> QCStatus Pass
#> TotalReads   10000
#> MappedReads  9500
#> UnmappedReads    500
```

Filter, tidy and write all tables with `run()`:

``` r
outdir <- file.path(tempdir(), "quickstart")
wf1 <- Workflow1$new(path = path)
wf1$run(
  output_dir = outdir,
  format = "parquet",
  input_id = "run1",
  output_id = "out1",
  prefix_include = TRUE
)

list.files(outdir, pattern = "\\.parquet$")
#> [1] "metadata.parquet"             "sampleA_tool1_table1.parquet" "sampleA_tool1_table2.parquet"
#> [4] "sampleA_tool1_table3.parquet" "sampleA_tool1_table4.parquet" "sampleA_tool1_table6.parquet"
```

Tidy output:

``` r
arrow::read_parquet(file.path(outdir, "sampleA_tool1_table3.parquet"))
#> # A tibble: 1 × 8
#>   input_id input_prefix output_id sample_id qcstatus reads_total reads_map reads_unmap
#> * <chr>    <chr>        <chr>     <chr>     <chr>          <dbl>     <dbl>       <dbl>
#> 1 run1     sampleA      out1      sampleA   Pass           10000      9500         500
```

Optional provenance columns (recommended for multi-sample/multi-run
use):

| Column | Purpose | User-supplied or auto-generated? |
|----|----|----|
| `input_id` | identifies the sample or input run | user |
| `output_id` | identifies the nemo processing run | user or auto (ULID) |
| `input_prefix` | filename prefix (e.g. sample name) | auto |

## Installation

From GitHub:

``` r
install.packages("remotes")
remotes::install_github("tidywf/nemo") # latest main commit
remotes::install_github("tidywf/nemo@v0.1.0.9007") # specific version
```

Conda: <https://anaconda.org/tidywf/r-nemo>. More options:
<https://tidywf.github.io/nemo/articles/installation>

## CLI

`nemo.R` is on `PATH` in the conda env. Otherwise:

``` bash
nemo_cli=$(Rscript -e 'x = system.file("cli", package = "nemo"); cat(x, "\n")' | xargs)
export PATH="${nemo_cli}:${PATH}"
```

    $ nemo.R --version
    nemo 0.1.0.9007

    #-----------------------------------#
    $ nemo.R --help
    usage: nemo.R [-h] [-v] {tidy,list,sync} ...

    Tidy Bioinformatic Workflows

    positional arguments:
      {tidy,list,sync}  sub-command help
        tidy            Tidy Workflow Outputs
        list            List Parsable Workflow Outputs
        sync            Sync Parsable Workflow Outputs From AWS S3

    options:
      -h, --help        show this help message and exit
      -v, --version     show program's version number and exit

    #-----------------------------------#
    $ nemo.R tidy --help
    usage: nemo.R tidy [-h] -w WORKFLOW -d IN_DIR [-o OUTPUT_DIR] [-f FORMAT]
                       [--input_id INPUT_ID] [--output_id OUTPUT_ID | --ulid]
                       [--dbname DBNAME] [--dbuser DBUSER] [--dbhost DBHOST]
                       [--dbport DBPORT] [--include INCLUDE] [--exclude EXCLUDE]
                       [--prefix_include] [-q]

    options:
      -h, --help            show this help message and exit
      -w, --workflow WORKFLOW
                            Workflow name.
      -d, --in_dir IN_DIR   Input directory.
      -o, --output_dir OUTPUT_DIR
                            Output directory.
      -f, --format FORMAT   Format of output [def: parquet] (parquet, db, tsv,
                            csv, rds)
      --input_id INPUT_ID   Input ID for this run.
      --output_id OUTPUT_ID
                            Output ID for this run.
      --ulid                Generate a ULID as output ID.
      --dbname DBNAME       Database name.
      --dbuser DBUSER       Database user.
      --dbhost DBHOST       Database host (default: driver/env default, e.g.
                            PGHOST).
      --dbport DBPORT       Database port (default: driver/env default, e.g.
                            PGPORT).
      --include INCLUDE     Include only these files (comma sep tool_parsers).
      --exclude EXCLUDE     Exclude only these files (comma sep tool_parsers).
      --prefix_include      Include input prefix column in output tables.
      -q, --quiet           Shush all the logs.

    #-----------------------------------#
    $ nemo.R list --help
    usage: nemo.R list [-h] -w WORKFLOW -d IN_DIR [-f FORMAT] [-m MAX] [-q]

    options:
      -h, --help            show this help message and exit
      -w, --workflow WORKFLOW
                            Workflow name.
      -d, --in_dir IN_DIR   Input directory.
      -f, --format FORMAT   Format of list output [def: pretty] (tsv, pretty)
      -m, --max MAX         Max rows to show.
      -q, --quiet           Shush all the logs.
