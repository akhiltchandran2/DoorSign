#!/usr/bin/env bash
# Builds DoorSign from the command line. Run from the repo root on a Mac with Xcode.
set -euo pipefail

CONFIG="${1:-Debug}"

xcodebuild \
  -project DoorSign.xcodeproj \
  -scheme DoorSign \
  -configuration "$CONFIG" \
  -derivedDataPath build \
  build

APP="build/Build/Products/$CONFIG/DoorSign.app"
echo
echo "Built: $APP"
echo "Run it with:  open \"$APP\""
echo "Watch status changes with:"
echo "  log stream --predicate 'subsystem == \"com.company.doorsign\"' --level info"
