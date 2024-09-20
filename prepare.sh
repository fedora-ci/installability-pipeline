#!/usr/bin/bash

RET_NO_RPMS_IN_BREW=7
RET_NO_RPMS_IN_REPOS=8
RET_EMPTY_REPOQUERY=11

set -e
set -x
# sanity checks
[ -z "$TASK_ID" ] && { echo "TASK_ID missing in the environment"; exit 1; }
[ -z "$PROFILE_NAME" ] && { echo "PROFILE_NAME missing in the environment"; exit 1; }

# install mini-tps
dnf -y copr enable @osci/mini-tps
dnf -y install mini-tps
dnf -y copr disable @osci/mini-tps

# make sure mini-tps can find Koji
# TODO: can mini-tps RPM package provide this configuration automatically?
mkdir -p /var/tmp/mini-tps/ /usr/local/libexec/mini-tps/

cat << EOF > /var/tmp/mini-tps/env
export BREWHUB=https://koji.fedoraproject.org/kojihub
export BREWROOT=https://kojipkgs.fedoraproject.org
EOF

cp installability_runner.sh /usr/local/libexec/mini-tps/installability_runner.sh
chmod +x /usr/local/libexec/mini-tps/installability_runner.sh

. /var/tmp/mini-tps/env

# from now on, not all non-zero return codes are real errors
set +e

# prepare the system for testing
mtps-prepare-system -p "${PROFILE_NAME}" --fixrepo --enablebuildroot

if [[ "$PROFILE_NAME" == centos-stream-* ]]; then
    # enable CRB and EPEL
    echo "Enabling CRB and EPEL..."
    yum config-manager --enable crb
    yum -y install epel-release
fi

mtps-get-task --createrepo --installrepofile --recursive --task="$TASK_ID" --download=/var/lib/brew-repo
rc="$?"
if [[ "$rc" -ne 0 ]]; then
    if [[ "$rc" -eq $RET_NO_RPMS_IN_BREW || "$rc" -eq $RET_NO_RPMS_IN_REPOS || "$rc" -eq $RET_EMPTY_REPOQUERY ]]; then
        echo "Skipped. See 'download build' (or /prepare) logs for info." > SKIP_TEST
    else  # unknown error
        exit "$rc"
    fi
fi

if [ -n "$ADDITIONAL_TASK_IDS" ]; then
    for additional_task_id in ${ADDITIONAL_TASK_IDS}; do
        mtps-get-task --createrepo --installrepofile --recursive --task="$additional_task_id" --download='/var/lib/repo-for-side-tag' --repofilename=side-tag
    done
fi
