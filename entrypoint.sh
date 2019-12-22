#!/bin/bash -l

set -e

if [[ -z "$GITHUB_TOKEN" ]]; then
  echo "Required the GITHUB_TOKEN environment variable."
  exit 1
fi

if [[ -z "$GIT_USER_NAME" ]]; then
    echo "require to set with: GIT_USER_NAME."
  exit 1
fi

if [[ -z "$GIT_EMAIL" ]]; then
  echo "require to set with: GIT_EMAIL."
  exit 1
fi

git remote set-url origin "https://$GITHUB_ACTOR:$GITHUB_TOKEN@github.com/$GITHUB_REPOSITORY"
git checkout master
BRANCH_NAME="bundle_update/$(date "+%Y%m%d_%H%M%S")"
git checkout -b ${BRANCH_NAME}

export PATH="/usr/local/bundle/bin:$PATH"

if [[ -n "$INPUT_BUNDLER_VERSION" ]]; then
  gem install bundler -v "$INPUT_BUNDLER_VERSION"
else
  gem install bundler
fi

gem install bundler-diff

bundle config --local build.mysql2 "--with-ldflags=-L/usr/local/opt/openssl/lib"
bundle update
bundle diff -f md_table
BUNDLE_DIFF="$(bundle diff -f md_table)"

if [ "$(git diff --name-only origin/master --diff-filter=d | wc -w)" == 0 ]; then
  echo "not update"
  exit 1
fi

export GITHUB_USER="$GITHUB_ACTOR"

git config --global user.name $GIT_USER_NAME
git config --global user.email $GIT_EMAIL

hub add Gemfile Gemfile.lock
hub commit -m "bundle update && bundle update --ruby"
hub push origin ${BRANCH_NAME}

TITLE="bundle update $(date "+%Y%m%d_%H%M%S")"

PR_ARG="-m \"$TITLE\" -m \"$BUNDLE_DIFF\""

if [[ -n "$INPUT_REVIEWERS" ]]; then
  PR_ARG="$PR_ARG -r \"$INPUT_REVIEWERS\""
fi

COMMAND="hub pull-request -b master -h $BRANCH_NAME --no-edit $PR_ARG || true"

echo "$COMMAND"
sh -c "$COMMAND"
