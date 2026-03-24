#!/bin/sh
set -eu

CI_REF="${CI_REF:-}"
CI_SHA="${CI_SHA:-}"

if [ -z "$CI_SHA" ]; then
  CI_SHA="$(git rev-parse HEAD)"
fi

if [ -z "$CI_REF" ]; then
  CI_REF="$(git symbolic-ref -q HEAD || true)"
  if [ -z "$CI_REF" ]; then
    CI_REF="detached"
  fi
fi

short_sha="$(printf '%s' "$CI_SHA" | cut -c1-7)"
tags="sha-${short_sha}"

case "$CI_REF" in
  refs/heads/main)
    tags="latest ${tags}"
    ;;
  refs/tags/v*)
    version_tag="${CI_REF#refs/tags/}"
    tags="${version_tag} ${tags}"
    ;;
esac

printf '%s\n' "$tags"
