#!/bin/bash
flutter build appbundle
pushd build/app/intermediates/merged_native_libs/release/out/lib
zip -r debugsymbols.zip *
popd
echo Built bundle in $PWD/build/app/outputs/bundle/release/app-release.aab
echo Built symbols in $PWD/build/app/intermediates/merged_native_libs/release/out/lib/debugsymbols.zip
