#!/bin/bash

get_result () {
    local result
    case $1 in
        0) result="pass" ;;
        1) result="fail" ;;
        *) result="error" ;;
    esac
    echo "$result"
}

TESTRUN_ID="$(date +%H%M%S)"
LOGS_DIR=${LOGS_DIR:-${TMT_TEST_DATA:+${TMT_TEST_DATA}/}mtps-logs}
mkdir -p "${LOGS_DIR}"

if [[ -f ${TMT_PLAN_DATA:+${TMT_PLAN_DATA}/}SKIP_TEST ]]; then
  # The SKIP_TEST file contains a reason why the prepare.sh ended unexpectedly.
  # Copy it to a log file which can be parsed by generate-result-json
  # (to show the reason in viewer.html)
  cat ${TMT_PLAN_DATA:+${TMT_PLAN_DATA}/}SKIP_TEST
  cp ${TMT_PLAN_DATA:+${TMT_PLAN_DATA}/}SKIP_TEST "${LOGS_DIR}/SKIP-${TESTRUN_ID}-install-package.log"
  tmtresult="skip"
else
  highrc=0
  for method in "install" "update" "downgrade" "remove"; do
      mtps-run-tests "$@" --test="$method";
      thisrc=$?
      thisres="$(get_result $thisrc)"
      echo "$method result: $thisres (status code: $thisrc)"
      if [ "$thisrc" -gt "$highrc" ]; then
          highrc="$thisrc"
      fi
  done
  tmtresult="$(get_result $highrc)"
fi

if [ -n "$TMT_TEST_DATA" ]; then
    # generate the result JSON
    /usr/libexec/mini-tps/viewer/generate-result-json "$LOGS_DIR" > "$TMT_TEST_DATA/result.json"
    # copy the viewer HTML
    cp /usr/share/mini-tps/viewer/viewer.html "$TMT_TEST_DATA/viewer.html"

    cat <<FOE > "$TMT_TEST_DATA/results.yaml"
- name: /installability
  result: $tmtresult
  log:
    - ../output.txt
    - viewer.html
    - result.json
FOE
    echo "running in TMT, wrote $TMT_TEST_DATA/results.yaml"
fi
echo "mtps-run-tests overall result: $tmtresult (status code: $highrc)"
exit $highrc
