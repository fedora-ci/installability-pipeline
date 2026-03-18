#!/usr/bin/python3
# /// script
# ///

import argparse
import logging
import os
import subprocess
from pathlib import Path

logging.basicConfig(level="INFO")
logger = logging.getLogger(Path(__file__).name)

REPO_NAME = "installability-test"
REPO_PATH = Path(f"/etc/yum.repos.d/{REPO_NAME}.repo")
REPO_CONTENT = """
[{repo_name}]
name=Installability repo
baseurl=file://{repo_path}/
enabled=1
gpgcheck={with_gpg_check}
"""


def install_repo(repo_path: Path, with_gpg_check: bool = False) -> None:
    logger.info(f"Installing repo into: {REPO_PATH}")
    content = REPO_CONTENT.format(
        repo_path=repo_path,
        with_gpg_check=1 if with_gpg_check else 0,
        repo_name=REPO_NAME,
    )
    REPO_PATH.write_text(content)
    logger.info(f"Content:\n{content}")


def koji_task(args: argparse.Namespace, repo_path: Path) -> None:
    logger.info(f"""
    Preparing environment for:
    Koji task: {args.koji_task_id}
    Arch: {args.arch}
    """)

    arch_args = set()
    if args.arch:
        arch_args.add(f"--arch={args.arch}")
        arch_args.add("--arch=noarch")

    logger.info("Downloading artifacts from Koji")
    subprocess.run(
        [
            "koji",
            "download-task",
            args.koji_task_id,
            *arch_args,
        ],
        cwd=repo_path,
        check=True,
    )

    logger.info(f"Creating the repo: {repo_path}")
    subprocess.run(
        [
            "createrepo",
            f"{repo_path}",
        ],
        check=True,
    )
    install_repo(repo_path=repo_path)


def bodhi_update(args: argparse.Namespace, repo_path: Path) -> None:
    logger.info(f"""
    Preparing environment for:
    Bodhi update: {args.bodhi_update_id}
    Arch: {args.arch}
    """)

    arch_args = []
    if args.arch:
        arch_args.append(f"--arch={args.arch}")

    logger.info("Downloading artifacts from Bodhi")
    res = subprocess.run(
        [
            "bodhi",
            "updates",
            "download",
            # TODO: we should enable the gpg checks, but we need to submit the jobs
            #  after the signing finished
            "--no-gpg",
            f"--updateid={args.bodhi_update_id}",
            *arch_args,
        ],
        cwd=repo_path,
    )
    # Naive handling for older bodhi that does not recognize --no-gpg
    # TODO: Find a better way to do this
    if res.returncode != 0:
        subprocess.run(
            [
                "bodhi",
                "updates",
                "download",
                f"--updateid={args.bodhi_update_id}",
                *arch_args,
            ],
            cwd=repo_path,
            check=True,
        )
    # bodhi updates download does not fail on failed downloads.
    # for now we just manually check that there are at least a rpm present
    rpms = list(repo_path.glob("*.rpm"))
    if not rpms:
        logger.error("No rpms were downloaded? Something bad is happening!")
        raise SystemExit(1)

    logger.info(f"Creating the repo: {repo_path}")
    subprocess.run(
        [
            "createrepo",
            f"{repo_path}",
        ],
        check=True,
    )
    install_repo(repo_path=repo_path)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--arch", default=None)
    parser.add_argument(
        "--workdir",
        type=Path,
        default=os.environ.get("TMT_PLAN_DATA", "."),
    )

    actions = parser.add_subparsers(required=True, dest="action")

    koji_parser = actions.add_parser("koji-task")
    koji_parser.add_argument("koji_task_id")

    bodhi_parser = actions.add_parser("bodhi-update")
    bodhi_parser.add_argument("bodhi_update_id")

    args = parser.parse_args()

    repo_path: Path = args.workdir / "repo"
    repo_path.mkdir(exist_ok=True)

    try:
        if args.action == "koji-task":
            koji_task(args, repo_path)
        elif args.action == "bodhi-update":
            bodhi_update(args, repo_path)
        else:
            raise NotImplementedError
    except SystemExit:
        raise
    except subprocess.CalledProcessError:
        logger.error("Prepare failed")
        raise SystemExit(1)
    except Exception as exc:
        logger.error("Unexpected prepare failure", exc_info=exc)
        raise SystemExit(2)
