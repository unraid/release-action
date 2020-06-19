#!/usr/bin/env bash

get_latest_github_release() {
    local repo=$1
    echo $(hub api --flat "repos/${repo}/releases/latest" | awk '/.tag_name/ {print $2}')
}

replace() {
    local search=$1
    local replace=$2
    local file=$3
    printf '%s\n' "replacing '${search}' with '${replace}' in file '${file}'"
    sed -i "s/${search}/${replace}/g" $file || exit 1
}

# https://stackoverflow.com/a/56201734/2311366
check_bash_version() {
    local major=${1:-4}
    local minor=$2
    local rc=0
    local num_re='^[0-9]+$'

    if [[ ! $major =~ $num_re ]] || [[ $minor && ! $minor =~ $num_re ]]; then
        printf '%s\n' "ERROR: version numbers should be numeric"
        return 1
    fi
    if [[ $minor ]]; then
        local bv=${BASH_VERSINFO[0]}${BASH_VERSINFO[1]}
        local vstring=$major.$minor
        local vnum=$major$minor
    else
        local bv=${BASH_VERSINFO[0]}
        local vstring=$major
        local vnum=$major
    fi
    ((bv < vnum)) && {
        # printf '%s\n' "ERROR: Need Bash version $vstring or above, your version is ${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}"
        rc=1
    }
    return $rc
}

# Ensure we have version 4 otherwise
# associative arrays aren't supported
check_bash_version 4
bash_check_return_code=$?

if [[ ! $bash_check_return_code == 1 ]]; then
    # associative array for job status
    unset JOBS
    declare -A JOBS
fi

# Run command in the background
background() {
  eval $1 & JOBS[$!]="$1"
}

# Check exit status of each job
# preserve exit status in ${JOBS}
# returns 1 if any job failed
# https://unix.stackexchange.com/a/230740/119653
reap() {
  local cmd
  local status=0
  for pid in ${!JOBS[@]}; do
    cmd=${JOBS[${pid}]}
    wait ${pid} ; JOBS[${pid}]=$?
    if [[ ${JOBS[${pid}]} -ne 0 ]]; then
      status=${JOBS[${pid}]}
      echo -e "[${pid}] Exited with status: ${status}\n${cmd}"
    fi
  done
  return ${status}
}

# https://unix.stackexchange.com/a/9443/119653
reverse() {
    local line
    if IFS= read -r line
    then
        reverse
        printf '%s\n' "$line"
    fi
}

add_ssh_key() {
    if [[ ! -z "$SSH_KEY" ]]; then
        echo "Adding SSH key"

        mkdir ~/.ssh/

        # Add private key
        echo $SSH_KEY > ~/.ssh/id_rsa

        # Set correct permissions
        chmod 600 ~/.ssh/id_rsa

        # Add our known hosts
        echo $KNOWN_HOSTS > ~/.ssh/known_hosts

        # Create ssh config
        printf "Host *\n  AddKeysToAgent yes\n  UseKeychain yes\n  IdentityFile ~/.ssh/id_rsa" > ~/.ssh/config

        # Start agent
        eval "$(ssh-agent -s)"

        # Add private key to agent
        ssh-add -k ~/.ssh/id_rsa

        echo "Done adding key"
    fi
}

# Current directory
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IS_TAG=$(git tag -l --points-at HEAD)
RELEASE_COMMIT=$(git rev-list --tags --max-count=1)

# If we don't have a first release
# then bail as the first one should always be manual.
if [[ -z "$RELEASE_COMMIT" ]]; then
    echo "No tags found!"
    exit 1;
fi

RELEASE_TAG=$(git describe --tags $RELEASE_COMMIT)
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
    background ${DIR}/display-info.sh
 
    # Run command
    reap
    exit_code=$?
else
    # Upload to Github releases
    background "${DIR}/release-to-github.sh $FILE"

    # Allow us to use our ssh keys
    add_ssh_key

    # In plugins we need to grab the plg file
    # otherwise it'll be missing for the templating step
    if [[ $REPO == "plugins" ]]; then
        git clone git@github.com:unraid/graphql-api.git /tmp/graphql-api
        exit 1
        # mv /tmp/graphql-api/dynamix.unraid.net.plg .
        # rm -rf /tmp/graphql-api
    fi

    # Only upload to s3 bucket if new release
    if [[ ! -z "$IS_TAG" ]]; then
        background "${DIR}/release-to-s3.sh $FILE"

        # --------------------
        # Move it back here
        # Move it back here
        # Move it back here
        # --------------------

        # Only upload plg file in the graphql-api/plugins repo
        if [[ $REPO == "graphql-api" ]] ||  [[ $REPO == "plugins" ]]; then
            # Replace plg file's template vars
            PLG_VERSION=$(date '+%Y.%m.%d.%H%M')
            GRAPHQL_API_VERSION=$(if [[ $REPO == "graphql-api" ]]; then echo $RELEASE_TAG; else get_latest_github_release 'unraid/graphql-api'; fi)
            PLUGINS_VERSION=$(if [[ $REPO == "plugins" ]]; then echo $RELEASE_TAG; else get_latest_github_release 'unraid/plugins'; fi)
            replace "{{ plg_version }}" $PLG_VERSION /tmp/graphql-api/dynamix.unraid.net.plg
            replace "{{ node_graphql_api_version }}" $GRAPHQL_API_VERSION /tmp/graphql-api/dynamix.unraid.net.plg
            replace "{{ node_plugins_version }}" $PLUGINS_VERSION /tmp/graphql-api/dynamix.unraid.net.plg

            # Upload plg file to s3
            background "${DIR}/release-to-s3.sh /tmp/graphql-api/dynamix.unraid.net.plg"
        fi
    fi

    # Run command
    reap
    exit_code=$?

    # Remove temp files
    rm $NEW_FILE
    rm $CHANGELOG
fi

if [[ ! $exit_code == 0 ]]; then
    echo "Failed deploying!" && exit $exit_code
else
    echo "Deployed successfully!"
fi
