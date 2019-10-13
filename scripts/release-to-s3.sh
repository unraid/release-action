#!/usr/bin/env bash

if [[ -z $AWS_ACCESS_KEY_ID || -z $AWS_ACCESS_KEY_SECRET]]; then
  echo "Skipping S3 as envs are missing"
  exit 0
fi

# Set creds from env
touch ~/.s3cfg
echo "[default]
access_key = $AWS_ACCESS_KEY_ID
secret_key = $AWS_ACCESS_KEY_SECRET" > ~/.s3cfg

# Upload file to s3
s3-cli put $FILE s3://$AWS_S3_BUCKET --acl-public
# s3-cli put s3://$AWS_S3_BUCKET$FILE s3://$AWS_S3_BUCKET/latest.tgz --acl-public