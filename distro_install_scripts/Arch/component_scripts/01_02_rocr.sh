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
trap 'print_cmd=$lastcmd; errno=$?; if [ $errno -ne 0 ]; then echo "\"${print_cmd}\" command failed with exit code $errno."; fi' EXIT
source "$BASE_DIR/../common_options.sh"
parse_args "$@"

# Install pre-reqs. We might need base-devel, cmake, and git if nobody
# ran the higher-level build scripts. Definitely need libelf for ROCr.
if [ ${ROCM_LOCAL_INSTALL} = false ] || [ ${ROCM_INSTALL_PREREQS} = true ]; then
    echo "Installing software required to build ROCr runtime."
    echo "You will need to have root privileges to do this."
    sudo pacman -Sy --noconfirm --needed base-devel cmake pkgconf git libelf patch
    if [ ${ROCM_INSTALL_PREREQS} = true ] && [ ${ROCM_FORCE_GET_CODE} = false ]; then
        exit 0
    fi
fi

# Set up source-code directory
if [ $ROCM_SAVE_SOURCE = true ]; then
    SOURCE_DIR=${ROCM_SOURCE_DIR}
    if [ ${ROCM_FORCE_GET_CODE} = true ] && [ -d ${SOURCE_DIR}/ROCR-Runtime ]; then
        rm -rf ${SOURCE_DIR}/ROCR-Runtime
    fi
    mkdir -p ${SOURCE_DIR}
else
    SOURCE_DIR=`mktemp -d`
fi
cd ${SOURCE_DIR}

# Download ROCr
if [ ${ROCM_FORCE_GET_CODE} = true ] || [ ! -d ${SOURCE_DIR}/ROCR-Runtime ]; then
    git clone -b ${ROCM_VERSION_BRANCH} https://github.com/RadeonOpenCompute/ROCR-Runtime.git
    cd ${SOURCE_DIR}/ROCR-Runtime/src
    git checkout ${ROCM_ROCR_CHECKOUT}
    cd ${SOURCE_DIR}/ROCR-Runtime/
    patch -p1 < ${BASE_DIR}/patches/01_02_rocr.patch
    cd ${SOURCE_DIR}/ROCR-Runtime/src
else
    echo "Skipping download of ROCr, since ${SOURCE_DIR}/ROCR-Runtime already exists."
fi

if [ ${ROCM_FORCE_GET_CODE} = true ]; then
    echo "Finished downloading ROCr. Exiting."
    exit 0
fi

# Build, and install ROCr
cd ${SOURCE_DIR}/ROCR-Runtime/src
mkdir -p build
cd build

# Time for a pretty gross workaround. The ROCm device libraries installs
# outdated copies of hsa.h and amd_hsa_*.h to ROCM_INSTALL/include/.  This
# means that if you try to point the ROCr build system at ROCM_INSTALL/include/
# directory, ROCr will pick up outdated verisons of these files and the built
# will fail spectacularly. We can't just fix this in our current ROCm Device
# Libs build because someone may want to use this script to build ROCr on a
# from-package ROCm installation.
# We also can't point ROCr to a different include directory, as these bad
# hsa files are dumped into the same directory as our required hsakmt.h Thunk
# headers.
# INSTEAD, our ugly hack is to make a temporary "ROCm include directory" that
# removes the outdated hsa files, and point our build system towards that.
# Then delete it after our build is complete.
TEMP_INCLUDE_DIR=`mktemp -d`
cp -LR ${ROCM_INPUT_DIR}/include/* ${TEMP_INCLUDE_DIR}
rm -f ${TEMP_INCLUDE_DIR}/hsa.h
rm -f ${TEMP_INCLUDE_DIR}/amd_hsa_*.h
# Since the temporary include directory can change each time this script is
# called, delete any old build stuff sitting around.
rm -rf ${SOURCE_DIR}/ROCR-Runtime/src/build/*
cmake .. -DCMAKE_BUILD_TYPE=${ROCM_CMAKE_BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_OUTPUT_DIR}/ -DCPACK_PACKAGING_INSTALL_PREFIX=${ROCM_OUTPUT_DIR}/ -DCPACK_GENERATOR=DEB -DCMAKE_LIBRARY_PATH=${ROCM_INPUT_DIR}/lib/ -DCMAKE_INCLUDE_PATH=${TEMP_INCLUDE_DIR}
make -j `nproc`

if [ ${ROCM_FORCE_BUILD_ONLY} = true ]; then
    echo "Finished building ROCr. Exiting."
    exit 0
fi

# if [ ${ROCM_FORCE_PACKAGE} = true ]; then
#     make package
#     echo "Copying `ls -1 hsa-rocr-dev-*.deb` to ${ROCM_PACKAGE_DIR}"
#     mkdir -p ${ROCM_PACKAGE_DIR}
#     cp hsa-rocr-dev-*.deb ${ROCM_PACKAGE_DIR}
#     if [ ${ROCM_LOCAL_INSTALL} = false ]; then
#         ROCM_PKG_IS_INSTALLED=`dpkg -l hsa-rocr-dev | grep '^.i' | wc -l`
#         if [ ${ROCM_PKG_IS_INSTALLED} -gt 0 ]; then
#             PKG_NAME=`dpkg -l hsa-rocr-dev | grep '^.i' | awk '{print $2}'`
#             sudo dpkg -r --force-depends ${PKG_NAME}
#         fi
#         sudo dpkg -i hsa-rocr-dev-*.deb
#     fi
# else
    ${ROCM_SUDO_COMMAND} make install

    if [ ${ROCM_LOCAL_INSTALL} = false ]; then
        ${ROCM_SUDO_COMMAND} sh -c "echo ${ROCM_OUTPUT_DIR}/hsa/lib > /etc/ld.so.conf.d/hsa-rocr-dev.conf"
        ${ROCM_SUDO_COMMAND} ldconfig
    fi
# fi
rm -rf ${TEMP_INCLUDE_DIR}

if [ $ROCM_SAVE_SOURCE = false ]; then
    rm -rf ${SOURCE_DIR}
fi
