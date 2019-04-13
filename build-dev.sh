#!/bin/bash
npm run build:static:dev &&
bundle exec jekyll serve --config "_config.yml,_config_dev.yml" --incremental
