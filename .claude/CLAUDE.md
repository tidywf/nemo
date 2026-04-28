# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/claude-code) when working with code in this repository.

## Project Overview

nemo is an R package for tidying and exploring outputs from bioinformatic pipelines. It uses R6 classes to define Tools (parsers for specific file types) and Workflows (collections of Tools).

## Key Architecture

- **Tool**: Base R6 class (`R/Tool.R`) that parses specific file types and outputs tidy tibbles
- **Workflow**: R6 class (`R/Workflow.R`) that orchestrates multiple Tools, handling file discovery, tidying, and writing
- **Config**: R6 class (`R/Config.R`) that reads `inst/config/tools/<tool>/schema.yaml` and exposes raw/tidy schemas as tibbles
- Tools inherit from the base `Tool` class and implement file-specific parsing logic

## Reference Implementations

`Tool1` (`R/Tool1.R`) and `Workflow1` (`R/Workflow1.R`) are the canonical examples to follow when creating new tools or workflows. They demonstrate the full pattern: schema config, file discovery, raw parsing, and tidy output.

## CLI

The CLI is built with `argparse` via `nemo_cli()` (`R/cli.R`). The entry script lives at `inst/cli/nemo.R`. Two subcommands are available:

| Subcommand | Key args | What it does |
|------------|----------|--------------|
| `list` | `-d IN_DIR`, `-f FORMAT` | Lists parsable files in a workflow directory; output as `pretty` (markdown table) or `tsv` |
| `tidy` | `-d IN_DIR`, `-o OUT_DIR`, `-f FORMAT`, `-i ID` | Runs `nemofy()` on a directory and writes tidy outputs |

Both subcommands accept `-w WORKFLOW` (workflow name) and `-q` (quiet). The `tidy` subcommand also accepts `--include`/`--exclude` (comma-separated file filters) and `--dbname`/`--dbuser` for database output.

## Parsing (`R/parse.R`)

| Function | File type (`ftype`) | Notes |
|----------|---------------------|-------|
| `parse_file()` | `tsv` | Header present; schema version auto-detected via `schema_guess()` |
| `parse_file_nohead()` | `txt-nohead` | No header; column count validated against schema |
| `parse_file_keyvalue()` | key-value tsv | Two-column file pivoted wide |
| `file_hdr()` | any delimited | Returns column names without reading full file |
| `schema_guess()` | — | Matches column names against all versioned schemas; errors if not exactly one match |

All parse functions attach a `file_version` attribute to the returned tibble.

## Writing (`R/write.R`)

- `nemo_write(d, fpfix, format, dbconn, dbtab)` — dispatches to the correct writer based on `format`
- `nemo_osfx(fpfix, format)` — constructs output file path with the right extension (`.tsv.gz`, `.csv.gz`, `.parquet`, `.rds`)
- `nemo_out_formats()` — returns the vector of valid format strings: `parquet`, `db`, `tsv`, `csv`, `rds`

## Common Commands

```r
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

Tests are generated automatically by [roxytest](https://github.com/mikldk/roxytest) from `@testexamples` blocks in roxygen documentation. **Do not write test files manually** — add `@examples` (for the example itself) and `@testexamples` (for `expect_*` assertions) to the function's roxygen block, then run `devtools::document()` to regenerate the test files in `tests/testthat/`.

## Code Formatting and Pre-commit Hooks

R code is formatted with [air](https://github.com/posit-dev/air) (100-char line width, 2-space indent, configured in `air.toml`). Pre-commit hooks (`.pre-commit-config.yaml`) enforce:
- `air-format` — auto-formats R files on commit
- `check-added-large-files` — blocks files > 200 KB
- `file-contents-sorter` — keeps `.Rbuildignore` sorted
- `check-yaml` — validates YAML syntax
- `forbid-to-commit` — blocks `.Rhistory`, `.RData`, `.Rds`, `.rds` files

## Version Bumping and Release Workflow

Bumping is done via the `.github/workflows/bump.yaml` GitHub Actions workflow, which installs the package, bumps all version references, renders `README.qmd`, and pushes a single `Bump version: OLD => NEW` commit directly to the branch (using the bot token to bypass branch protection). The `deploy.yaml` workflow triggers on that commit message pattern.

Trigger it from the CLI:

```bash
make bump VERSION=x.y.z BRANCH=dev
# or on main:
make bump VERSION=x.y.z BRANCH=main
```

This calls `gh workflow run bump.yaml --ref BRANCH --field version=VERSION` under the hood. Can also be triggered via the GitHub Actions UI: Actions → Bump Version → Run workflow.

## UML Generation

`nemo_uml()` (`R/uml.R`) generates a PlantUML diagram from R6 class names and renders it as an SVG. Entry script: `inst/scripts/uml.R`. Output tracked in `vignettes/fig/uml/`. `R6toPlant` is in `Suggests` + `Remotes`.

## CI/CD: `.github/workflows/deploy.yaml`

The `conda-docs` workflow triggers on pushes to `main` or `dev`, but only runs when the commit message starts with `Bump version:`. All jobs delegate to reusable workflows in `tidywf/.github`.

### Jobs (in order)

| Job | Reusable workflow | Notes |
|-----|-------------------|-------|
| `umlise` | `umlise.yaml` | Installs from source, runs `inst/scripts/uml.R`, commits `vignettes/fig/uml/` if changed |
| `condarise` | `condarise.yaml` | Builds + uploads conda pkg, regenerates lock file, commits |
| `tag` | `tag.yaml` | `git pull` to collect all bot commits, then creates `vVERSION` tag |
| `pkgdownise` | `pkgdownise.yaml` | Checks out tag, deploys pkgdown site |

### Version

The version is set via `pkg_version:` in the `with:` blocks of each job. `make bump VERSION=x.y.z` updates all occurrences automatically.

## Output Formats

The `write()` and `nemofy()` methods support:
- `tsv` - Tab-separated values (gzipped: `.tsv.gz`)
- `csv` - Comma-separated values (gzipped: `.csv.gz`)
- `parquet` - Apache Parquet format
- `rds` - R serialized format
- `db` - Database (requires `dbconn` parameter)
