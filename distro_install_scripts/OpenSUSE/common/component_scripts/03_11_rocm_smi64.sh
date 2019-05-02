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
BASE_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
set -e
trap 'lastcmd=$curcmd; curcmd=$BASH_COMMAND' DEBUG
trap 'errno=$?; print_cmd=$lastcmd; if [ $errno -ne 0 ]; then echo "\"${print_cmd}\" command failed with exit code $errno."; fi' EXIT
source "$BASE_DIR/common/common_options.sh"
parse_args "$@"

# Install pre-reqs.
if [ ${ROCM_LOCAL_INSTALL} = false ] || [ ${ROCM_INSTALL_PREREQS} = true ]; then
    echo "Installing software required to build the ROCm SMI Lib."
    echo "You will need to have root privileges to do this."
    sudo zypper -n in cmake pkg-config git make gcc-c++ graphviz rpm-build
    if [ ${ROCM_INSTALL_PREREQS} = true ] && [ ${ROCM_FORCE_GET_CODE} = false ]; then
        exit 0
    fi
fi

# Set up source-code directory
if [ $ROCM_SAVE_SOURCE = true ]; then
    SOURCE_DIR=${ROCM_SOURCE_DIR}
    if [ ${ROCM_FORCE_GET_CODE} = true ] && [ -d ${SOURCE_DIR}/rocm_smi_lib ]; then
        rm -rf ${SOURCE_DIR}/rocm_smi_lib
    fi
    mkdir -p ${SOURCE_DIR}
else
    SOURCE_DIR=`mktemp -d`
fi
cd ${SOURCE_DIR}

# Download ROCm SMI Lib
if [ ${ROCM_FORCE_GET_CODE} = true ] || [ ! -d ${SOURCE_DIR}/rocm_smi_lib ]; then
    git clone https://github.com/RadeonOpenCompute/rocm_smi_lib.git
    cd rocm_smi_lib
    git checkout ${ROCM_SMILIB_CHECKOUT}
else
    echo "Skipping download of ROCm SMI Lib, since ${SOURCE_DIR}/rocm_smi_lib already exists."
fi

if [ ${ROCM_FORCE_GET_CODE} = true ]; then
    echo "Finished downloading ROCm SMI Lib. Exiting."
    exit 0
fi

cd ${SOURCE_DIR}/rocm_smi_lib
mkdir -p build
cd build
cmake -DCPACK_PACKAGING_INSTALL_PREFIX=${ROCM_OUTPUT_DIR}/ -DCPACK_GENERATOR=RPM ${ROCM_CPACK_RPM_PERMISSIONS} -DCMAKE_BUILD_TYPE=${ROCM_CMAKE_BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_OUTPUT_DIR}/ ..

make -j `nproc`

if [ ${ROCM_FORCE_BUILD_ONLY} = true ]; then
    echo "Finished building ROCm SMI Lib. Exiting."
    exit 0
fi

if [ ${ROCM_FORCE_PACKAGE} = true ]; then
    make package
    echo "Copying `ls -1 rocm_smi_lib64-*.rpm` to ${ROCM_PACKAGE_DIR}"
    mkdir -p ${ROCM_PACKAGE_DIR}
    cp ./rocm_smi_lib64-*.rpm ${ROCM_PACKAGE_DIR}
    if [ ${ROCM_LOCAL_INSTALL} = false ]; then
        ROCM_PKG_IS_INSTALLED=`rpm -qa | grep rocm_smi_lib64 | wc -l`
        if [ ${ROCM_PKG_IS_INSTALLED} -gt 0 ]; then
            PKG_NAME=`rpm -qa | grep rocm_smi_lib64 | head -n 1`
            sudo rpm -e --nodeps ${PKG_NAME}
        fi
        sudo rpm -i ./rocm_smi_lib64-*.rpm
    fi
else
    ${ROCM_SUDO_COMMAND} make install
fi

if [ $ROCM_SAVE_SOURCE = false ]; then
    rm -rf ${SOURCE_DIR}
fi
