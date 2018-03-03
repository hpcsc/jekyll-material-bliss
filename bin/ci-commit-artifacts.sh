#!/bin/bash

# Automated deploy script with Travis CI.

# Exit if any subcommand fails.
set -e

echo "========================= COMMIT TO $DEPLOY_REPOSITORY ================="
# Variables
ORIGIN_CREDENTIALS=${DEPLOY_REPOSITORY/\/\/github.com/\/\/$GITHUB_TOKEN@github.com}
TRAVIS_SHORT_HASH=$(git rev-parse --short $TRAVIS_COMMIT)
COMMIT_MESSAGE="[TRAVIS][#$TRAVIS_BUILD_NUMBER][$TRAVIS_SHORT_HASH] triggered by $TRAVIS_REPO_SLUG"

# Checkout github pages
git clone $DEPLOY_REPOSITORY deploy-repository

# copy artifacts to github pages repo
rm -rf ./deploy-repository/assets
yes | cp -rf public/* ./deploy-repository

# Commit and push
cd deploy-repository
git config user.name "$USERNAME"
git config user.email "$EMAIL"

git add -fA
git commit --allow-empty -m "$COMMIT_MESSAGE"
git push -f -q $ORIGIN_CREDENTIALS master

exit 0
