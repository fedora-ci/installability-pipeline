#!/usr/bin/bash

dnf -y copr enable rpmsoftwaremanagement/dnf5-testing
dnf -y install dnf5
# ensure dnf5 is installed from copr since it might be installed from fedora repos
dnf -y update dnf5 --repo=copr:copr.fedorainfracloud.org:rpmsoftwaremanagement:dnf5-testing
