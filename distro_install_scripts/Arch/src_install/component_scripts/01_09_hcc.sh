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
source "$BASE_DIR/../common_options.sh"
parse_args "$@"

# Install pre-reqs. We might need build-essential, cmake, and git if nobody
# ran the higher-level build scripts.
if [ ${ROCM_LOCAL_INSTALL} = false ] || [ ${ROCM_INSTALL_PREREQS} = true ]; then
    echo "Installing software required to build HCC."
    echo "You will need to have root privileges to do this."
    sudo pacman -Sy --noconfirm --needed base-devel cmake pkgconf git patch
    if [ ${ROCM_INSTALL_PREREQS} = true ] && [ ${ROCM_FORCE_GET_CODE} = false ]; then
        exit 0
    fi
fi
# If we are going to build this as a package and then try to install it, then
# we need to install the things it relies on or the deb installation will fail
if [ ${ROCM_LOCAL_INSTALL} = false ] && [ ${ROCM_FORCE_PACKAGE} = true ]; then
    sudo pacman -Sy --noconfirm --needed coreutils gcc findutils libelf pciutils file
fi

# Set up source-code directory
if [ $ROCM_SAVE_SOURCE = true ]; then
    SOURCE_DIR=${ROCM_SOURCE_DIR}
    if [ ${ROCM_FORCE_GET_CODE} = true ] && [ -d ${SOURCE_DIR}/hcc ]; then
        rm -rf ${SOURCE_DIR}/hcc
    fi
    mkdir -p ${SOURCE_DIR}
else
    SOURCE_DIR=`mktemp -d`
fi
cd ${SOURCE_DIR}

# Download hcc
if [ ${ROCM_FORCE_GET_CODE} = true ] || [ ! -d ${SOURCE_DIR}/hcc ]; then
    git clone --recursive -b ${ROCM_VERSION_BRANCH} https://github.com/RadeonOpenCompute/hcc.git
    cd ${SOURCE_DIR}/hcc
    git checkout ${ROCM_HCC_CHECKOUT}
    git submodule update
    patch -p 1 < ${BASE_DIR}/patches/01_09_hcc.patch
else
    echo "Skipping download of hcc, since ${SOURCE_DIR}/hcc already exists."
fi

if [ ${ROCM_FORCE_GET_CODE} = true ]; then
    echo "Finished downloading hcc. Exiting."
    exit 0
fi

cd ${SOURCE_DIR}/hcc
mkdir -p build
cd build

cd ${SOURCE_DIR}/hcc/build/

cmake .. -DCMAKE_BUILD_TYPE=${ROCM_CMAKE_BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_OUTPUT_DIR}/hcc/ -DLLVM_USE_LINKER=gold -DCLANG_ANALYZER_ENABLE_Z3_SOLVER=OFF -DLLVM_ENABLE_ASSERTIONS=OFF -DCMAKE_LIBRARY_PATH=${ROCM_INPUT_DIR}/lib -DCMAKE_INCLUDE_PATH=${ROCM_INPUT_DIR}/include -DCPACK_PACKAGING_INSTALL_PREFIX=${ROCM_OUTPUT_DIR}/ -DCPACK_GENERATOR=DEB -DHCC_OPEN_SOURCE_BUILD=ON
# Building HCC can take a large amount of memory, and it will fail if you do
# not have enough memory available per thread. As such, this # logic limits
# the number of build threads in response to the amount of available memory
# on the system.
MEM_AVAIL=`cat /proc/meminfo | grep MemTotal | awk {'print $2'}`
AVAIL_THREADS=`nproc`

# Give about 4 GB to each building thread
MAX_THREADS=`echo $(( ${MEM_AVAIL} / $(( 1024 * 1024 * 4 )) ))`
if [ ${ROCM_CMAKE_BUILD_TYPE} = "RelWithDebInfo" ]; then
    MAX_THREADS=`echo $(( ${MEM_AVAIL} / $(( 1024 * 1024 * 6 )) ))`
fi
if [ ${MAX_THREADS} -lt ${AVAIL_THREADS} ]; then
    NUM_BUILD_THREADS=${MAX_THREADS}
else
    NUM_BUILD_THREADS=${AVAIL_THREADS}
fi
if [ ${NUM_BUILD_THREADS} -lt 1 ]; then
    NUM_BUILD_THREADS=1
fi

make -j ${NUM_BUILD_THREADS}
# Workaround for Experimental ROC Issue #4
if [ ${ROCM_CMAKE_BUILD_TYPE} = "Debug" ]; then
    sed -i 's/DEBUG/RELEASE/g' ./lib/CMakeFiles/Export/lib/cmake/hcc/hcc-targets-debug.cmake
elif [ ${ROCM_CMAKE_BUILD_TYPE} = "RelWithDebInfo" ]; then
    sed -i 's/RELWITHDEBINFO/RELEASE/g' ./lib/CMakeFiles/Export/lib/cmake/hcc/hcc-targets-relwithdebinfo.cmake
fi

if [ ${ROCM_FORCE_BUILD_ONLY} = true ]; then
    echo "Finished building hcc. Exiting."
    exit 0
fi

if [ ${ROCM_FORCE_PACKAGE} = true ]; then
    echo "Sorry, packaging not yet implemented for this distribution"
    exit 2
#     make package
#     echo "Copying `ls -1 hcc-*.deb` to ${ROCM_PACKAGE_DIR}"
#     mkdir -p ${ROCM_PACKAGE_DIR}
#     cp ./hcc-*.deb ${ROCM_PACKAGE_DIR}
#     if [ ${ROCM_LOCAL_INSTALL} = false ]; then
#         ROCM_PKG_IS_INSTALLED=`dpkg -l hcc | grep '^.i' | wc -l`
#         if [ ${ROCM_PKG_IS_INSTALLED} -gt 0 ]; then
#             PKG_NAME=`dpkg -l hcc | grep '^.i' | awk '{print $2}'`
#             sudo dpkg -r --force-depends ${PKG_NAME}
#         fi
#         sudo dpkg -i hcc-*.deb
#     fi
else
    ${ROCM_SUDO_COMMAND} make install
    ${ROCM_SUDO_COMMAND} mkdir -p ${ROCM_OUTPUT_DIR}/bin/
    ${ROCM_SUDO_COMMAND} bash -c 'for i in lld clamp-config extractkernel hcc hcc-config; do ln -sf '"${ROCM_OUTPUT_DIR}"'/hcc/bin/${i} '"${ROCM_OUTPUT_DIR}"'/bin/${i}; done'
    ${ROCM_SUDO_COMMAND} mkdir -p ${ROCM_OUTPUT_DIR}/include/
    if [ ! -d ${ROCM_OUTPUT_DIR}/include/hcc ]; then
        ${ROCM_SUDO_COMMAND} ln -sf ${ROCM_OUTPUT_DIR}/hcc/include ${ROCM_OUTPUT_DIR}/include/hcc
    fi
    ${ROCM_SUDO_COMMAND} mkdir -p ${ROCM_OUTPUT_DIR}/lib/
    ${ROCM_SUDO_COMMAND} bash -c 'for i in libclang_rt.builtins-x86_64.a libhc_am.so libmcwamp.a libmcwamp_atomic.a libmcwamp_cpu.so libmcwamp_hsa.so; do ln -sf '"${ROCM_OUTPUT_DIR}"'/hcc/lib/${i} '"${ROCM_OUTPUT_DIR}"'/lib/${i}; done'
fi

if [ $ROCM_SAVE_SOURCE = false ]; then
    rm -rf ${SOURCE_DIR}
fi
