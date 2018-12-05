#!/bin/bash

FW_DIR="/lib/firmware/$1"
rm -rf $FW_DIR/radeon
rm -rf $FW_DIR/amdgpu
[[ ! $(ls -A $FW_DIR) ]] && rm -rf $FW_DIR
rm -f /etc/dracut.conf.d/amdgpu-$1.conf
