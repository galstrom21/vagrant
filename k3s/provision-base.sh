#!/bin/bash

# prevent apt-get et al from asking questions.
export DEBIAN_FRONTEND=noninteractive

# update the package cache.
apt-get update

# install jq.
apt-get install -y jq

# install curl.
apt-get install -y curl

# install the bash completion.
apt-get install -y bash-completion
