#!/bin/bash

# This used to be a lot more complicated when the debig symbols weren't
# generated correctly.
flutter build appbundle
PARENT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &> /dev/null && pwd)"
echo Built bundle in $PARENT_DIR/build/app/outputs/bundle/release/app-release.aab
