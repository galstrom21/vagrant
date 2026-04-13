#!/usr/bin/env bash

set -xe

sudo DEBIAN_FRONTEND=noninteractive apt install -y redis-server

# Verify Redis is running
echo "INSTALL | Verify redis is available"
redis-cli ping
