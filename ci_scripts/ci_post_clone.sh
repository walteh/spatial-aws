#!/bin/bash

#  ci_post_clone.sh
#  spatial-aws
#
#  Created by walter on 6/2/24.
#
#  update the build version to the latest git tag

latestTag=""

function check() {
  # Get the latest tags from git
  echo "Fetching tags from git"
  git fetch --tags

  # Get the highest semver tag
  latestTag=$(git tag --merged HEAD | grep -E '^v.*$' | sort -V | tail -n 1)
  echo "latest tag: $latestTag"
}

# Retry mechanism
attempt=0
max_attempts=20

while [ -z "$latestTag" ] && [ $attempt -lt $max_attempts ]; do
  attempt=$((attempt + 1))
  echo "Attempt $attempt of $max_attempts"
  
  check

  if [ -z "$latestTag" ]; then
    if [ $attempt -lt $max_attempts ]; then
      echo "No tags found. Retrying in 15 seconds..."
      sleep 15
    else
      echo "No tags found after $max_attempts attempts. Exiting."
      exit 1
    fi
  fi
done

# We are inside the ci_scripts folder in CI, so need to refer from there
projectPath=../spatial-aws.xcodeproj/project.pbxproj

# Check if the Xcode project file exists
if [ ! -f "$projectPath" ]; then
  echo "file not found at $projectPath"
  exit 1
fi

# Remove the 'v' prefix, if present, and anything after the first '-'
latestTag=$(echo "$latestTag" | sed -E 's/^v//g' | sed -E 's/-.*//g')

# Update the MARKETING_VERSION in the Xcode project file
sed -i '' "s/MARKETING_VERSION = [0-9]*\.[0-9]*\.[0-9]*;/MARKETING_VERSION = $latestTag;/g" "$projectPath"
echo "updated version number to $latestTag"
