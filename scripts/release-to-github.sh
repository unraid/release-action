#!/usr/bin/env bash

if [[ $IS_PRE_RELEASE ]]; then
    hub release create -a $FILE -F $CHANGELOG -p $TAG
else
    hub release create -a $FILE -F $CHANGELOG $TAG
fi