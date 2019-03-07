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

# Install pre-reqs. We might need build-essential and cmake if nobody
# ran the higher-level build scripts.
if [ ${ROCM_LOCAL_INSTALL} = false ] || [ ${ROCM_INSTALL_PREREQS} = true ]; then
    echo "Installing software required to build ROCm CMAKE."
    echo "You will need to have root privileges to do this."
    sudo pacman -Sy --noconfirm --needed base-devel cmake pkgconf git
    if [ ${ROCM_INSTALL_PREREQS} = true ] && [ ${ROCM_FORCE_GET_CODE} = false ]; then
        exit 0
    fi
fi

# Set up source-code directory
if [ $ROCM_SAVE_SOURCE = true ]; then
    SOURCE_DIR=${ROCM_SOURCE_DIR}
    if [ ${ROCM_FORCE_GET_CODE} = true ] && [ -d ${SOURCE_DIR}/rocm-cmake ]; then
        rm -rf ${SOURCE_DIR}/rocm-cmake
    fi
    mkdir -p ${SOURCE_DIR}
else
    SOURCE_DIR=`mktemp -d`
fi
cd ${SOURCE_DIR}

# Download ROCm Cmake
if [ ${ROCM_FORCE_GET_CODE} = true ] || [ ! -d ${SOURCE_DIR}/rocm-cmake ]; then
    git clone https://github.com/RadeonOpenCompute/rocm-cmake.git
    cd ${SOURCE_DIR}/rocm-cmake
    git checkout ${ROCM_CMAKE_CHECKOUT}
else
    echo "Skipping download of ROCm cmake, since ${SOURCE_DIR}/rocm-cmake already exists."
fi

if [ ${ROCM_FORCE_GET_CODE} = true ]; then
    echo "Finished downloading rocm-cmake. Exiting."
    exit 0
fi

# Build, and install ROCm Cmake
cd ${SOURCE_DIR}/rocm-cmake
mkdir -p build
cd build
# There is no pacman cpack generator. It should(?) be possible to hook makepkg up to it through the external generator
# but that feels like much more hassle than it's worth. Instead, I think I'll just write the PKGBUILD files later and
# call the tool manually
cmake .. -DCMAKE_BUILD_TYPE=${ROCM_CMAKE_BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_OUTPUT_DIR}/ -DCPACK_PACKAGING_INSTALL_PREFIX=${ROCM_OUTPUT_DIR}/ -DCPACK_GENERATOR=DEB

if [ ${ROCM_FORCE_BUILD_ONLY} = true ]; then
    echo "Nothing to build for rocm-cmake. Exiting."
    exit 0
fi

# if [ ${ROCM_FORCE_PACKAGE} = true ]; then
#     cmake --build . --target package
#     echo "Copying `ls -1 rocm-cmake-*.deb` to ${ROCM_PACKAGE_DIR}"
#     mkdir -p ${ROCM_PACKAGE_DIR}
#     cp ./rocm-cmake-*.deb ${ROCM_PACKAGE_DIR}
#     if [ ${ROCM_LOCAL_INSTALL} = false ]; then
#         ROCM_PKG_IS_INSTALLED=`dpkg -l rocm-cmake | grep '^.i' | wc -l`
#         if [ ${ROCM_PKG_IS_INSTALLED} -gt 0 ]; then
#             PKG_NAME=`dpkg -l rocm-cmake | grep '^.i' | awk '{print $2}'`
#             sudo dpkg -r --force-depends ${PKG_NAME}
#         fi
#         sudo dpkg -i rocm-cmake-*.deb
#     fi
# else
    ${ROCM_SUDO_COMMAND} cmake --build . --target install
# fi

if [ $ROCM_SAVE_SOURCE = false ]; then
    rm -rf ${SOURCE_DIR}
fi
