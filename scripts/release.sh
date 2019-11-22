#!/usr/bin/env bash

set -e

commit_message=$1

if [ -z "$commit_message" ]; then
    >&2 echo "Commit message is empty."
    exit 1
fi

hugo
cd public
git add -A
git commit -m "$commit_message"
git push

cd ..
git add -A
git commit -m "$commit_message"
git push
