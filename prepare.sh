#!/usr/bin/bash

RET_NO_RPMS_IN_BREW=7
RET_NO_RPMS_IN_REPOS=8
RET_EMPTY_REPOQUERY=11

set -e
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

if [[ "$PROFILE_NAME" == centos-stream-* ]]; then
    # enable CRB and EPEL
    echo "Enabling CRB and EPEL..."

    CENTOS_STREAM_RELEASE=$(sed 's/centos-stream-//' <<< "$PROFILE_NAME")
    EPEL_RELEASE_PACKAGE_URL="https://dl.fedoraproject.org/pub/epel/epel-release-latest-$CENTOS_STREAM_RELEASE.noarch.rpm"
    if [[ "$CENTOS_STREAM_RELEASE" == "9" ]]; then
        EPEL_NEXT_RELEASE_PACKAGE_URL="https://dl.fedoraproject.org/pub/epel/epel-next-release-latest-$CENTOS_STREAM_RELEASE.noarch.rpm"
        rpm -q epel-release && yum -y reinstall "$EPEL_RELEASE_PACKAGE_URL" "$EPEL_NEXT_RELEASE_PACKAGE_URL" || yum -y install "$EPEL_RELEASE_PACKAGE_URL" "$EPEL_NEXT_RELEASE_PACKAGE_URL"
    else
        rpm -q epel-release && yum -y reinstall "$EPEL_RELEASE_PACKAGE_URL" || yum -y install "$EPEL_RELEASE_PACKAGE_URL"
    fi

    yum config-manager --enable crb
    yum config-manager --enable epel
fi
