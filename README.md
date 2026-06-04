

<!-- README.md is generated from README.qmd. Please edit that file -->

<a href="https://tidywf.github.io/nemo"><img src="man/figures/logo.png" alt="logo" align="left" height="100" /></a>

# 🐢 Tidy and Explore Bioinformatic Pipeline Outputs

[![conda-latest1](https://anaconda.org/tidywf/r-nemo/badges/latest_release_date.svg "Conda Latest Release")](https://anaconda.org/tidywf/r-nemo)
[![gha](https://github.com/tidywf/nemo/actions/workflows/deploy.yaml/badge.svg "GitHub Actions")](https://github.com/tidywf/nemo/actions/workflows/deploy.yaml)

📚 Docs:
[Installation](https://tidywf.github.io/nemo/articles/installation) \|
[Files/tables
supported](https://tidywf.github.io/nemo/articles/schema_table) \|
[Schema
walkthrough](https://tidywf.github.io/nemo/articles/schema_walkthrough)
\| [Changelog](https://tidywf.github.io/nemo/articles/NEWS) \| [R6
structure](https://tidywf.github.io/nemo/articles/structure) \|
[UML](https://tidywf.github.io/nemo/articles/uml) \|
[CI/CD](https://tidywf.github.io/nemo/articles/cicd)

## 🤔 The Problem

Bioinformatic pipelines produce a lot of output files, but consuming
them downstream is harder than it should be:

- **Format variety**: tools write TSV, CSV and various other proprietary
  formats, often mixed within the same pipeline
- **Non-standard structure**: files may be transposed, headerless, or
  embed section labels alongside data, requiring custom parsing logic
  for each tool
- **Messy column names**: raw names are frequently uppercase,
  space-separated, dot-delimited, or otherwise non-standard; joining
  across tools requires manual renaming
- **Schema drift**: column names and file layouts change silently
  between tool versions, breaking downstream code with no clear signal
  of what changed
- **No run-level provenance**: it is hard to tell which output file came
  from which sample or processing run once files are collected into a
  shared directory

{nemo} addresses this by providing a schema-driven parsing and tidying
layer that turns raw pipeline outputs into consistently structured,
versioned, analysis-ready tables. Its R6 classes (`Tool`, `Workflow`,
`Config`) are used for parsing, tidying, and writing bioinformatic
pipeline outputs. Given a directory of results, it identifies files by
YAML-defined schemas, reshapes and renames columns to a consistent tidy
form, and writes to Apache Parquet, TSV, CSV, RDS, or PostgreSQL. Each
run also produces a `metadata.parquet` file alongside the tidy tables,
capturing IDs, paths, and package versions.

Tool-specific schemas and parsers live in child packages —
{[tidywigits](https://github.com/tidywf/tidywigits "tidywigits")} for
the WiGiTS suite and
{[tidydragen](https://github.com/tidywf/tidydragen "tidydragen")} (WIP)
for Illumina DRAGEN — under `inst/config/tools/` in each respective
package.

Three optional columns can be prepended to every written table to
support downstream tracing and joining. All are opt-in and off by
default, but highly recommended for any multi-sample or multi-run
pipeline:

| Column | R argument | CLI flag | Purpose |
|----|----|----|----|
| `input_id` | `input_id = "run1"` | `--input_id run1` | identifies the sample or input run |
| `output_id` | `output_id = "abc"` | `--output_id abc` / `--ulid` | identifies the processing run |
| `input_pfix` | `pfix_include = TRUE` | `--prefix_include` | filename prefix (e.g. sample name) |

## ⚡ Quickstart

Raw pipeline outputs often have non-standard layouts. This file stores
QC metrics as key-value rows rather than columns:

``` r
library(nemo)

path <- system.file("extdata/tool1/latest", package = "nemo")
writeLines(readLines(file.path(path, "sampleA.tool1.table3.tsv")))
SampleID    sampleA
QCStatus    Pass
TotalReads  10000
MappedReads 9500
UnmappedReads   500
```

`nemofy()` parses, tidies, and writes all tables in one call:

``` r
outdir <- file.path(tempdir(), "quickstart")

Workflow1$new(path = path)$nemofy(
  diro         = outdir,
  format       = "parquet",
  input_id     = "run1",
  output_id    = "out1",
  pfix_include = TRUE
)

list.files(outdir, pattern = "\\.parquet$")
[1] "metadata.parquet"             "sampleA_tool1_table1.parquet" "sampleA_tool1_table2.parquet"
[4] "sampleA_tool1_table3.parquet" "sampleA_tool1_table4.parquet" "sampleA_tool1_table5.parquet"
[7] "sampleA_tool1_table6.parquet"
```

Read back the tidied table:

``` r
arrow::read_parquet(file.path(outdir, "sampleA_tool1_table3.parquet"))
# A tibble: 1 × 8
  input_id input_pfix output_id sample_id qcstatus reads_total reads_map reads_unmap
* <chr>    <chr>      <chr>     <chr>     <chr>          <dbl>     <dbl>       <dbl>
1 run1     sampleA    out1      sampleA   Pass           10000      9500         500
```

## 🍕 Installation

Using {remotes} directly from GitHub:

``` r
install.packages("remotes")
remotes::install_github("tidywf/nemo") # latest main commit
remotes::install_github("tidywf/nemo@v0.0.3.9020") # specific version
```

Alternatively:

- conda package: <https://anaconda.org/tidywf/r-nemo>

For more details see:
<https://tidywf.github.io/nemo/articles/installation>

## 🌀 CLI

A `nemo.R` command line interface is available for convenience.

- If you’re using the conda package, the `nemo.R` command will already
  be available inside the activated conda environment.
- If you’re *not* using the conda package, you need to export the
  `nemo/inst/cli/` directory to your `PATH` in order to use `nemo.R`.

``` bash
nemo_cli=$(Rscript -e 'x = system.file("cli", package = "nemo"); cat(x, "\n")' | xargs)
export PATH="${nemo_cli}:${PATH}"
```

    $ nemo.R --version
    nemo 0.0.3.9020

    #-----------------------------------#
    $ nemo.R --help
    usage: nemo.R [-h] [-v] {tidy,list} ...

    Tidy Bioinformatic Workflows

    positional arguments:
      {tidy,list}    sub-command help
        tidy         Tidy Workflow Outputs
        list         List Parsable Workflow Outputs

    options:
      -h, --help     show this help message and exit
      -v, --version  show program's version number and exit
    '
    #-----------------------------------#
    $ nemo.R tidy --help
    usage: nemo.R tidy [-h] -w WORKFLOW -d IN_DIR [-o OUT_DIR] [-f FORMAT]
                       [--input_id INPUT_ID] [--output_id OUTPUT_ID | --ulid]
                       [--dbname DBNAME] [--dbuser DBUSER] [--include INCLUDE]
                       [--exclude EXCLUDE] [--prefix_include] [-q]

    options:
      -h, --help            show this help message and exit
      -w, --workflow WORKFLOW
                            Workflow name.
      -d, --in_dir IN_DIR   Input directory.
      -o, --out_dir OUT_DIR
                            Output directory.
      -f, --format FORMAT   Format of output [def: parquet] (parquet, db, tsv,
                            csv, rds)
      --input_id INPUT_ID   Input ID for this run.
      --output_id OUTPUT_ID
                            Output ID for this run.
      --ulid                Generate a ULID as output ID.
      --dbname DBNAME       Database name.
      --dbuser DBUSER       Database user.
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
