# installability-pipeline

This repository contains the definition of the Installability CI pipeline.

This pipeline tries to install, upgrade, downgrade and remove RPM packages and publishes results via [CI Messages](https://pagure.io/fedora-ci/messages).

> ** **Important:** ** Structure of the branches in this repository resembles branches in dist-git, i.e. master branch contains the pipeline definition for Fedora Rawhide, [f32](https://github.com/fedora-ci/installability-pipeline/tree/f32) branch is for Fedora 32, etc.

## Test definition

The generic installability test is described in a [Flexible Metadata Format](https://pagure.io/fedora-ci/metadata).

The actual definition lives in the [installability.fmf](./installability.fmf) file.

## Test execution

The pipeline delegates the test execution to the Testing Farm (TODO: link once available). The pipeline only collects, archive and report results.

However, it is possible to run the installability test locally. To do that, clone this repository and run following command:

TODO: this is outdated... update here as well in generic-tests repository

```shell
tmt run -ae TASK_ID=43617203 -e RELEASE_ID=Fedora-32 -d provision -h libvirt.testcloud -i URL_TO_COMPOSE plan --name /installability
```

The command above will run installability on a Koji build with the [task Id "43617203"](https://koji.fedoraproject.org/koji/taskinfo?taskID=43617203) (f32-backgrounds-32.1.3-1.fc32) and it tests it in the context of Fedora 32.
