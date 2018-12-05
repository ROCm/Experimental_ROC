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
trap 'errno=$?; print_cmd=$lastcmd; if [ $errno -ne 0 ]; then echo "\"${print_cmd}\" command failed with exit code $errno."; fi' EXIT
source "$BASE_DIR/common/common_options.sh"
parse_args "$@"

# Install pre-reqs. We might need cmake and git if nobody ran the higher-level
# build scripts. We will need wget if we need to download the new cmake version.
if [ ${ROCM_LOCAL_INSTALL} = false ] || [ ${ROCM_INSTALL_PREREQS} = true ]; then
    echo "Installing software required to build ATMI."
    echo "You will need to have root privileges to do this."
    sudo yum -y install cmake pkgconfig git wget
    if [ ${ROCM_INSTALL_PREREQS} = true ] && [ ${ROCM_FORCE_GET_CODE} = false ]; then
        exit 0
    fi
fi

# Set up source-code directory
if [ $ROCM_SAVE_SOURCE = true ]; then
    SOURCE_DIR=${ROCM_SOURCE_DIR}
    if [ ${ROCM_FORCE_GET_CODE} = true ] && [ -d ${SOURCE_DIR}/atmi ]; then
        rm -rf ${SOURCE_DIR}/atmi
    fi
    mkdir -p ${SOURCE_DIR}
else
    SOURCE_DIR=`mktemp -d`
fi
cd ${SOURCE_DIR}

# Download ATMI
if [ ${ROCM_FORCE_GET_CODE} = true ] || [ ! -d ${SOURCE_DIR}/atmi ]; then
    # We require a new version of cmake to build OpenCL on CentOS, so get it here.
    source "$BASE_DIR/common/get_updated_cmake.sh"
    get_cmake "${SOURCE_DIR}"
    git clone https://github.com/RadeonOpenCompute/atmi.git
    cd ${SOURCE_DIR}/atmi
    git checkout 4dd14ad
else
    echo "Skipping download of ATMI, since ${SOURCE_DIR}/atmi already exists."
fi

if [ ${ROCM_FORCE_GET_CODE} = true ]; then
    echo "Finished downloading ATMI. Exiting."
    exit 0
fi

cd ${SOURCE_DIR}/atmi
mkdir -p src/build
cd src/build
export GFXLIST="gfx701 gfx801 gfx802 gfx803 gfx900 gfx906"
${SOURCE_DIR}/cmake/bin/cmake -DCMAKE_INSTALL_PREFIX=${ROCM_OUTPUT_DIR}/atmi -DCMAKE_BUILD_TYPE=${ROCM_CMAKE_BUILD_TYPE} -DLLVM_DIR=${ROCM_INPUT_DIR}/llvm/ -DDEVICE_LIB_DIR=${ROCM_INPUT_DIR}/lib/ -DHSA_DIR=${ROCM_INPUT_DIR}/ -DATMI_HSA_INTEROP=ON -DATMI_DEVICE_RUNTIME=ON -DATMI_C_EXTENSION=ON ..

make -j `nproc`
${ROCM_SUDO_COMMAND} make install

unset GFXLIST

if [ $ROCM_SAVE_SOURCE = false ]; then
    rm -rf ${SOURCE_DIR}
fi
