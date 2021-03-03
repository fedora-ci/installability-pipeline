#!/bin/bash

set -e
# sanity checks
[ -z "$TASK_ID" ] && { echo "TASK_ID missing in the environment"; exit 1; }
[ -z "$PROFILE_NAME" ] && { echo "PROFILE_NAME missing in the environment"; exit 1; }

# install mini-tps
curl --retry 5 --retry-delay 10 --retry-all-errors -Lo /etc/yum.repos.d/mini-tps.repo https://copr.fedorainfracloud.org/coprs/msrb/mini-tps/repo/fedora-rawhide/msrb-mini-tps-fedora-rawhide.repo
dnf install -y mini-tps

# make sure mini-tps can find Koji
# TODO: can mini-tps RPM package provide this configuration automatically?
mkdir -p /var/tmp/mini-tps/ /usr/local/libexec/mini-tps/

cat << EOF > /var/tmp/mini-tps/env
export BREWHUB=https://koji.fedoraproject.org/kojihub
export BREWROOT=https://kojipkgs.fedoraproject.org
EOF

cat << EOF > /usr/local/libexec/mini-tps/installability_runner.sh
#!/bin/bash
set -e
. /var/tmp/mini-tps/env
mtps-run-tests \$@
EOF
chmod +x /usr/local/libexec/mini-tps/installability_runner.sh

. /var/tmp/mini-tps/env

# prepare the system for testing
mtps-prepare-system -p ${PROFILE_NAME} --fixrepo --enablebuildroot
mtps-get-task --recursive --task=$TASK_ID --srpm
mtps-get-task --createrepo --installrepofile --recursive --task=$TASK_ID --download=/var/lib/brew-repo

if [ -n "$ADDITIONAL_TASK_IDS" ]; then
    for additional_task_id in ${ADDITIONAL_TASK_IDS}; do
        mtps-get-task --createrepo --installrepofile --recursive --task=$additional_task_id --download='/var/lib/repo-for-side-tag' --repofilename=side-tag
    done
fi
