

<!-- README.md is generated from README.qmd. Please edit that file -->

<a href="https://tidywf.github.io/nemo"><img src="man/figures/logo.png" alt="logo" align="left" height="100" /></a>

# Tidy and Explore Bioinformatic Pipeline Outputs

[![conda-latest1](https://anaconda.org/tidywf/r-nemo/badges/latest_release_date.svg "Conda Latest Release")](https://anaconda.org/tidywf/r-nemo)
[![gha](https://github.com/tidywf/nemo/actions/workflows/deploy.yaml/badge.svg "GitHub Actions")](https://github.com/tidywf/nemo/actions/workflows/deploy.yaml)

📚 Docs:
[Installation](https://tidywf.github.io/nemo/articles/installation) \|
[Files supported](https://tidywf.github.io/nemo/articles/schema_table)
\| [Changelog](https://tidywf.github.io/nemo/articles/NEWS) \| [R6
structure](https://tidywf.github.io/nemo/articles/structure) \|
[UML](https://tidywf.github.io/nemo/articles/uml) \|
[CI/CD](https://tidywf.github.io/nemo/articles/cicd)

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

nemo is an R package that attempts to address these issues by providing
a schema-driven parsing and tidying layer that turns raw pipeline
outputs into consistently structured, versioned, analysis-ready tables.

Its R6 classes (`Tool`, `Workflow`, `Config`) form the base layer: given
a directory of bioinformatic results, they identify files by
YAML-defined schemas, reshape and rename columns to a consistent tidy
form, and write to a specified format (Apache Parquet, TSV, CSV, RDS, or
PostgreSQL). Each run also produces a `metadata.parquet` file alongside
the tidy tables, capturing IDs, paths, and package versions.

Downstream packages extend these base classes by supplying tool-specific
schemas and parsers.
[tidywigits](https://github.com/tidywf/tidywigits "tidywigits") and
[tidydragen](https://github.com/tidywf/tidydragen "tidydragen") are
example R packages that target the large number of outputs from the
established bioinformatic pipelines WiGiTS/hmftools and Illumina DRAGEN,
respectively.

## Quickstart

Raw pipeline outputs often have non-standard layouts. For example, this
file stores QC metrics as key-value rows rather than columns:

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

The `run()` method is able to filter, tidy, and write all tables of
interest in one call (`Workflow1` is nemo’s built-in example workflow):

``` r
outdir <- file.path(tempdir(), "quickstart")

Workflow1$new(path = path)$run(
  output_dir      = outdir,
  format       = "parquet",
  input_id     = "run1",
  output_id    = "out1",
  prefix_include = TRUE
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
  input_id input_prefix output_id sample_id qcstatus reads_total reads_map reads_unmap
* <chr>    <chr>        <chr>     <chr>     <chr>          <dbl>     <dbl>       <dbl>
1 run1     sampleA      out1      sampleA   Pass           10000      9500         500
```

Three optional columns can be prepended to every written table to
support downstream tracing and joining. All are opt-in and off by
default, but highly recommended for any multi-sample or multi-run
pipeline:

| Column         | Purpose                            |
|----------------|------------------------------------|
| `input_id`     | identifies the sample or input run |
| `output_id`    | identifies the processing run      |
| `input_prefix` | filename prefix (e.g. sample name) |

## Installation

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

## CLI

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
    usage: nemo.R tidy [-h] -w WORKFLOW -d IN_DIR [-o OUTPUT_DIR] [-f FORMAT]
                       [--input_id INPUT_ID] [--output_id OUTPUT_ID | --ulid]
                       [--dbname DBNAME] [--dbuser DBUSER] [--include INCLUDE]
                       [--exclude EXCLUDE] [--prefix_include] [-q]

    options:
      -h, --help            show this help message and exit
      -w WORKFLOW, --workflow WORKFLOW
                            Workflow name.
      -d IN_DIR, --in_dir IN_DIR
                            Input directory.
      -o OUTPUT_DIR, --output_dir OUTPUT_DIR
                            Output directory.
      -f FORMAT, --format FORMAT
                            Format of output [def: parquet] (parquet, db, tsv,
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
      -w WORKFLOW, --workflow WORKFLOW
                            Workflow name.
      -d IN_DIR, --in_dir IN_DIR
                            Input directory.
      -f FORMAT, --format FORMAT
                            Format of list output [def: pretty] (tsv, pretty)
      -m MAX, --max MAX     Max rows to show.
      -q, --quiet           Shush all the logs.
