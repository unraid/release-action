#!/usr/bin/env bash

if [ -z $1 ]; then
  echo "Skipping Github as filepath is missing, please pass it as the first argument"
  exit 0
fi

if [[ $IS_PRE_RELEASE ]]; then
    hub release create -a $1 -F $CHANGELOG -p $TAG
else
    hub release create -a $1 -F $CHANGELOG $TAG
fi