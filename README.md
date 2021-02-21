# installability-pipeline

This repository contains the definition of the Installability CI pipeline.

This pipeline tries to install, update, downgrade and remove RPM packages and publishes results via [CI Messages](https://pagure.io/fedora-ci/messages).

## Test definition

The generic installability test is described in a [Flexible Metadata Format](https://pagure.io/fedora-ci/metadata).

The actual definition lives in the [installability.fmf](./installability.fmf) file.

## Test execution

The pipeline delegates the test execution to the Testing Farm (TODO: link once available). The pipeline only collects, archive and report results.

However, it is possible to run the installability test locally. To do that, clone this repository and run following command:

```shell
tmt run -ae TASK_ID=43617203 -e RELEASE_ID=Fedora-32 -d provision --how virtual.testcloud --image fedora plan --name /installability
```

The command above will run the installability test on a Koji build with the [task Id "43617203"](https://koji.fedoraproject.org/koji/taskinfo?taskID=43617203) (f32-backgrounds-32.1.3-1.fc32) and it tests it in the context of the latest Fedora.
