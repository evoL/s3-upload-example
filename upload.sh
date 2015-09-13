#!/bin/bash
curl -o authdata.json -d '' http://localhost:4567/authdata

curl -v \
  -F 'acl=public-read' \
  -F 'key=uploads/${filename}' \
  -F "policy=$(jq -r .policy authdata.json)" \
  -F "x-amz-algorithm=$(jq -r $'.\"x-amz-algorithm\"' authdata.json)" \
  -F "x-amz-credential=$(jq -r $'.\"x-amz-credential\"' authdata.json)" \
  -F "x-amz-date=$(jq -r $'.\"x-amz-date\"' authdata.json)" \
  -F "x-amz-signature=$(jq -r $'.\"x-amz-signature\"' authdata.json)" \
  -F "file=@$1" \
  "http://$(jq -r .bucket authdata.json).s3.amazonaws.com/"
