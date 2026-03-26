# Installation

There are several ways to install {nemo}:

### R

Using {remotes} directly from GitHub:

``` r
install.packages("remotes")
remotes::install_github("tidywf/nemo") # latest main commit
remotes::install_github("tidywf/nemo@v0.0.3.9007") # released version
```

### Conda

[![conda-version](https://anaconda.org/tidywf/r-nemo/badges/version.svg "Conda package version")![conda-latest](https://anaconda.org/tidywf/r-nemo/badges/latest_release_date.svg "Conda package latest release date")](https://anaconda.org/tidywf/r-nemo)

The conda package is available from the tidywf channel at
<https://anaconda.org/tidywf/r-nemo>.

``` bash
conda create \
  -n nemo_env \
  -c tidywf -c conda-forge \
  r-nemo==0.0.3.9007

conda activate nemo_env
```

### Pixi

If you use [Pixi](https://pixi.sh/), you can create a new isolated
environment with the deployed conda package:

``` bash
pixi init -c tidywf -c conda-forge ./tidy_env
cd ./tidy_env
pixi add r-nemo==0.0.3.9007
```

Then you can create a task to run the `nemo.R` CLI script:

``` bash
pixi task add nemo "nemo.R"
pixi run nemo --help
```

Or activate the environment and use nemo directly in an R environment:

``` bash
pixi shell
R
```

``` r
library(nemo)
```
