#!/usr/bin/python3
# /// script
# dependencies = [
#     "ruamel.yaml",
# ]
# ///

from __future__ import annotations

import argparse
import enum
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

from ruamel.yaml import YAML, Representer

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


@yaml.register_class
class Result(enum.IntEnum):
    """
    Results are
    """
    PENDING = 0
    SKIP = 1
    PASS = 2
    INFO = 3
    WARN = 4
    FAIL = 5
    ERROR = 6

    @classmethod
    def to_yaml(cls, representer: Representer, node: Result) -> str:
        return representer.represent_str(node.name.lower())

class TmtResult(TypedDict):
    """
    Subset of tmt result that we will use.

    See https://tmt.readthedocs.io/en/stable/spec/results.html
    """

    name: str
    result: Result
    log: list[str]
    duration: NotRequired[str]
    subresult: NotRequired[list[TmtResult]]


result = TmtResult(
    name="/",
    result=Result.PENDING,
    log=[
        "../output.txt",
    ],
    subresult=[
        TmtResult(
            name=method,
            result=Result.PENDING,
            log=[
                f"output-{method}.txt",
            ],
        )
        for method in TEST_CASES
    ],
)


def update_results(workdir: Path) -> None:
    with (workdir / "results.yaml").open("w") as f:
        yaml.dump([result], f)

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
    args.workdir: Path
    logs_dir: Path = args.workdir / MTPS_LOGS_DIR
    logs_dir.mkdir(exist_ok=True)
    os.environ["LOGS_DIR"] = str(logs_dir)

    update_results(args.workdir)
    failed = False
    for method in TEST_CASES:
        subresult = next(sr for sr in result["subresult"] if sr["name"] == method)
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
            subresult["result"] = Result.FAIL
        else:
            subresult["result"] = Result.PASS
        subresult["duration"] = format_duration(duration)
        (args.workdir / f"output-{method}.txt").write_text(res.stdout)
        subresult["log"].extend(
            str(log_path.relative_to(args.workdir))
            for log_path in logs_dir.glob(f"*-*-{method}-*.log")
        )
        update_results(args.workdir)
    # Report the overall results
    if failed:
        result["result"] = Result.FAIL
    else:
        result["result"] = Result.PASS
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
        result["log"].extend(["viewer.html", "result.json"])
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
