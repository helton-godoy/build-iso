set shell := ["bash", "-euo", "pipefail", "-c"]

default:
  @just --list

help:
  make help

download-zbm:
  make download-zbm

setup-docker:
  make setup-docker

build-iso:
  make build-iso

clean:
  make clean

setup-vm:
  make setup-vm

vm-list:
  make vm-list

vm-destroy:
  make vm-destroy

vm-destroy-all:
  make vm-destroy-all

test-vm-uefi:
  make test-vm-uefi

test-vm-bios:
  make test-vm-bios

test-vm-all:
  make test-vm-all

vm-connect-uefi:
  make vm-connect-uefi

vm-connect-bios:
  make vm-connect-bios

vm-boot-disk-uefi:
  make vm-boot-disk-uefi

vm-boot-disk-bios:
  make vm-boot-disk-bios

docs:
  make docs

docs-installer:
  make docs-installer

docs-dev:
  make docs-dev

docs-tests:
  make docs-tests

docs-all:
  make docs-all

docs-markdown:
  make docs-markdown

docs-stats:
  make docs-stats

verify-docs:
  make verify-docs

validate-ad:
  make validate-ad

ad-precheck:
  make ad-precheck

validate-configs:
  make validate-configs

lint:
  make lint

plan-list:
  make plan-list

plan-archive file:
  make plan-archive FILE="{{file}}"
