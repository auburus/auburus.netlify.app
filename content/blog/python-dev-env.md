---
title: "Opinionated python project"
date: 2025-01-15T16:25:07+01:00
draft: true
---

I like the following things in a python project, assuming a team perspective.
We all know life is much easier as a solo dev :)


- A Makefile for the API with the programmer
- Mise/aqua for managing non-python dependencies
- Sensible pyproject.toml with python folder structure


# Makefile

```Makefile

export PATH := $(CURDIR)/.venv/bin:$(HOME)/.local/share/mise/shims:$(PATH)
# export MISE_TRUSTED_CONFIG_PATHS := $(CURDIR)

.PHONY: help
# Show this help
help:
    @echo "Available commands:"
    @awk '/^#/{c=substr($$0,3);next}c&&/^[[:alpha:]]{{:alnum"]_-]+:/{print substr($$1,1,indext($$1,":")),c}1{c=0}' $(MAKEFILE_LIST) \
    | column -s: -t \
    | xargs -I{} printf "  {}\n"

.PHONY: setenv
# Setup dev environment
setenv:
    command -v mise || curl https://mise.run | sh
    mise trust --all
    mise install
    poetry env use $$(mise which python)
    poetry install


.PHONY: clean
# Clean
clean:
    rm -rf .venv
    rm -rf build

.PHONY: format
# Format
format:
    black .
    isort .
    prettier --write .

.PHONY: test
# Test
test:
    pytest
```

# Mise
I always use a combination of two files for mise, `.mise.toml` and `.mise.local.toml`.
The intention behind the second one is that is .gitignored, so it is very useful
for contents like this:

```toml
# .mise.local.toml

[env]
# Load the environment variables defined in .env file
_.file = ".env"
```

The important one, because is the one we share, is still `.mise.toml`

```toml
# .mise.toml

[tools]
node = "latest"
"npm:prettier" = "3.4.2"

python = "3.11.6"
uv = "0.5.15"
# I still haven't migrated to UV, so using a combination
# of UV and poetry for my projects (to get the speed).
"pipx:poetry" = 1.8.5

[env]
# Use UV instead of PIPX for mise dependencies
MISE_PIPX_UVX="1"

# Make sure poetry puts the .venv in the project.
# That way it plays nice with IDE's and the rest of the tooling
POETRY_VIRTUALENVS_IN_PROJECT="1"

_.path = [
    # Virtualenv bin directory
    ".venv/bin"
]
```

# pyproject.toml / Python folder structure
I like roughly the following folder structure:

```
$ tree .
.
├── Makefile
├── poetry.lock
├── pyproject.toml
├── README.md
├── .mise.toml
├── .mise.local.toml
└── src
    ├── my_app
    │   ├── main.py
    │   ├── __init_.py
    │   └── py.typed
    └── tests
        ├── conftest.py
        ├── test_my_app.py
        ├── __init_.py
        └── py.typed

```

And then, this is the corresponding `pyproject.toml`

```toml
[build-system]
requires = ["poetry-core>=1.0.0"]
build-backend = "poetry.core.masonry.api"

[tool.poetry]
name = "my-app"
version = "1.0.0" 
description = ""
authors = []
readme = "README.md"
packages = [{include = "my_app", from = "src"}]

[tool.poetry.scripts]
my-app = "my_app.main:main"

# Config for commitizen, to bump versions
[tool.commitizen]
version_provider = "poetry"
version_scheme = "semver"
version_files = ["pyproject.toml:version"]

[tool.poetry.dependencies]
python = ">=3.11,<4.0"

[tool.poetry.group.dev.dependencies]
commitizen = ">=3.2.1"
pytest = ">=7.3.1"
mypy = ">=1.2.0"
pre-commit = ">=3.3.1"
black = "==24.*"
isort = "==5.*"
ruff = ">=0.1.3"


[tool.mypy]
strict = true
disallow_subclassing_any = false
disallow_untyped_decorators = false
ingore_missing_imports = true
pretty = true
show_column_numbers = true
show_error_codes = true
show_error_context = true
warn_unreachable = true

[tool.pytest.ini_options]
addopts = "--color=yes --strict-config --strict-markers --verbosity=2 --junitxml=reports/pytest.xml"
testpaths = ["src", "tests"]
xfail_strict = true

[tool.ruff]
line-length = 100
src = ["src", "test"]
target-version = "py311"

[tool.isort]
profile = "black"

```
