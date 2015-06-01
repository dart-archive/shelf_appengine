#!/usr/bin/env bash
exec gcloud preview app run \
  test/dispatch.yaml \
  test/module-serve/module-serve.yaml \
  test/module-redirect/module-redirect.yaml \
  test/default/default.yaml
