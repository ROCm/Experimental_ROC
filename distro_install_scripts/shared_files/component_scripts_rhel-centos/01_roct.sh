#!/bin/bash
###############################################################################
# Copyright (c) 2018 Advanced Micro Devices, Inc.
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
source scl_source enable devtoolset-7
BASE_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
set -e
trap 'lastcmd=$curcmd; curcmd=$BASH_COMMAND' DEBUG
trap 'print_cmd=$lastcmd; errno=$?; if [ $errno -ne 0 ]; then echo "\"${print_cmd}\" command failed with exit code $errno."; fi' EXIT
source "$BASE_DIR/common/common_options.sh"
parse_args "$@"

# Install pre-reqs. The Thunk needs PCIe utils and numaif.h. In addition, we need
# git to be able to download the source code and wget so we can get the new version
# of cmake. Also installing old version of cmake to get system-wide stuff set up.
if [ ${ROCM_LOCAL_INSTALL} = false ] || [ ${ROCM_INSTALL_PREREQS} = true ]; then
    echo "Installing software required to build ROCt Thunk layer."
    echo "You will need to have root privileges to do this."
    sudo yum -y install cmake pkgconfig git pciutils-devel numactl-devel wget
    if [ ${ROCM_INSTALL_PREREQS} = true ] && [ ${ROCM_FORCE_GET_CODE} = false ]; then
        exit 0
    fi
fi

# Set up source-code directory
if [ $ROCM_SAVE_SOURCE = true ]; then
    SOURCE_DIR=${ROCM_SOURCE_DIR}
    if [ ${ROCM_FORCE_GET_CODE} = true ] && [ -d ${SOURCE_DIR}/ROCT-Thunk-Interface ]; then
        rm -rf ${SOURCE_DIR}/ROCT-Thunk-Interface
    fi
    mkdir -p ${SOURCE_DIR}
else
    SOURCE_DIR=`mktemp -d`
fi
cd ${SOURCE_DIR}

# Download ROCt
if [ ${ROCM_FORCE_GET_CODE} = true ] || [ ! -d ${SOURCE_DIR}/ROCT-Thunk-Interface ]; then
    # We require a new version of cmake to build ROCT on CentOS, so get it here.
    source "$BASE_DIR/common/get_updated_cmake.sh"
    get_cmake "${SOURCE_DIR}"
    git clone -b roc-1.9.x https://github.com/RadeonOpenCompute/ROCT-Thunk-Interface.git
    cd ${SOURCE_DIR}/ROCT-Thunk-Interface/
    git checkout tags/roc-1.9.1
else
    echo "Skipping download of ROCt, since ${SOURCE_DIR}/ROCT-Thunk-Interface already exists."
fi

if [ ${ROCM_FORCE_GET_CODE} = true ]; then
    echo "Finished downloading ROCt. Exiting."
    exit 0
fi

# Build, and install ROCt
cd ${SOURCE_DIR}/ROCT-Thunk-Interface/
mkdir -p build
cd build
${SOURCE_DIR}/cmake/bin/cmake .. -DCMAKE_BUILD_TYPE=${ROCM_CMAKE_BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_OUTPUT_DIR}/
${ROCM_SUDO_COMMAND} mkdir -p ${ROCM_OUTPUT_DIR}/lib64/
make -j `nproc`
${ROCM_SUDO_COMMAND} make install
${ROCM_SUDO_COMMAND} mkdir -p ${ROCM_OUTPUT_DIR}/include/
${ROCM_SUDO_COMMAND} cp -R ${SOURCE_DIR}/ROCT-Thunk-Interface/include/* ${ROCM_OUTPUT_DIR}/include/

if [ ${ROCM_LOCAL_INSTALL} = false ]; then
    ${ROCM_SUDO_COMMAND} sh -c "echo ${ROCM_OUTPUT_DIR}/lib > /etc/ld.so.conf.d/x86_64-libhsakmt.conf"
    ${ROCM_SUDO_COMMAND} sh -c "echo ${ROCM_OUTPUT_DIR}/lib64 > /etc/ld.so.conf.d/x86_64-libhsakmt.conf"
    ${ROCM_SUDO_COMMAND} ldconfig
fi

if [ $ROCM_SAVE_SOURCE = false ]; then
    rm -rf ${SOURCE_DIR}
fi
