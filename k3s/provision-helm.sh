#!/bin/bash

curl -sfL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash -

sudo sh -c "helm completion bash >//usr/share/bash-completion/completions/helm"
