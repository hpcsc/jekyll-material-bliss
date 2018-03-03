#!/usr/bin/env sh

# Set up Jekyll site. Run this script immediately after cloning the codebase.
# https://github.com/thoughtbot/guides/tree/master/protocol

# Exit if any subcommand fails
set -e

echo "========================= BUNDLE INSTALL ======================="

# Set up Ruby dependencies via Bundler.
gem install bundler --conservative
bundle install
bundle update