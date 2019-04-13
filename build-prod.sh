#!/bin/bash

# Exit if any subcommand fails.
set -e

echo "========================= WEBPACK PRODUCTION ================="
npm run build:production

echo "========================= GENERATE STATIC ================="
npm run build:static:production

echo "========================= JEKYLL BUILD ================="
JEKYLL_ENV=production bundle exec jekyll build --config "_config.yml,_config_prod.yml"
