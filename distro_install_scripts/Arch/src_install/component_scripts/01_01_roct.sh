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

# Install pre-reqs. We might need build-essential, cmake, and git if nobody
# ran the higher-level build scripts. Definitely need libnuma-dev for ROCt.
# We need 'rpm' because this makefile will always try to build RPMs..
if [ ${ROCM_LOCAL_INSTALL} = false ] || [ ${ROCM_INSTALL_PREREQS} = true ]; then
    echo "Installing software required to build ROCt Thunk layer."
    echo "You will need to have root privileges to do this."
    sudo pacman -Sy --noconfirm --needed base-devel cmake pkgconf git pciutils numactl
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
    git clone -b ${ROCM_VERSION_BRANCH} https://github.com/RadeonOpenCompute/ROCT-Thunk-Interface.git
    cd ${SOURCE_DIR}/ROCT-Thunk-Interface/
    git checkout ${ROCM_ROCT_CHECKOUT}
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
cmake .. -DCMAKE_BUILD_TYPE=${ROCM_CMAKE_BUILD_TYPE} -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_INSTALL_PREFIX=${ROCM_OUTPUT_DIR}/ -DCPACK_PACKAGING_INSTALL_PREFIX=${ROCM_OUTPUT_DIR}/ -DCPACK_GENERATOR=DEB
make -j `nproc`
make -j `nproc` build-dev

if [ ${ROCM_FORCE_BUILD_ONLY} = true ]; then
    echo "Finished building ROCt. Exiting."
    exit 0
fi

if [ ${ROCM_FORCE_PACKAGE} = true ]; then
    echo "Sorry, packaging not yet implemented for this distribution"
    exit 2
    # make package
    # echo "Copying `ls -1 hsakmt-roct-*.deb` to ${ROCM_PACKAGE_DIR}"
    # mkdir -p ${ROCM_PACKAGE_DIR}
    # cp hsakmt-roct-*.deb ${ROCM_PACKAGE_DIR}
    # if [ ${ROCM_LOCAL_INSTALL} = false ]; then
    #     ROCM_PKG_IS_INSTALLED=`dpkg -l hsakmt-roct-[0-9] | grep '^.i' | wc -l`
    #     if [ ${ROCM_PKG_IS_INSTALLED} -gt 0 ]; then
    #         PKG_NAME=`dpkg -l hsakmt-roct-[0-9] | grep '^.i' | awk '{print $2}'`
    #         sudo dpkg -r --force-depends ${PKG_NAME}
    #     fi
    #     sudo dpkg -i hsakmt-roct-*.deb
    # fi
    # cd hsakmt-roct-dev
    # make package
    # echo "Copying `ls -1 hsakmt-roct-dev-*.deb` to ${ROCM_PACKAGE_DIR}"
    # cp hsakmt-roct-dev-*.deb ${ROCM_PACKAGE_DIR}
    # if [ ${ROCM_LOCAL_INSTALL} = false ]; then
    #     ROCM_PKG_IS_INSTALLED=`dpkg -l hsakmt-roct-dev | grep '^.i' | wc -l`
    #     if [ ${ROCM_PKG_IS_INSTALLED} -gt 0 ]; then
    #         PKG_NAME=`dpkg -l hsakmt-roct-dev | grep '^.i' | awk '{print $2}'`
    #         sudo dpkg -r --force-depends ${PKG_NAME}
    #     fi
    #     sudo dpkg -i hsakmt-roct-dev-*.deb
    # fi
else
    ${ROCM_SUDO_COMMAND} mkdir -p ${ROCM_OUTPUT_DIR}/lib/
    ${ROCM_SUDO_COMMAND} make install
    ${ROCM_SUDO_COMMAND} make install-dev

    if [ ${ROCM_LOCAL_INSTALL} = false ]; then
        ${ROCM_SUDO_COMMAND} sh -c "echo ${ROCM_OUTPUT_DIR}/lib > /etc/ld.so.conf.d/x86_64-libhsakmt.conf"
        ${ROCM_SUDO_COMMAND} ldconfig
    fi
fi

if [ $ROCM_SAVE_SOURCE = false ]; then
    rm -rf ${SOURCE_DIR}
fi
