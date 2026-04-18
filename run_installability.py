#!/usr/bin/python3
# /// script
# dependencies = [
#     "ruamel.yaml",
# ]
# ///

from __future__ import annotations

import argparse
import logging
import os
import shutil
import subprocess
import sys
import datetime
from pathlib import Path
from shutil import which
from typing import TypedDict, Literal

if sys.version_info >= (3, 11):
    from typing import NotRequired
else:
    from typing_extensions import NotRequired

from ruamel.yaml import YAML

logging.basicConfig(level="INFO")
logger = logging.getLogger(Path(__file__).name)

yaml = YAML()

REPO_NAME = "installability-test"
MTPS_LIBEXEC = Path("/usr/libexec/mini-tps")
MTPS_LOGS_DIR = "mtps-logs"
MTPS_VIEWER_HTML = Path("/usr/share/mini-tps/viewer/viewer.html")
TEST_CASES = [
    "install",
    "update",
    "downgrade",
    "remove",
]

can_selinux = bool(which("getenforce"))


class Result(TypedDict):
    """
    Subset of tmt result that we will use.

    See https://tmt.readthedocs.io/en/stable/spec/results.html
    """

    name: str
    result: Literal["pass", "fail", "info", "warn", "error", "skip", "pending"]
    log: list[str]
    duration: NotRequired[str]


results = {
    f"/{method}": Result(
        name=f"/{method}",
        result="pending",
        log=[
            f"output-{method}.txt",
        ],
    )
    for method in TEST_CASES
}
results["/"] = Result(
    name="/",
    result="pending",
    log=[
        "../output.txt",
    ],
)


def update_results(workdir: Path) -> None:
    with (workdir / "results.yaml").open("w") as f:
        yaml.dump(list(results.values()), f)

def format_duration(duration: datetime.timedelta) -> str:
    """
    Helper duration format from ``tmt.utils``
    """

    # A helper variable to hold the duration while we cut away days, hours and seconds.
    counter = int(duration.total_seconds())

    hours, counter = divmod(counter, 3600)
    minutes, seconds = divmod(counter, 60)

    return f'{hours:02}:{minutes:02}:{seconds:02}'


def main(args: argparse.Namespace) -> None:
    logs_dir: Path = args.workdir / MTPS_LOGS_DIR
    logs_dir.mkdir(exist_ok=True)
    os.environ["LOGS_DIR"] = str(logs_dir)

    update_results(args.workdir)
    failed = False
    for method in TEST_CASES:
        logger.info(f"Running mtps-run-tests: {method}")
        mtps_args = [
            f"--repo={REPO_NAME}",
            f"--test={method}",
            "--skiplangpack",
            f"--selinux={1 if can_selinux else 0}",
        ]
        if method not in ("downgrade",):
            mtps_args.append("--critical")
        start = datetime.datetime.now(datetime.timezone.utc)
        res = subprocess.run(
            [
                "mtps-run-tests",
                *mtps_args,
            ],
            text=True,
            stdout=subprocess.PIPE,
        )
        duration = datetime.datetime.now(datetime.timezone.utc) - start
        # Report the subresult
        if res.returncode > 0:
            failed = True
            results[f"/{method}"]["result"] = "fail"
        else:
            results[f"/{method}"]["result"] = "pass"
        results[f"/{method}"]["duration"] = format_duration(duration)
        args.workdir: Path
        (args.workdir / f"output-{method}.txt").write_text(res.stdout)
        results[f"/{method}"]["log"].extend(
            str(log_path.relative_to(args.workdir))
            for log_path in logs_dir.glob(f"*-*-{method}-*.log")
        )
        update_results(args.workdir)
    # Report the overall results
    if failed:
        results["/"]["result"] = "fail"
    else:
        results["/"]["result"] = "pass"
    update_results(args.workdir)
    logger.info("Generating results.json")
    results_json = subprocess.run(
        [MTPS_LIBEXEC / "viewer/generate-result-json", logs_dir],
        text=True,
        stdout=subprocess.PIPE,
    )
    if results_json.returncode == 0:
        (args.workdir / "result.json").write_text(results_json.stdout)
        shutil.copy(MTPS_VIEWER_HTML, args.workdir / "viewer.html")
        results["/"]["log"].extend(["viewer.html", "result.json"])
        update_results(args.workdir)

    logger.info("Finished running mtps-run-tests")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Actually run installability (mtps-run-tests)"
    )
    parser.add_argument(
        "--workdir",
        type=Path,
        default=os.environ.get("TMT_TEST_DATA", "."),
    )

    args = parser.parse_args()

    try:
        main(args)
    except (subprocess.CalledProcessError, SystemExit):
        logger.error("Installability failed!")
        raise SystemExit(1)
    except Exception as exc:
        logger.error("Unexpected installability failure", exc_info=exc)
        raise SystemExit(2)
