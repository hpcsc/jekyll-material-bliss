---
layout: post
title:  "How Is This Blog Deployed?"
date:   2018-03-12 09:00:00 +0800
type: post
categories: devops, deployment
tags: devops jekyll blog
---

In this post, I'll go through the pipeline that automatically picks up any change to my source code, builds and deploys to my Github Page.

Below is an overview of the pipeline:

![Github Page Pipeline](/assets/2018-03-12/github-page-pipeline.png "Github Page Pipeline")

There are 2 Github repositories involved:

- `jekyll-material-bliss`: contains all the source code of the blog (including Jekyll templates, Javascript source code written in React, etc). This repository is originally from [material-bliss-jekyll-theme](https://github.com/InsidiousMind/material-bliss-jekyll-theme "material-bliss-jekyll-theme") and modified a bit by me.
- `hpcsc.github.io`: this is the `production` Github page and is the target of the deployment. This repository contains static posts transformed by Jekyll, transpiled and bundled javascript, etc.

The process is triggered by any commit to `jekyll-material-bliss`. `Travis` listens, picks up the commit and starts building. Here's a snippet of `.travis.yml`:

```
install:
- env
- "./bin/ci-bundle-install.sh"
- "./bin/ci-npm-install.sh"
script:
- "./build-prod.sh"
after_success:
  - "./bin/ci-commit-artifacts.sh"
```

In the `install` phase, Travis prints out all environment variables available, installs Ruby `bundler`, does `bundle install`, and then `npm install` in the CI agent.

In the `build` phase (`script` section), Travis CI agent generates Javascript files using `webpack` in production mode, render some React components into Jekyll templates (.e.g. `<Post/>`) and finally invokes Jekyll to transform templates into static files. At the end of this phase, all of the build assets are generated into `public` folder in CI agent.

The interesting part is in Travis `after_success` script. If the build is successful, Travis invokes `ci-commit-artifacts.sh` script to `"deploy"` to `production` Github Page. This script is originally from [Kickster](https://github.com/nielsenramon/kickster/blob/master/snippets/travis/automated) but it doesn't suit my purpose (because it assumes the Github Page is of type `Project` and deploys to `gh-pages` branch instead of `master`) so I modified it to do a few things:

- Clone `hpcsc.github.io` repository in a sub folder of current directory with the name `deploy-repository`
- Copy artifacts from previous build step (`public` folder) into `deploy-repository` sub folder, override any file that exists in the destination:

    ```
    rm -rf ./deploy-repository/assets
    yes | cp -rf public/* ./deploy-repository
    ```

- Final step is to add the changes to Git, commit and push back to `hpcsc.github.io`. All of these commits have commit message in the following format: `[TRAVIS][#$TRAVIS_BUILD_NUMBER][$GIT_COMMIT_SHORT_HASH] triggered by jekyll-material-bliss`.

    Also note that instead of pushing to `https://github.com/hpcsc/hpcsc.github.io`, this script pushes to `https://{github-personal-access-token}@github.com/hpcsc/hpcsc.github.io` where `{github-personal-access-token}` is decrypted and provided by Travis from `secure` variable in `.travis.yml`

After this step, the change is successfully deployed to Github Page and can be viewed at `hpcsc.github.io`. However users will normally access my site through `Cloudfare CDN` instead.
