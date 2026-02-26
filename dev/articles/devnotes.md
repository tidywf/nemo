# Devnotes

### R pkg dev

| Command | Comment | Shortcut |
|----|----|----|
| `devtools::check()` | build and check the pkg | `Cmd + Shift + E` |
| `devtools::load_all()` | load the pkg | `Cmd + Shift + L` |
| `devtools::document()` | document the pkg | `Cmd + Shift + D` |
| `pak::local_install(upgrade = FALSE)` | install the pkg into the first library of [`.libPaths()`](https://rdrr.io/r/base/libPaths.html) | `Cmd + Shift + B` |

### conda

| Command | Comment |
|----|----|
| `conda install foo -c bar` | install pkg `foo` from channel `bar` |
| `conda create --file env.yml --prefix ./bar` | install conda pkgs listed in `env.yml` into the `./bar` directory |
| `conda info -e` | list conda environments installed on this machine |
| `rattler-build build -r recipe.yaml --output-dir ${HOME}/tmp` | build conda pkg from a recipe file |
| `rattler-build upload anaconda -o umccr --api-key <xxx> ${HOME}/tmp/r-tidywigits.conda` | upload conda pkg to anaconda |

### pkgdown

| Command | Comment |
|----|----|
| [`pkgdown::build_site()`](https://pkgdown.r-lib.org/reference/build_site.html) | builds entire site |
| `pkgdown::build_articles(quiet = FALSE)` | builds vignettes in debug mode |
| `pkgdown::build_article("developers")` | builds developers vignette only |

### Data Version Control

Instead of committing big data files into `git`, we can store the files
remotely (e.g. Google Drive, AWS S3, Cloudflare R2) and just keep track
of the data updates in `git` using [DVC](https://dvc.org/).

The R package uses the data files when running the code examples and
tests, and when rendering the vignettes. A simple `dvc pull` will pull
the data from the remote storage and allow these processes to take
place.

| Command | Comments |
|----|----|
| `dvc init` | initialise dvc |
| `dvc remote add -d storage gdrive://<...>` | add GDrive remote |
| `dvc remote add -d my_r2 s3://<...>` | add Cloudflare R2 remote |
| `dvc remote modify my_r2 endpointurl https://<...>.r2.cloudflarestorage.com` | add Cloudflare R2 remote endpointurl |
| `dvc remote list` | list all remotes |
| `dvc check-ignore *` | check what is dvc-ignored |
| `dvc list https://github.com/umccr/tidywigits inst/extdata` | list dvc’ed data |
| `dvc add path/to/folder` | adds `folder` (and its contents) to dvc |
| `dvc add path/to/file.txt` | adds `file.txt` to dvc |
| `dvc push` | pushes dvc data to remote |
| `dvc pull` | pulls dvc data from remote |
