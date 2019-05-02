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

# Install pre-reqs. We might need cmake and git if nobody ran the higher-level
# build scripts.
if [ ${ROCM_LOCAL_INSTALL} = false ] || [ ${ROCM_INSTALL_PREREQS} = true ]; then
    echo "Installing software required to build ROCm device libs."
    echo "You will need to have root privileges to do this."
    sudo dnf -y install cmake pkgconf-pkg-config git make gcc-c++ rpm-build
    if [ ${ROCM_INSTALL_PREREQS} = true ] && [ ${ROCM_FORCE_GET_CODE} = false ]; then
        exit 0
    fi
fi

# Set up source-code directory
if [ $ROCM_SAVE_SOURCE = true ]; then
    SOURCE_DIR=${ROCM_SOURCE_DIR}
    if [ ${ROCM_FORCE_GET_CODE} = true ] && [ -d ${SOURCE_DIR}/llvm_amd-common ]; then
        rm -rf ${SOURCE_DIR}/llvm_amd-common
    fi
    if [ ${ROCM_FORCE_GET_CODE} = true ] && [ -d ${SOURCE_DIR}/ROCm-Device-Libs ]; then
        rm -rf ${SOURCE_DIR}/ROCm-Device-Libs
    fi
    mkdir -p ${SOURCE_DIR}
else
    SOURCE_DIR=`mktemp -d`
fi
cd ${SOURCE_DIR}

# Download ROCm LLVM
if [ ${ROCM_FORCE_GET_CODE} = true ] || [ ! -d ${SOURCE_DIR}/llvm_amd-common ]; then
    cd ${SOURCE_DIR}
    git clone -b ${ROCM_VERSION_BRANCH} https://github.com/RadeonOpenCompute/llvm.git llvm_amd-common
    cd ${SOURCE_DIR}/llvm_amd-common
    git checkout ${ROCM_DEVICE_LIBS_CHECKOUT}
    cd ${SOURCE_DIR}/llvm_amd-common/tools
    git clone -b ${ROCM_VERSION_BRANCH} https://github.com/RadeonOpenCompute/lld.git lld
    cd ${SOURCE_DIR}/llvm_amd-common/tools/lld
    git checkout ${ROCM_DEVICE_LIBS_CHECKOUT}
    cd ${SOURCE_DIR}/llvm_amd-common/tools
    git clone -b ${ROCM_VERSION_BRANCH} https://github.com/RadeonOpenCompute/clang.git clang
    cd ${SOURCE_DIR}/llvm_amd-common/tools/clang
    git checkout ${ROCM_DEVICE_LIBS_CHECKOUT}
else
    echo "Skipping download of ROCm LLVM for device libs, since ${SOURCE_DIR}/llvm_amd-common already exists."
fi

if [ ${ROCM_FORCE_GET_CODE} = true ] || [ ! -d ${SOURCE_DIR}/ROCm-Device-Libs ]; then
    cd ${SOURCE_DIR}
    git clone -b ${ROCM_VERSION_BRANCH} https://github.com/RadeonOpenCompute/ROCm-Device-Libs.git
    cd ${SOURCE_DIR}/ROCm-Device-Libs/
    git checkout ${ROCM_DEVICE_LIBS_CHECKOUT}
else
    echo "Skipping download of ROCm Device Libs, since ${SOURCE_DIR}/ROCm-Device-Libs already exists."
fi

if [ ${ROCM_FORCE_GET_CODE} = true ]; then
    echo "Finished downloading LLVM and ROCm device libs. Exiting."
    exit 0
fi

ROCM_TEMP_LLVM_DIR=${ROCM_OUTPUT_DIR}/llvm/
if [ ${ROCM_FORCE_PACKAGE} = true ]; then
    ROCM_TEMP_LLVM_DIR=${SOURCE_DIR}/llvm_temp_install
    mkdir -p ${ROCM_TEMP_LLVM_DIR}
fi

if [ ${ROCM_FORCE_PACKAGE} = false ] || [ ! -f ${ROCM_TEMP_LLVM_DIR}/bin/clang ]; then
    # Build ROCm LLVM if it does not already exist
    cd ${SOURCE_DIR}/llvm_amd-common
    mkdir -p build
    cd build
    cmake -DCMAKE_BUILD_TYPE=${ROCM_CMAKE_BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_TEMP_LLVM_DIR} -DLLVM_TARGETS_TO_BUILD="AMDGPU;X86" -DLLVM_USE_LINKER=gold -DCLANG_ANALYZER_ENABLE_Z3_SOLVER=OFF -DLLVM_ENABLE_ASSERTIONS=No ..

    # Building LLVM can take a large amount of memory, and it will fail if you do
    # not have enough memory available per thread. As such, this # logic limits
    # the number of build threads in response to the amount of available memory
    # on the system.
    MEM_AVAIL=`cat /proc/meminfo | grep MemTotal | awk {'print $2'}`
    AVAIL_THREADS=`nproc`

    # Give about 4 GB to each building thread
    MAX_THREADS=`echo $(( ${MEM_AVAIL} / $(( 1024 * 1024 * 4 )) ))`
    if [ ${MAX_THREADS} -lt ${AVAIL_THREADS} ]; then
        NUM_BUILD_THREADS=${MAX_THREADS}
    else
        NUM_BUILD_THREADS=${AVAIL_THREADS}
    fi
    if [ ${NUM_BUILD_THREADS} -lt 1 ]; then
        NUM_BUILD_THREADS=1
    fi

    make -j ${NUM_BUILD_THREADS}
    ${ROCM_SUDO_COMMAND} make install
fi

# Build ROCm device libs
cd ${SOURCE_DIR}/ROCm-Device-Libs/
mkdir -p build
cd build
export LLVM_BUILD=${ROCM_TEMP_LLVM_DIR}
CC=$LLVM_BUILD/bin/clang cmake -DLLVM_DIR=${LLVM_BUILD} -DCMAKE_INSTALL_PREFIX=${ROCM_OUTPUT_DIR}/ -DCMAKE_BUILD_TYPE=${ROCM_CMAKE_BUILD_TYPE} -DCPACK_PACKAGING_INSTALL_PREFIX=${ROCM_OUTPUT_DIR}/ -DCPACK_GENERATOR=RPM ${ROCM_CPACK_RPM_PERMISSIONS} ..
make -j `nproc`

if [ ${ROCM_FORCE_BUILD_ONLY} = true ]; then
    echo "Finished building LLVM and ROCm device libs. Exiting."
    exit 0
fi

if [ ${ROCM_FORCE_PACKAGE} = true ]; then
    make package
    echo "Copying `ls -1 rocm-device-libs-*.rpm` to ${ROCM_PACKAGE_DIR}"
    mkdir -p ${ROCM_PACKAGE_DIR}
    cp ./rocm-device-libs-*.rpm ${ROCM_PACKAGE_DIR}
    if [ ${ROCM_LOCAL_INSTALL} = false ]; then
        ROCM_PKG_IS_INSTALLED=`rpm -qa | grep rocm-device-libs | wc -l`
        if [ ${ROCM_PKG_IS_INSTALLED} -gt 0 ]; then
            PKG_NAME=`rpm -qa | grep rocm-device-libs | head -n 1`
            sudo rpm -e --nodeps ${PKG_NAME}
        fi
        sudo rpm -i ./rocm-device-libs-*.rpm
    fi
else
    ${ROCM_SUDO_COMMAND} make install
fi

unset LLVM_BUILD

if [ $ROCM_SAVE_SOURCE = false ]; then
    rm -rf ${SOURCE_DIR}
fi
