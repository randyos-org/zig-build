#!/usr/bin/env bash
#cSpell:enableCompoundWords
# Full local build: stage3 (release), stage4 (debug), then ZLS.
. ./common.sh

./build-stage3.sh || exit 1

./build-stage4-debug.sh || exit 1
echo Zig stages 3 and 4 successfully built!

./build-zls.sh || exit 1
echo ZLS successfully built!
