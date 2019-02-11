#!/bin/bash

# Script to run a mass test of qw on an ec2 instance.
# Meant to be run as user-data on a spot instance which has an
# instance profile that allows uploading to the specified bucket.

# TODO:
# Add a timeout watchdog to catch qw crashes.

set -eu
set -o pipefail

# Parameters
QW_BRANCH="improvements"
S3_BUCKET="aj-qw-results"
START_SEED="1"
NUM_RUNS="1000"

# Constants
NPROC=$(nproc)

cd /home/ec2-user

# Build crawl
yum -y install git gcc gcc-c++ make bison flex ncurses-devel sqlite-devel zlib-devel pkgconfig python-yaml
git clone https://github.com/crawl/crawl.git
(
  cd crawl/crawl-ref/source/
  git submodule update --init
  make util/fake_pty
  make -j "$NPROC"
)

git clone https://github.com/alexjurkiewicz/qw.git
(
  cd qw
  git checkout -b "$QW_BRANCH"
  git reset --hard "origin/$QW_BRANCH"
)

# Start testing
seq "$START_SEED" "$((START_SEED + NUM_RUNS))" | \
    xargs -t -P "$NPROC" -n 1 \
        crawl/crawl-ref/source/util/fake_pty \
        crawl/crawl-ref/source/crawl -rc qw/qw.rc -seed

# Upload results
aws s3 cp --recursive morgue "s3://$S3_BUCKET/$HOSTNAME/"
