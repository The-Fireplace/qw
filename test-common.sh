#!/bin/bash

log() {
  echo "$(date +%H:%M:%S) $*" >&2
}

die() {
  log "$@"
  exit 1
}