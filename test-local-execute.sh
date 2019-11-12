#!/bin/bash

set -eu
set -o pipefail

num_runs=$1
crawl_source_dir=$2
qw_source_dir=$3
results_dir=$4

start_seed=1

# shellcheck source=test-common.sh
. "$qw_source_dir/test-common.sh"

# Sanity check qw.rc
if ! grep -qE ': AUTO_START = true' "$qw_source_dir/qw.rc"; then
  die "qw.rc doesn't have AUTO_START = true"
fi

if [[ -z ${TERM:-} ]]; then
  log "Setting TERM=xterm"
  export TERM=xterm
fi

log "Building Crawl DB"
if ! "$crawl_source_dir/crawl" -builddb &>/dev/null; then
  die "Failed to run crawl -builddb"
fi

log "Running qw"
# Explanation of the more esoteric parallel args:
# jobs: Maximum number of jobs. (n% the number of cores). We want way more
#   job slots than cores because some qw sometimes hangs, using no CPU.
# limit: Before starting a job, only start it if there are fewer than n
#   runnable processes on the system (runnable process = in R or D state,
#   according to ps). Ideally, we would have exactly as many crawl processes
#   running as there are non-saturated cores, (any more will be less efficient
#   due to task switching overhead). On a dedicated test machine this should
#   probably be equal to number of cores + 1 or so.
# timeout: if a job runs this long, kill it. qw sometimes crashes, so this
#   catches that.
# termseq: if a job needs to be killed (because it timed out), follow these
#   steps. send SIGTERM, wait 5secs, if it's still running, send SIGKILL, wait
#   100ms and then continue
seq "$start_seed" "$((start_seed + num_runs - 1))" |
  parallel \
    --bar -n 1 -I {} \
    --jobs 200% --limit "load $((ncpu * 5 / 4))" --delay 1s \
    --timeout "1h" --termseq TERM,5000,KILL,100 \
    -- \
    "$crawl_source_dir/util/fake_pty" \
    "$crawl_source_dir/crawl" \
    -seed {} -name qw{} -rc "$qw_source_dir/qw.rc" \
    -dir "$results_dir" ||
  true # We don't care if some jobs fail