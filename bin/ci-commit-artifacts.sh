#!/bin/bash

# Automated deploy script with Travis CI.

# Exit if any subcommand fails.
set -e

echo "========================= COMMIT TO GITHUB PAGE ================="
# Variables
ORIGIN_URL='https://github.com/hpcsc/hpcsc.github.io'
ORIGIN_CREDENTIALS=${ORIGIN_URL/\/\/github.com/\/\/$GITHUB_TOKEN@github.com}
TRAVIS_SHORT_HASH=$(git rev-parse --short $TRAVIS_COMMIT)
COMMIT_MESSAGE="[TRAVIS][#$TRAVIS_BUILD_NUMBER][$TRAVIS_SHORT_HASH] triggered by $TRAVIS_REPO_SLUG"

# Checkout github pages
git clone $ORIGIN_URL

# copy artifacts to github pages repo
rm -rf ./hpcsc.github.io/assets
yes | cp -rf public/* ./hpcsc.github.io

# Commit and push
cd hpcsc.github.io
git config user.name "$USERNAME"
git config user.email "$EMAIL"

git add -fA
git commit --allow-empty -m "$COMMIT_MESSAGE"
git push -f -q $ORIGIN_CREDENTIALS master

exit 0
