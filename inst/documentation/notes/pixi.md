### Installation

Pixi is awesome - see <https://pixi.sh/>.

```
brew install pixi
```

### Project

```
cd my_projects
pixi init hello-world -c conda-forge -c tidywf
cd hello-world
```

- `pixi.toml`

A TOML file `pixi.toml` is created in the project directory:

```toml
[workspace]
authors = ["pdiakumis <peterdiakumis@gmail.com>"]
channels = ["conda-forge", "tidywf"]
name = "hello-world"
platforms = ["osx-arm64"]
version = "0.1.0"

[tasks]


[dependencies]

```

- dependencies

This will look into the `conda-forge` and `tidywf` conda channels for `r-tidywigits`,
and install it into `./.pixi` along with its dependencies.

```
pixi add r-tidywigits
```

```
ls -1 .pixi/envs/default/lib/R/library/tidywigits/cli
list.R
tidy.R
tidywigits.R
```

- `pixi.lock`

A lock file `pixi.lock` is also created in the project directory

### Tasks

```
pixi task add tidy "tidywigits.R"
```

Then you run that task with `pixi run <...>`:

```
pixi run tidy --help
✨ Pixi task (tidy): tidywigits.R --help
usage: tidywigits.R [-h] [-v] {tidy,list} ...

🐠 WiGiTS Output Tidying 🐢

[...]
```

### Environment

- activate pixi environment

```
pixi shell
```

This behaves like a conda environment with the env prefix:

```
(hello-world) $ ...
```

To exit:

```
exit
```

