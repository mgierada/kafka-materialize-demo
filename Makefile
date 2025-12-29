.DEFAULT_GOAL := help

## project ID
PROJECT := kafka-materialize-demo

ifneq (,$(wildcard .env))
include .env
export $(shell sed -n 's/^\([A-Za-z_][A-Za-z0-9_]*\)=.*/\1/p' .env)
endif

##----------------------------------------------------------------------------
##
##  env files
##
##----------------------------------------------------------------------------

## project env file
ENV_FILE := .envrc
export ENV_FILE
APPLICATION = $(PROJECT)
export APPLICATION


## import .env files
##
## -- project level
$(shell touch $(ENV_FILE))
include $(ENV_FILE)

##----------------------------------------------------------------------------
##
## 	Other identifiers
##
##----------------------------------------------------------------------------

# python version
PYTHON_VERSION := 3.11.9

##----------------------------------------------------------------------------
##
## 	Makefile config
##
##----------------------------------------------------------------------------

## IMPORTANT - stop on first subcommand error
.SHELLFLAGS = -ec

##
## for commands that differ by OS or shell, for example:
##
##		ifeq ($(OS),Darwin)
##			## do OSX thing
##		else
##			## do non-OSX thing
##		endifset
##
OS := $(shell uname)
SHELL := $(shell which bash || which ash)

##
## for recursive make calls within this file, use `${MAKE}` not `make`
## -- see https://www.gnu.org/software/make/manual/make.html#MAKE-Variable
##
MAKE := ${MAKE} --no-print-directory

##----------------------------------------------------------------------------
##
## 	ANSI text colors
##
##----------------------------------------------------------------------------

TEXT_RESET := \033[0m
export TEXT_RESET
TEXT_YELLOW := \033[33m
export TEXT_YELLOW
TEXT_GREEN := \033[32m
export TEXT_GREEN
TEXT_PURPLE := \033[35m
export TEXT_PURPLE
TEXT_CYAN := \033[36m
export TEXT_CYAN
TEXT_BLUE := \033[34m
export TEXT_BLUE
TEXT_RED := \033[31m
export TEXT_RED
TEXT_BOLD := \033[01m
export TEXT_BOLD

##----------------------------------------------------------------------------
##@ General targets
##----------------------------------------------------------------------------

## @@note targets without a comment on a label line, or that include HIDDEN in that
## comment, will not be listed by the help command - hides a comment w/out deleting
.PHONY: help
help: ##@ (Default) Print listing of key targets with their descriptions
	@printf "\nUsage: make $(TEXT_CYAN)<command>$(TEXT_RESET)\n"
	@grep -F -h "##@" $(MAKEFILE_LIST) | grep -F -v grep -F | sed -e 's/\\$$//' | awk 'BEGIN {FS = ":*[[:space:]]*##@[[:space:]]*"}; \
	{ \
		if($$2 == "") \
			printf ""; \
		else if($$0 ~ /^#/) \
			printf "\n$(TEXT_BOLD)%s$(TEXT_RESET)\n", $$2; \
		else if($$1 == "") \
			printf "     %-30s%s\n", "", $$2; \
		else \
			printf "\n    $(TEXT_CYAN)%-30s$(TEXT_RESET) %s\n", $$1, $$2; \
	}'

##----------------------------------------------------------------------------
##@ Local virtual environment & container builds
##----------------------------------------------------------------------------

PROJECT_DIR := producer

.PHONY: lock
lock: ##@ lock the dependencies
	@uv lock --project $(PROJECT_DIR)

.PHONY: dep
dep: ##@ install all project dependencies including dev-dependencies
	@uv venv --python=$(PYTHON_VERSION) --clear --project $(PROJECT_DIR)
	@uv sync --all-groups --project $(PROJECT_DIR)

.PHONY: dep-no-dev
dep-no-dev: ##@ install project dependencies without dev-dependencies
	@uv venv --python=$(PYTHON_VERSION) --clear --project $(PROJECT_DIR)
	@uv sync --no-dev --project $(PROJECT_DIR)

.PHONY: install
# An alias for dep
install:
	@${MAKE} dep

.PHONY: install-no-dev
# An alias for dep-no-dev
install-no-dev:
	@${MAKE} dep-no-dev

.PHONY: clean
clean: ##@ remove the virtual env
	rm -fR ./.venv/ || true
	
##----------------------------------------------------------------------------
##@ Project chores
##----------------------------------------------------------------------------

###########
# linting #
###########
 
.PHONY: lint
lint: ##@ lint the codebase
	@${MAKE} lint-ruff

.PHONY: lint-fix
lint-fix: ##@ attempt to fix all fixable linting issues
	@${MAKE} lint-ruff-fix

.PHONY: lint-ruff
lint-ruff: ##@ lint python files 
	@. .venv/bin/activate && \
		ruff check --config pyproject.toml

.PHONY: lint-ruff-fix
lint-ruff-fix: ##@ fix linting issues in python files 
	@. .venv/bin/activate && \
		ruff check --fix

.PHONY: lint-ruff-fix-unsafe
lint-ruff-fix-unsafe: ##@ fix linting issues in python files that may not work (including fixing relative imports)
	@. .venv/bin/activate && \
		ruff check --fix --unsafe-fixes

#############
# container #
#############

.PHONY: build 
build: ##@ build raw the Airflow with our custom code and packages
	@ docker compose build

.PHONY: up
up: ##@ start the container for local development
	@ docker compose up -d

.PHONY: down
down: ##@ stop the container
	@ docker compose down

###########
# testing #
###########

#...

##############
# formatting #
##############

.PHONY: format
format: ##@ check the codebase for any formatting violations
	@${MAKE} format-ruff

.PHONY: typecheck
typecheck: ##@ run typecheck for python files
	@${MAKE} typecheck-python

.PHONY: format-fix
format-fix: ##@ format the codebase
	@${MAKE} format-ruff-fix

.PHONY: fix
# An alias for format-fix
fix:
	@${MAKE} format-fix

.PHONY: format-ruff
format-ruff: ##@ check the formatting of python files
	@. .venv/bin/activate && \
		ruff format --diff

.PHONY: format-ruff-fix
format-ruff-fix: ##@ format python files
	@. .venv/bin/activate && \
		ruff format

.PHONY: typecheck-python
typecheck-python: ##@ typecheck python files
	@. .venv/bin/activate && \
		ty check

##############
#     CI     #
##############
.PHONY: setup-ci-quality
setup-ci-quality:
	@uv venv --python=$(PYTHON_VERSION) --clear
	@uv sync --only-group quality --frozen
  
.PHONY: quality
quality: ##@ run quality check (lint, format, test)
	@${MAKE} lint
	@${MAKE} format
	@${MAKE} test
