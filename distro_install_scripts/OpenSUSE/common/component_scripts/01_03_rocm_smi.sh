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

# Install pre-reqs. rocm-smi requires git to download
if [ ${ROCM_LOCAL_INSTALL} = false ] || [ ${ROCM_INSTALL_PREREQS} = true ]; then
    echo "Installing software required by ROCm SMI."
    echo "You will need to have root privileges to do this."
    sudo dnf -y install python git make patch rpm-build
    if [ ${ROCM_INSTALL_PREREQS} = true ] && [ ${ROCM_FORCE_GET_CODE} = false ]; then
        exit 0
    fi
fi

# Set up source-code directory
if [ $ROCM_SAVE_SOURCE = true ]; then
    SOURCE_DIR=${ROCM_SOURCE_DIR}
    if [ ${ROCM_FORCE_GET_CODE} = true ] && [ -d ${SOURCE_DIR}/ROC-smi ]; then
        rm -rf ${SOURCE_DIR}/ROC-smi
    fi
    mkdir -p ${SOURCE_DIR}
else
    SOURCE_DIR=`mktemp -d`
fi
cd ${SOURCE_DIR}

# Download rocm-smi
if [ ${ROCM_FORCE_GET_CODE} = true ] || [ ! -d ${SOURCE_DIR}/ROC-smi ]; then
    git clone -b ${ROCM_VERSION_BRANCH} https://github.com/RadeonOpenCompute/ROC-smi.git
    cd ${SOURCE_DIR}/ROC-smi
    git checkout ${ROCM_SMI_CHECKOUT}
    patch -p1 < ${BASE_DIR}/patches/01_03_rocm_smi.patch
else
    echo "Skipping download of rocm-smi, since ${SOURCE_DIR}/ROC-smi already exists."
fi

if [ ${ROCM_FORCE_GET_CODE} = true ]; then
    echo "Finished downloading rocm-smi. Exiting."
    exit 0
fi

if [ ${ROCM_FORCE_BUILD_ONLY} = true ]; then
    echo "Nothing to build for rocm-smi. Exiting."
    exit 0
fi

cd ${SOURCE_DIR}/ROC-smi
if [ ${ROCM_FORCE_PACKAGE} = true ]; then
    sed -i 's#/opt/rocm/#'${ROCM_OUTPUT_DIR}/'#' ./RPM/rocm-smi.spec
    make rpm
    echo "Copying `ls -1 ./build/rpm/rocm-smi-*.rpm` to ${ROCM_PACKAGE_DIR}"
    mkdir -p ${ROCM_PACKAGE_DIR}
    cp ./build/rpm/rocm-smi-*.rpm ${ROCM_PACKAGE_DIR}
    if [ ${ROCM_LOCAL_INSTALL} = false ]; then
        ROCM_PKG_IS_INSTALLED=`rpm -qa | grep rocm-smi | wc -l`
        if [ ${ROCM_PKG_IS_INSTALLED} -gt 0 ]; then
            PKG_NAME=`rpm -qa | grep rocm-smi | head -n 1`
            sudo rpm -e --nodeps ${PKG_NAME}
        fi
        sudo rpm -i ./build/rpm/rocm-smi-*.rpm
    fi
else
    # Install rocm-smi
    ${ROCM_SUDO_COMMAND} mkdir -p ${ROCM_OUTPUT_DIR}/bin/
    ${ROCM_SUDO_COMMAND} cp -R rocm* ${ROCM_OUTPUT_DIR}/bin/
fi

if [ $ROCM_SAVE_SOURCE = false ]; then
    rm -rf ${SOURCE_DIR}
fi
