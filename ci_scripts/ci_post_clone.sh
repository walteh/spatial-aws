#!/bin/sh

#  ci_post_clone.sh
#  spatial-aws
#
#  Created by walter on 6/2/24.
#
#  update the build version to the latest git tag

# Get the highest semver tag
latestTag=$(git tag -l | sort -V | tail -n 1)
echo "latest tag: $latestTag"

# Check if latestTag is not empty
if [ -z "$latestTag" ]; then
  echo "No tags found. Exiting."
  exit 1
fi

# Update the version number in Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $latestTag" "${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"
echo "updated version number to $latestTag"

