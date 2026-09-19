#!/usr/bin/env bash
# Builds TeamStatus from the command line. Run from the repo root on a Mac with Xcode.
set -euo pipefail

CONFIG="${1:-Debug}"

xcodebuild \
  -project TeamStatus.xcodeproj \
  -scheme TeamStatus \
  -configuration "$CONFIG" \
  -derivedDataPath build \
  build

APP="build/Build/Products/$CONFIG/TeamStatus.app"
echo
echo "Built: $APP"
echo "Run it with:  open \"$APP\""
echo "Watch status changes with:"
echo "  log stream --predicate 'subsystem == \"com.company.teamstatus\"' --level info"
