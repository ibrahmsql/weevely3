set shell := ["bash", "-c"]
set quiet

NAME := "weevely"
DATE := "2025-06-04"

# This thing
help:
	#!/bin/bash
	echo -e "{{YELLOW}}[+] {{MAGENTA}}{{NAME}} {{BLUE}}{{DATE}}{{NORMAL}}"
	echo -e "{{YELLOW}}[*] usage: {{GREEN}}just <target>{{NORMAL}}"
	just --list --list-heading "" --unsorted

# install in editable mode
dev:
	#!/bin/bash
	uv tool install -e . --force

# uninstall package
uninstall:
	#!/bin/bash
	uv tool uninstall weevely

# format code
format:
	#!/bin/bash
	ruff format src

# clean build files
clean:
	#!/bin/bash
	rm -rf dist

# run tests
test cmd="":
	#!/bin/bash
	sudo tests/run.sh {{cmd}}

# build packages
build:
	#!/bin/bash
	uv build --wheel

# install built whl packages
install-build: build
	#!/bin/bash
	uv tool install --force dist/*.whl

# check code quality
lint:
	#!/bin/bash
	ruff check src
	ruff format --check src

# fix code quality issues
fix:
	#!/bin/bash
	ruff check --fix src
	ruff format src

# type check
typecheck:
	#!/bin/bash
	mypy src

# build docker image
docker-build:
	docker build -t weevely .

# run docker container
docker-run cmd="--help":
	docker run --rm -it weevely {{cmd}}

# run c2 dashboard
c2:
	#!/bin/bash
	uv run uvicorn weevely.c2.main:app --reload --port 8000
