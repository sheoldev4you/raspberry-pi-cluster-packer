#!/usr/bin/env bash

set -e

mount -t binfmt_misc binfmt_misc /proc/sys/fs/binfmt_misc/

./cluster.sh " $@ "