#!/bin/bash

set -eu
set -o pipefail

# Constants
qw_source_dir="$(
  cd "$(dirname -- "$0")"
  pwd -P
)" # absolute path
qw_git_commit=$(git --git-dir "$qw_source_dir/.git" describe --always --dirty)
results_dir="$qw_source_dir/results/$qw_git_commit"

# shellcheck source=test-common.sh
. "$qw_source_dir/test-common.sh"

usage() {
  if [[ -n $* ]]; then
    echo "$@" >&2
    echo
  fi
  echo "usage: $0 crawl_source_dir num_runs" >&2
  echo "" >&2
  echo "crawl_source_dir path to crawl/crawl-ref/source" >&2
  echo "num_runs         number of seeds to test" >&2
  if [[ -n $* ]]; then
    exit 1
  fi
}

if [[ ${1:-} == -h || ${1:-} == --help ]]; then
  usage
fi

if [[ $# -lt 2 || $# -gt 2 ]]; then
  usage "Unexpected number of arguments."
fi

if ! [[ -d $1 ]]; then
  usage "crawl_source_dir is not a directory"
fi

if ! [[ $2 =~ ^[0-9]+$ ]]; then
  usage "num_runs is not a number"
fi

log "Hello."

crawl_source_dir=$1
num_runs=$2

renice -n 99 -p $$ # Make sure we're low prio

# Prepare
"$qw_source_dir/test-local-prepare.sh" "$results_dir" "$crawl_source_dir" "$qw_source_dir"


# OK, we are ready to run
"$qw_source_dir/test-local-execute.sh" "$num_runs" "$crawl_source_dir" "$qw_source_dir" "$results_dir"

# Now, collect statistics
log "Collecting statistics..."

"$qw_source_dir/test-local-results.sh" "$results_dir" "$crawl_source_dir" "$qw_source_dir" "$qw_git_commit"