#!/bin/bash

set -e

# install mini-tps
curl -Lo /etc/yum.repos.d/mini-tps.repo https://copr.fedorainfracloud.org/coprs/msrb/mini-tps/repo/fedora-rawhide/msrb-mini-tps-fedora-rawhide.repo
dnf install -y mini-tps

# import config; needed so mtps-* commands work correctly
. env.sh

# prepare the system for testing
mtps-prepare-system -p fedora-${RELEASE_ID:1} --fixrepo --enablebuildroot
mtps-get-task --recursive --task=$TASK_ID --srpm
mtps-get-task --createrepo --installrepofile --recursive --task=$TASK_ID --download=/var/lib/brew-repo

if [ -n "$ADDITIONAL_TASK_IDS" ]; then
    for additional_task_id in ${ADDITIONAL_TASK_IDS}; do
        mtps-get-task --createrepo --installrepofile --recursive --task=$additional_task_id --download='/var/lib/repo-for-side-tag' --repofilename=side-tag
    done
fi
