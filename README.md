# installability-pipeline

This repository contains the definition of the Installability CI pipeline.

This pipeline tries to install, update, downgrade and remove RPM packages and publishes results via [CI Messages](https://pagure.io/fedora-ci/messages).

## Test definition

The generic installability test is described in a [Flexible Metadata Format](https://pagure.io/fedora-ci/metadata).

The actual definition lives in the [installability.fmf](installability.fmf) file.

## Test execution

The pipeline delegates the test execution to the [Testing Farm](https://api.dev.testing-farm.io). The pipeline only collects, archive and report results.

However, it is possible to run the installability test locally. To do that, clone this repository and run one of the following commands:

```shell
$ tmt run -a \
  -e TASK_ID=43617203 \
  -e PROFILE_NAME=fedora-43 \
  provision --how virtual --image fedora
(running in a virtual environment)
$ tmt run -a \
  -e TASK_ID=43617203 \
  -e PROFILE_NAME=fedora-43 \
  provision --how container --image fedora:rawhide
(running in a container environment)
```

Where `TASK_ID` is the koji build you want to test, and `PROFILE_NAME` is the environment which must match
the provision image used.
