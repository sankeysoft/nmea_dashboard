#!/bin/bash

# This used to be a lot more complicated when the debig symbols weren't
# generated correctly.
flutter build appbundle
echo Built bundle in $PWD/build/app/outputs/bundle/release/app-release.aab
