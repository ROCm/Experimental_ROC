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
    echo "Installing software required to build the rocSPARSE."
    echo "You will need to have root privileges to do this."
    sudo zypper -n in cmake pkg-config git make gcc-c++ libboost_program_options1_66_0 rpm-build
    if [ ${ROCM_INSTALL_PREREQS} = true ] && [ ${ROCM_FORCE_GET_CODE} = false ]; then
        exit 0
    fi
fi

# Set up source-code directory
if [ $ROCM_SAVE_SOURCE = true ]; then
    SOURCE_DIR=${ROCM_SOURCE_DIR}
    if [ ${ROCM_FORCE_GET_CODE} = true ] && [ -d ${SOURCE_DIR}/rocSPARSE ]; then
        rm -rf ${SOURCE_DIR}/rocSPARSE
    fi
    mkdir -p ${SOURCE_DIR}
else
    SOURCE_DIR=`mktemp -d`
fi
cd ${SOURCE_DIR}

# Download rocSPARSE
if [ ${ROCM_FORCE_GET_CODE} = true ] || [ ! -d ${SOURCE_DIR}/rocSPARSE ]; then
    git clone https://github.com/ROCmSoftwarePlatform/rocSPARSE.git
    cd rocSPARSE
    git checkout ${ROCM_ROCSPARSE_CHECKOUT}
else
    echo "Skipping download of rocSPARSE, since ${SOURCE_DIR}/rocSPARSE already exists."
fi

if [ ${ROCM_FORCE_GET_CODE} = true ]; then
    echo "Finished downloading rocSPARSE. Exiting."
    exit 0
fi

cd ${SOURCE_DIR}/rocSPARSE
mkdir -p build/release

# Fix some hard-coded locations in the CMake files
git checkout ./cmake/Dependencies.cmake
sed -i s'#/opt/rocm/bin/hcc#${HIP_HCC_EXECUTABLE} -DCMAKE_PREFIX_PATH='"${ROCM_INPUT_DIR}"' -DCMAKE_MODULE_PATH='"${ROCM_INPUT_DIR}"'/hip/cmake/#'  ./cmake/Dependencies.cmake

cd build/release
HIP_PLATFORM=hcc CXX=${ROCM_INPUT_DIR}/hcc/bin/hcc cmake -DCPACK_PACKAGING_INSTALL_PREFIX=${ROCM_OUTPUT_DIR}/ -DCPACK_GENERATOR=RPM ${ROCM_CPACK_RPM_PERMISSIONS} -DCMAKE_BUILD_TYPE=${ROCM_CMAKE_BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_OUTPUT_DIR}/ -DCMAKE_PREFIX_PATH=${ROCM_INPUT_DIR} -DCMAKE_MODULE_PATH=${ROCM_INPUT_DIR}/hip/cmake/ ../../
make -j `nproc`


if [ ${ROCM_FORCE_BUILD_ONLY} = true ]; then
    echo "Finished building rocSPARSE. Exiting."
    exit 0
fi

if [ ${ROCM_FORCE_PACKAGE} = true ]; then
    make package
    echo "Copying `ls -1 rocsparse-*.rpm` to ${ROCM_PACKAGE_DIR}"
    mkdir -p ${ROCM_PACKAGE_DIR}
    cp ./rocsparse-*.rpm ${ROCM_PACKAGE_DIR}
    if [ ${ROCM_LOCAL_INSTALL} = false ]; then
        ROCM_PKG_IS_INSTALLED=`rpm -qa | grep rocsparse | wc -l`
        if [ ${ROCM_PKG_IS_INSTALLED} -gt 0 ]; then
            PKG_NAME=`rpm -qa | grep rocsparse | head -n 1`
            sudo rpm -e --nodeps ${PKG_NAME}
        fi
        sudo rpm -i ./rocsparse-*.rpm
    fi
else
    ${ROCM_SUDO_COMMAND} make install

    if [ ${ROCM_LOCAL_INSTALL} = false ]; then
        echo ${ROCM_OUTPUT_DIR}/lib | ${ROCM_SUDO_COMMAND} tee -a /etc/ld.so.conf.d/rocsparse.conf
    fi
fi

if [ $ROCM_SAVE_SOURCE = false ]; then
    rm -rf ${SOURCE_DIR}
fi
