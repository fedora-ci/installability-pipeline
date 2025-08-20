#!/usr/bin/bash

# not all non-zero return codes are real errors
set +e

RET_NO_RPMS_IN_BREW=7
RET_NO_RPMS_IN_REPOS=8
RET_EMPTY_REPOQUERY=11

[ -z "$TMT_VERSION" ] && { echo "Please run using tmt run. See README.md."; exit 1; }
[[ -z "$TASK_ID" && -z "$PACKIT_COPR_RPMS" ]] && { echo "TASK_ID or PACKIT_COPR_RPMS missing in the environment"; exit 1; }
[ -z "$PROFILE_NAME" ] && { echo "PROFILE_NAME missing in the environment"; exit 1; }

# prepare the system for testing
mtps-prepare-system -p "${PROFILE_NAME}" --fixrepo --enablebuildroot
if [ -n "$TASK_ID" ]; then
  mtps-get-task --createrepo --installrepofile --recursive --task="$TASK_ID" --download=/var/lib/brew-repo
  rc="$?"
  if [[ "$rc" -ne 0 ]]; then
      if [[ "$rc" -eq $RET_NO_RPMS_IN_BREW || "$rc" -eq $RET_NO_RPMS_IN_REPOS || "$rc" -eq $RET_EMPTY_REPOQUERY ]]; then
          echo "Skipped. See 'download build' (or /prepare) logs for info." > ${TMT_PLAN_DATA}/SKIP_TEST
      else  # unknown error
          exit "$rc"
      fi
  fi

  if [ -n "$ADDITIONAL_TASK_IDS" ]; then
      for additional_task_id in ${ADDITIONAL_TASK_IDS}; do
          mtps-get-task --createrepo --installrepofile --recursive --task="$additional_task_id" --download='/var/lib/repo-for-side-tag' --repofilename=side-tag
      done
  fi
else
  # Get a normalized copr_id, replacing the `/` with `-`
  copr_id=$(echo $PACKIT_COPR_PROJECT |	sed "s|/|-|")
  # Replicate the logic with the packit copr rpms
  createrepo --database /var/share/test-artifacts
  cat <<EOF > /etc/yum.repos.d/copr-${copr_id}.repo
[copr-$copr_id]
name=Repo for $PACKIT_COPR_PROJECT copr build
baseurl=file:///var/share/test-artifacts
enabled=1
gpgcheck=0
EOF
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
