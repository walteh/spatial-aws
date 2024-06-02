#!/bin/bash

#  ci_post_clone.sh
#  spatial-aws
#
#  Created by walter on 6/2/24.
#
#  update the build version to the latest git tag

# Get the latest tags from git
echo "Fetching tags from git"
git fetch --tags


# Get the highest semver tag
latestTag=$(git tag --merged HEAD | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n 1)
echo "latest tag: $latestTag"

# Check if latestTag is not empty
if [ -z "$latestTag" ]; then
  echo "No tags found. Exiting."
  exit 1
fi

# Resolve the Info.plist path
projectPath=./spatial-aws.xcodeproj/project.pbxproj

# Check if the Info.plist file exists
if [ ! -f "$projectPath" ]; then
  echo "Error: Info.plist file not found at $projectPath"
  exit 1
fi

# version no v
latestTag=${latestTag:1}

# Update the version number in Info.plist
sed -i '' "s/MARKETING_VERSION = [0-9]*\.[0-9]*\.*[0-9]*;/MARKETING_VERSION = $latestTag;/g" "$projectPath"
echo "updated version number to $latestTag"
