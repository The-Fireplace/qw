#!/bin/bash

set -eu
set -o pipefail

results_dir=$1
crawl_source_dir=$2
qw_source_dir=$3
git_commit=$4
# shellcheck source=test-common.sh
. "$qw_source_dir/test-common.sh"

cd "$results_dir"
n_morgues=$(find morgue -name 'morgue-*.txt' | wc -l | sed 's/^[[:space:]]*//')
n_crashes=$(find morgue -name 'crash-*.txt' | wc -l | sed 's/^[[:space:]]*//')
n_total=$((n_morgues + n_crashes))
n_crashes_pct=$(bc <<<"scale=2; $n_crashes/$n_total*100")
# "|| true" is because of pipefail
n_wins=$( (grep -l 'Escaped with the Orb!' morgue/morgue-*.txt || true) | wc -l | sed 's/^[[:space:]]*//')
n_wins_pct=$(bc <<<"scale=2; $n_wins/$n_total*100")
if [[ $n_morgues -gt 1 ]]; then
  all_scores=$(sed -r 's/.*sc=([[:digit:]]+):.*/\1/' saves/scores-seeded)
  mean=$(( $(echo "$all_scores" | paste -s -d+ - | bc) / n_morgues ))
  median=$(echo "$all_scores" | sed "$((n_morgues / 2))q;d") # slightly off when n_morgues is even
else
  # Zero or one successful runs. Just don't bother with either of these.
  mean="-1"
  median="-1"
fi

# Build the qw config document. This is a bit complex
qw_config=""
while read -r line; do
  key=$(echo $line | cut -d\  -f2)
  val=$(echo $line | sed 's/: [_A-Z]* = //' | sed 's/^"//' | sed 's/"$//' | sed 's/"/\\"/g')
  # Note the newline
  qw_config="$qw_config    \"$key\": \"$val\",
"
done < <(grep -E '^: [A-Z]' "$qw_source_dir/qw.rc" | grep -v ENUM | grep -v ATT_ | grep -v LOS)
# Add the combo, without a trailing comma
# Note the newline
qw_config="${qw_config}    \"combo\": \"$(grep -E '^combo' "$qw_source_dir/qw.rc" | awk '{print $3}')\"
"

crawl_version_short=$("$crawl_source_dir/crawl" -version | head -1 | cut -d\  -f3)
crawl_version_full=$("$crawl_source_dir/crawl" -version | tr '\n' '\0' | sed 's/\00/\\n/g')

log "Total games: $n_total"
log "Total crashes $n_crashes ($n_crashes_pct%)"
log "Total wins: $n_wins ($n_wins_pct%)"
log "Mean score: $mean"
log "Median score: $median"

results_file="$results_dir/summary.json"
log "Writing summary to $results_file"

cat >"$results_file" <<EOF
{
  "qw_sha": "$git_commit",
  "qw_config": {
${qw_config}
  },
  "crawl_version_short": "$crawl_version_short",
  "crawl_version_full": "$crawl_version_full",
  "games": $n_total,
  "losses": $((n_total - n_crashes - n_wins)),
  "crashes": $n_crashes,
  "wins": $n_wins,
  "score_mean": $mean,
  "score_median": $median,
  "start_seed": 1
}
EOF