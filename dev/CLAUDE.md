# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/claude-code) when
working with code in this repository.

## Project Overview

nemo is an R package for tidying and exploring outputs from
bioinformatic pipelines. It uses R6 classes to define Tools (parsers for
specific file types) and Workflows (collections of Tools).

## Key Architecture

- **Tool**: Base R6 class (`R/Tool.R`) that parses specific file types
  and outputs tidy tibbles
- **Workflow**: R6 class (`R/Workflow.R`) that orchestrates multiple
  Tools, handling file discovery, tidying, and writing
- **Config**: R6 class (`R/Config.R`) that reads a per-tool LinkML
  schema (`inst/config/tools/<tool>/schema.yaml`) and exposes raw/tidy
  schemas as tibbles
- Tools inherit from the base `Tool` class and implement file-specific
  parsing logic

## Config / Schema System

Each tool has a single LinkML (<https://github.com/linkml/linkml>)
schema at `inst/config/tools/<tool>/schema.yaml`.

### Class naming convention

| Prefix | Meaning                        | Example      |
|--------|--------------------------------|--------------|
| `Raw`  | Describes an input file        | `RawTable1`  |
| `Tidy` | Describes a tidy output tibble | `TidyTable1` |

The prefix is stripped and lowercased to get the table name used in the
`Config` API (e.g. `RawTable1` → `"table1"`).

### Versioning

Slot-level `in_subset` tags declare which tool versions a field belongs
to. Version subsets are anything that isn’t `raw` or `tidy`
(e.g. `v1.2.3`, `latest`). If no slot-level version tags exist, the
class-level `in_subset` is used.

### nemo-specific annotations

Since LinkML has no native concept of file discovery, nemo-specific
metadata is stored in class `annotations`: - `name` — explicit logical
table name (e.g. `table1`). **Required** on all classes. Decouples the
class name from the table name, which allows multiple tidy classes to
share the same logical name (e.g. `TidyTable1Coords` and
`TidyTable1Metrics` both with `name: table1`, distinguished by
`subtbl`) - `pattern` — regex used to match raw output files - `ftype` —
file type (`tsv`, `txt-nohead`, etc.) - `subtbl` — tidy sub-table name
(defaults to `"tbl1"` if omitted). Use distinct values when one raw
table produces multiple tidy tibbles

### Field types

LinkML `range` types map to readr col spec codes internally:

| LinkML    | nemo internal |
|-----------|---------------|
| `string`  | `c`           |
| `integer` | `i`           |
| `float`   | `d`           |

### Key helpers (`R/utils.R`)

- `linkml_type_remap(x)` — maps LinkML type → nemo internal type
- `linkml_classes_by_subset(schema, subset)` — filter classes by subset
  tag
- `linkml_class_name(cls, cls_name, prefix)` — get logical table name;
  prefers `annotations$name`, falls back to stripping prefix and
  lowercasing
- `linkml_strip_prefix(x, prefix)` — strip class name prefix and
  lowercase (used as fallback by `lkml_class_name`)
- `linkml_class_versions(cls)` — get version tags for a class
- `linkml_slots_for_version(cls, v)` — get slots belonging to a version

## Reference Implementations

`Tool1` (`R/Tool1.R`) and `Workflow1` (`R/Workflow1.R`) are the
canonical examples to follow when creating new tools or workflows. They
demonstrate the full pattern: schema config, file discovery, raw
parsing, and tidy output.

## CLI

The CLI is built with `argparse` via
[`nemo_cli()`](https://tidywf.github.io/nemo/dev/reference/nemo_cli.md)
(`R/cli.R`). The entry script lives at `inst/cli/nemo.R`. Two
subcommands are available:

| Subcommand | Key args | What it does |
|----|----|----|
| `list` | `-d IN_DIR`, `-f FORMAT` | Lists parsable files in a workflow directory; output as `pretty` (markdown table) or `tsv` |
| `tidy` | `-d IN_DIR`, `-o OUT_DIR`, `-f FORMAT`, `-i ID` | Runs `nemofy()` on a directory and writes tidy outputs |

Both subcommands accept `-w WORKFLOW` (workflow name) and `-q` (quiet).
The `tidy` subcommand also accepts `--include`/`--exclude`
(comma-separated file filters) and `--dbname`/`--dbuser` for database
output.

## Parsing (`R/parse.R`)

| Function | File type (`ftype`) | Notes |
|----|----|----|
| [`parse_file()`](https://tidywf.github.io/nemo/dev/reference/parse_file.md) | `tsv` | Header present; schema version auto-detected via [`schema_guess()`](https://tidywf.github.io/nemo/dev/reference/schema_guess.md) |
| [`parse_file_nohead()`](https://tidywf.github.io/nemo/dev/reference/parse_file_nohead.md) | `txt-nohead` | No header; column count validated against schema |
| [`parse_file_keyvalue()`](https://tidywf.github.io/nemo/dev/reference/parse_file_keyvalue.md) | key-value tsv | Two-column file pivoted wide |
| [`file_hdr()`](https://tidywf.github.io/nemo/dev/reference/file_hdr.md) | any delimited | Returns column names without reading full file |
| [`schema_guess()`](https://tidywf.github.io/nemo/dev/reference/schema_guess.md) | — | Matches column names against all versioned schemas; errors if not exactly one match |

All parse functions attach a `file_version` attribute to the returned
tibble.

## Writing (`R/write.R`)

- `nemo_write(d, fpfix, format, dbconn, dbtab)` — dispatches to the
  correct writer based on `format`
- `nemo_osfx(fpfix, format)` — constructs output file path with the
  right extension (`.tsv.gz`, `.csv.gz`, `.parquet`, `.rds`)
- [`nemo_out_formats()`](https://tidywf.github.io/nemo/dev/reference/nemo_out_formats.md)
  — returns the vector of valid format strings: `parquet`, `db`, `tsv`,
  `csv`, `rds`

## Common Commands

``` r
# Load package for development
devtools::load_all()

# Run tests
devtools::test()

# Update documentation (NAMESPACE, Rd files)
devtools::document()

# Run R CMD check
devtools::check()

# Example workflow usage
path <- system.file("extdata/tool1", package = "nemo")
tools <- list(tool1 = Tool1)
wf <- Workflow$new(name = "test_wf", path = path, tools = tools)
wf$nemofy(diro = tempdir(), format = "parquet", input_id = "run1")
```

## Testing Convention

Tests are generated automatically by
[roxytest](https://github.com/mikldk/roxytest) from `@testexamples`
blocks in roxygen documentation. **Do not write test files manually** —
add `@examples` (for the example itself) and `@testexamples` (for
`expect_*` assertions) to the function’s roxygen block, then run
`devtools::document()` to regenerate the test files in
`tests/testthat/`.

## Code Formatting and Pre-commit Hooks

R code is formatted with [air](https://github.com/posit-dev/air)
(100-char line width, 2-space indent, configured in `air.toml`).
Pre-commit hooks (`.pre-commit-config.yaml`) enforce: - `air-format` —
auto-formats R files on commit - `check-added-large-files` — blocks
files \> 200 KB - `file-contents-sorter` — keeps `.Rbuildignore`
sorted - `check-yaml` — validates YAML syntax - `forbid-to-commit` —
blocks `.Rhistory`, `.RData`, `.Rds`, `.rds` files

## Version Bumping and Release Workflow

Bumping is done via the `.github/workflows/bump.yaml` GitHub Actions
workflow, which installs the package, bumps all version references,
renders `README.qmd`, and pushes a single `Bump version: OLD => NEW`
commit directly to the branch (using the bot token to bypass branch
protection). The `deploy.yaml` workflow triggers on that commit message
pattern.

Trigger it from the CLI:

``` bash
make bump VERSION=x.y.z BRANCH=dev
# or on main:
make bump VERSION=x.y.z BRANCH=main
```

This calls
`gh workflow run bump.yaml --ref BRANCH --field version=VERSION` under
the hood. Can also be triggered via the GitHub Actions UI: Actions →
Bump Version → Run workflow.

## CI/CD: `.github/workflows/deploy.yaml`

The `conda-docs` workflow triggers on pushes to `main` or `dev`, but
only runs when the commit message starts with `Bump version:`. Both jobs
call reusable workflows from `tidywf/.github`.

### Jobs

**`condarise_and_tag`** — delegates to
`tidywf/.github/.github/workflows/condarise-and-tag.yaml`: 1. Builds the
conda package with `rattler-build` 2. Uploads to Anaconda under the
`tidywf` owner; uses `--channel dev` label on `dev` 3. Regenerates the
conda lock file (`deploy/conda/env/lock/conda-linux-64.lock`) for
`linux-64` 4. Commits and pushes the updated lock file as a bot commit
5. Creates a git tag (`vVERSION`) — on both branches

**`pkgdownise`** (depends on `condarise_and_tag`) — delegates to
`tidywf/.github/.github/workflows/pkgdownise.yaml`: - Checks out the
release tag, then deploys via
[`pkgdown::deploy_to_branch()`](https://pkgdown.r-lib.org/reference/deploy_to_branch.html)
— same flow on both branches

### Version

The version is set via `pkg_version:` in the `with:` blocks of each job.
`make bump VERSION=x.y.z` updates all occurrences automatically.

## Output Formats

The [`write()`](https://rdrr.io/r/base/write.html) and `nemofy()`
methods support: - `tsv` - Tab-separated values (gzipped: `.tsv.gz`) -
`csv` - Comma-separated values (gzipped: `.csv.gz`) - `parquet` - Apache
Parquet format - `rds` - R serialized format - `db` - Database (requires
`dbconn` parameter)
