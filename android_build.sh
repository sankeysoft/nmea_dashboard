#!/bin/bash
flutter build appbundle
echo Built bundle in $PWD/build/app/outputs/bundle/release/app-release.aab
# Used in earlier versions of the gradle plugin.
#pushd build/app/intermediates/merged_native_libs/release/out/lib
#zip -r debugsymbols.zip *
#popd
#echo Built symbols in $PWD/build/app/intermediates/merged_native_libs/release/out/lib/debugsymbols.zip
