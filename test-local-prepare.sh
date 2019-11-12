#!/bin/bash

set -eu
set -o pipefail

results_dir=$1
crawl_source_dir=$2
qw_source_dir=$3

# shellcheck source=test-common.sh
. "$qw_source_dir/test-common.sh"

if [[ -e $results_dir ]]; then
  die "Results dir $results_dir already exists!"
else
  mkdir "$results_dir"
fi

log "Results dir: $results_dir"

# Check binaries exist
if ! [[ -x $crawl_source_dir/crawl ]]; then
  log "Building crawl"
  (
    cd "$crawl_source_dir"
    make -j "ncpu"
  )
fi

if ! [[ -x $crawl_source_dir/util/fake_pty ]]; then
  log "Building fake_pty"
  (
    cd "$crawl_source_dir"
    make util/fake_pty
  )
fi