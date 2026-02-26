# 🐢 Tidy and Explore Bioinformatic Pipeline Outputs

[![conda-latest1](https://anaconda.org/umccr/r-nemo/badges/latest_release_date.svg "Conda Latest Release")](https://anaconda.org/umccr/r-nemo)
[![gha](https://github.com/umccr/nemo/actions/workflows/deploy.yaml/badge.svg "GitHub Actions")](https://github.com/umccr/nemo/actions/workflows/deploy.yaml)

- 📚 Docs: <https://umccr.github.io/nemo>
  - [Installation](https://umccr.github.io/nemo/articles/installation)
  - [R6 structure](https://umccr.github.io/nemo/articles/structure)
  - [Changelog](https://umccr.github.io/nemo/articles/NEWS)

## Overview

{nemo} is an R package that contains the building blocks for parsing,
tidying, and writing bioinformatic pipeline results in a more consistent
structure.

In short, it traverses through a directory containing results from one
or more runs of certain bioinformatic tools, parses any files it
recognises, tidies them up (which includes data reshaping,
normalisation, column name cleanup etc.), and writes them to the output
format of choice e.g. Apache Parquet, PostgreSQL, TSV, RDS.

The specific tools it can handle are controlled by configuration files
written in YAML that are part of ‘child’ {nemo} packages, like
{[tidywigits](https://github.com/umccr/tidywigits "tidywigits")} and
{[dracarys](https://github.com/umccr/dracarys "dracarys")}. These
configuration files (under `inst/config` in those respective packages)
specify the schemas, types, patterns and field descriptions for the
*raw* input *files* and *tidy* output *tbls*.

## 🍕 Installation

Using {remotes} directly from GitHub:

``` r
install.packages("remotes")
remotes::install_github("umccr/nemo") # latest main commit
remotes::install_github("umccr/nemo@v0.0.3.9006") # released version
```

Alternatively:

- conda package: <https://anaconda.org/umccr/r-nemo>

For more details see:
<https://umccr.github.io/nemo/articles/installation>

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

``` R
$ nemo.R --version
nemo 0.0.3.9006

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
usage: nemo.R tidy [-h] -w WORKFLOW -d IN_DIR [-o OUT_DIR] [-f FORMAT] -i ID
                   [--dbname DBNAME] [--dbuser DBUSER] [--include INCLUDE]
                   [--exclude EXCLUDE] [-q]

options:
  -h, --help            show this help message and exit
  -w WORKFLOW, --workflow WORKFLOW
                        Workflow name.
  -d IN_DIR, --in_dir IN_DIR
                        Input directory.
  -o OUT_DIR, --out_dir OUT_DIR
                        Output directory.
  -f FORMAT, --format FORMAT
                        Format of output [def: parquet] (parquet, db, tsv,
                        csv, rds)
  -i ID, --id ID        ID to use for this run.
  --dbname DBNAME       Database name.
  --dbuser DBUSER       Database user.
  --include INCLUDE     Include only these files (comma,sep).
  --exclude EXCLUDE     Exclude these files (comma,sep).
  -q, --quiet           Shush all the logs.

#-----------------------------------#
$ nemo.R list --help
usage: nemo.R list [-h] -w WORKFLOW -d IN_DIR [-f FORMAT] [-q]

options:
  -h, --help            show this help message and exit
  -w WORKFLOW, --workflow WORKFLOW
                        Workflow name.
  -d IN_DIR, --in_dir IN_DIR
                        Input directory.
  -f FORMAT, --format FORMAT
                        Format of list output [def: pretty] (tsv, pretty)
  -q, --quiet           Shush all the logs.
```
