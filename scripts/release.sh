#!/usr/bin/env bash

# https://unix.stackexchange.com/a/9443/119653
reverse () {
    local line
    if IFS= read -r line
    then
        reverse
        printf '%s\n' "$line"
    fi
}

# Current directory
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IS_TAG=$(git tag -l --points-at HEAD)
RELEASE_TAG=$(git describe --tags $(git rev-list --tags --max-count=1))
RELEASE=$(echo $RELEASE_TAG | awk -F- '{print $1}')
TIMESTAMP=$(date +%Y%m%d%H%M%S)
REPO=$(echo "${REPO#*/}")
ORG="unraid"
CHANGELOG="${DIR}/release.md"
FILE=unraid-$REPO-*.tgz
TAG=$RELEASE_TAG

# If full tag
if [[ ! -z "$IS_TAG" ]]; then
    TYPE="Release"

    # Compare to the last known semver version so we get the whole changelog
    LAST_RELEASE=$(git tag --list  --sort=v:refname | grep -v rolling | reverse | sed -n 2p)
    RELEASE_NOTES=$(git log "$LAST_RELEASE...HEAD~1" --pretty=format:"- %s [\`%h\`](http://github.com/$ORG/$REPO/commit/%H)" --reverse)
# Otherwise rolling release
else
    TYPE="Rolling"
    LAST_RELEASE=$(git tag --list  --sort=v:refname | grep -v rolling | reverse | sed -n 1p)
    RELEASE=$LAST_RELEASE
    ROLLING_TAG="$RELEASE-rolling-$TIMESTAMP"
    RELEASE_NOTES=$(git log "$RELEASE_TAG...HEAD" --pretty=format:"- %s [\`%h\`](http://github.com/$ORG/$REPO/commit/%H)" --reverse)
    IS_PRE_RELEASE="true"
    TAG=$ROLLING_TAG
fi

NEW_FILE="unraid-$REPO-$TAG.tgz"

# Dry run
if [[ $* == *--dry* ]]; then
    export DRY_RUN="true" 
else
    # If it's not a dry-run let's copy the release to it's new location
    cp $FILE $NEW_FILE
fi

# Create release changelog
printf "$TAG\n\n$RELEASE_NOTES" > $CHANGELOG

# Exports
export FILE=$NEW_FILE
export CHANGELOG
export RELEASE
export TYPE
export RELEASE_NOTES
export IS_PRE_RELEASE
export RELEASE_TAG
export TAG

if [[ $DRY_RUN ]]; then
    # Display info
    bash ${DIR}display-info.sh
else
    # Upload to Github releases
    bash ${DIR}release-to-github.sh

    # # Upload to s3 bucket
    bash ${DIR}release-to-s3.sh

    # Remove temp files
    rm $NEW_FILE
    rm $CHANGELOG
fi