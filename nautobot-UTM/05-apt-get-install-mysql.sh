#!/usr/bin/env bash

set -xe

sudo DEBIAN_FRONTEND=noninteractive apt install -y libmysqlclient-dev mysql-server pkg-config
