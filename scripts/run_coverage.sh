#!/bin/bash
set -e

PROJDIR=$(dirname "$0")/..
flutter test --coverage $PROJDIR
# Sigh, genhtml is buggy with explicit ouput directory.
#genhtml $PROJDIR/coverage/lcov.info --source-directory $PROJDIR --output-directory $PROJDIR/coverage
pushd $PROJDIR
genhtml coverage/lcov.info --source-directory $PROJDIR --output-directory coverage
popd
firefox $PROJDIR/coverage/index.html
