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

highrc=0
. /var/tmp/mini-tps/env
for method in "install" "update" "downgrade" "remove"; do
    mtps-run-tests $@ --test="$method";
    thisrc=$?
    thisres="$(get_result $thisrc)"
    echo "$method result: $thisres (status code: $thisrc)"
    if [ "$thisrc" -gt "$highrc" ]; then
        highrc="$thisrc"
    fi
done
tmtresult="$(get_result $highrc)"
if [ -n "$TMT_TEST_DATA" ]; then
    # generate the result JSON
    /usr/libexec/mini-tps/viewer/generate-result-json ./mtps-logs > "$TMT_TEST_DATA/result.json"
    # copy the viewer HTML
    cp /usr/share/mini-tps/viewer/viewer.html "$TMT_TEST_DATA/viewer.html"

    cat <<FOE > "$TMT_TEST_DATA/results.yaml"
- name: /installability
  result: $tmtresult
  log:
    - viewer.html
    - ../output.txt
    - result.json
FOE
    echo "running in TMT, wrote $TMT_TEST_DATA/results.yaml"
fi
echo "mtps-run-tests overall result: $tmtresult (status code: $highrc)"
exit $highrc
