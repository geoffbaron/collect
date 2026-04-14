#!/bin/bash
# Build, increment build number, and push to connected iPhone
set -e

DEVICE="41EE944A-7296-5435-A042-9E1494486AD2"
ARCHIVE="/tmp/CollectDev.xcarchive"

# Increment build number
CURRENT=$(agvtool what-version -terse 2>/dev/null | tr -d '[:space:]')
NEW=$((CURRENT + 1))
agvtool new-version -all "$NEW" > /dev/null 2>&1
echo "Build $CURRENT → $NEW"

# Archive
echo "Building..."
xcodebuild -scheme Collect \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  archive \
  2>&1 | grep -E "error:|warning: prov|ARCHIVE"

# Install
echo "Installing..."
APP_PATH=$(find "$ARCHIVE" -name "Collect.app" | head -1)
xcrun devicectl device install app --device "$DEVICE" "$APP_PATH" 2>&1 | tail -3

# Launch
xcrun devicectl device process launch --device "$DEVICE" com.geoffbaron.collect 2>&1 | tail -1
VERSION=$(grep -m1 "MARKETING_VERSION" Collect.xcodeproj/project.pbxproj | awk -F' = ' '{print $2}' | tr -d '";')
echo "Done — v${VERSION} (${NEW})"
