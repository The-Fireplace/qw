#!/bin/bash

log() {
  echo "$(date +%H:%M:%S) $*" >&2
}

die() {
  log "$@"
  exit 1
}

case $(uname) in
Darwin)
  ncpu=$(sysctl -n hw.ncpu)
  ;;
Linux)
  ncpu=$(nproc)
  ;;
*)
  die "Unknown OS, can't get number of CPUs"
  ;;
esac