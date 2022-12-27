#!/bin/bash
#
# Copyright 2022 Jody Sankey
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENCE.md file for details.
#
# Simple helper to safely force-clear all contents in the build
# directory.
#
# Created this because because something around Android emulator
# was creating files which could not be deleted from an NFS client
# and its a bit scary to be regularly having to run `rm -rf *` on
# the server without any protection on the correct directory being
# selected.
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

if [ -d "$SCRIPT_DIR/build" ]; then
  rm -rvf $SCRIPT_DIR/build/*
else
  echo "Build directory $DIRECTORY/build does exist."
fi
