#!/bin/bash
###############################################################################
# Copyright (c) 2018-2019 Advanced Micro Devices, Inc.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
###############################################################################
BASE_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
set -e
trap 'lastcmd=$curcmd; curcmd=$BASH_COMMAND' DEBUG
trap 'errno=$?; print_cmd=$lastcmd; if [ $errno -ne 0 ]; then echo "\"${print_cmd}\" command failed with exit code $errno."; fi' EXIT
source "$BASE_DIR/common/common_options.sh"
parse_args "$@"

sudo zypper -n in wget bzip2

# 2.0.0 is an old release, so the deb packages have moved over to an archive
# tarball. Let's set up a local repo to allow us to do the install here.
# Store the repo in the source directory or a temp directory.
if [ $ROCM_SAVE_SOURCE = true ]; then
    SOURCE_DIR=${ROCM_SOURCE_DIR}
    if [ ${ROCM_FORCE_GET_CODE} = true ] && [ -d ${SOURCE_DIR}/rocm_2.0.0 ]; then
        rm -rf ${SOURCE_DIR}/rocm_2.0.0
    fi
    mkdir -p ${SOURCE_DIR}
else
    SOURCE_DIR=`mktemp -d`
fi
cd ${SOURCE_DIR}
if [ ! -f ${SOURCE_DIR}/yum_2.0.0.tar.bz2 ]; then
    wget http://repo.radeon.com/rocm/archive/yum_2.0.0.tar.bz2
fi
if [ ! -d yum_2.0.0.89 ]; then
    tar -xf yum_2.0.0.tar.bz2
fi
cd yum_2.0.0.89
REAL_SOURCE_DIR=`realpath ${SOURCE_DIR}`
sudo sh -c "echo [ROCm] > /etc/yum.repos.d/rocm.repo"
sudo sh -c "echo name=ROCm >> /etc/yum.repos.d/rocm.repo"
sudo sh -c "echo baseurl=file://${REAL_SOURCE_DIR}/yum_2.0.0.89/ >> /etc/yum.repos.d/rocm.repo"
sudo sh -c "echo enabled=1 >> /etc/yum.repos.d/rocm.repo"
sudo sh -c "echo gpgcheck=0 >> /etc/yum.repos.d/rocm.repo"

sudo zypper -n in miopen-hip miopengemm rocm-libs rocsparse hipsparse Thrust rocm_smi64 rccl
# By default, this installs miopen-hip, because PyTorch and Tensorflow use it
# If you want to use OpenVX you may need to install miopen-opencl instead of miopen-hip

sudo rm -f /etc/yum.repos.d/rocm.repo
