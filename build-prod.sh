#!/bin/bash

# Exit if any subcommand fails.
set -e

echo "========================= WEBPACK PRODUCTION ================="
npm run build:production

echo "========================= GENERATE STATIC ================="
npm run build:static

echo "========================= JEKYLL BUILD ================="
bundle exec jekyll build --config "_config.yml,_config_prod.yml"
