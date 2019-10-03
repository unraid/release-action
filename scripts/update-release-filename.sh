#!/usr/bin/env bash

FILE=$(echo ./unraid-*-*.tgz)
echo mv "$FILE" "${FILE%.tgz}-${RELEASE}.tgz"