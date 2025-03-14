#!/usr/bin/bash

# not all non-zero return codes are real errors
set +e

RET_NO_RPMS_IN_BREW=7
RET_NO_RPMS_IN_REPOS=8
RET_EMPTY_REPOQUERY=11

[ -z "$TASK_ID" ] && { echo "TASK_ID missing in the environment"; exit 1; }
[ -z "$PROFILE_NAME" ] && { echo "PROFILE_NAME missing in the environment"; exit 1; }

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
    rpm -q epel-release && yum -y reinstall "$EPEL_RELEASE_PACKAGE_URL" || yum -y install "$EPEL_RELEASE_PACKAGE_URL"

    yum config-manager --enable crb
    yum config-manager --enable epel
fi
