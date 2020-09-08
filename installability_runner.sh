#!/bin/bash

set -e

. env.sh 

mtps-run-tests $@
