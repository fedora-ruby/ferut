#!/usr/bin/bash

RUBY_DIST_GIT=$HOME/fedora-scm/own/ruby
RUBY_GIT_REF=master
RUBY_GIT_WORKING_BRANCH=fedora-ruby-3.0
RUBY_GIT_WORKING_TAG=fedora-ruby-3.0-tag

git checkout $RUBY_GIT_REF && \
git checkout -b $RUBY_GIT_WORKING_BRANCH

for p in \
  $(sed -n "/^Patch[[:digit:]]\+: / s/Patch[[:digit:]]\+:[[:blank:]]\+// p" $RUBY_DIST_GIT/ruby.spec) \
; do
  # The following file is reversly applied.
  [[ "$p" == "ruby-3.0.3-ext-openssl-extconf.rb-require-OpenSSL-version-1.0.1.patch" ]] && continue
  # Not in Git format.
  [[ "$p" == "ruby-3.1.0-SSL_read-EOF-handling.patch" ]] && continue

  git tag -f $RUBY_GIT_WORKING_TAG && \
  git am $RUBY_DIST_GIT/$p && \
  git format-patch $RUBY_GIT_WORKING_TAG..HEAD --stdout > $RUBY_DIST_GIT/$p || \
  exit 1
done

git checkout $RUBY_GIT_REF && \
git tag -d $RUBY_GIT_WORKING_TAG && \
git branch -D $RUBY_GIT_WORKING_BRANCH