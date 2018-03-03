#!/bin/bash
npm run build:static &&
bundle exec jekyll serve --config "_config.yml,_config_dev.yml" --incremental
