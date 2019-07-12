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
    echo "Installing software required to build the rocRAND."
    echo "You will need to have root privileges to do this."
    sudo dnf -y install cmake pkgconf-pkg-config git make gcc-c++ boost-program-options gcc-gfortran rpm-build
    sudo dnf -y install python-pip
    sudo pip install pyyaml
    if [ ${ROCM_INSTALL_PREREQS} = true ] && [ ${ROCM_FORCE_GET_CODE} = false ]; then
        exit 0
    fi
fi

# Set up source-code directory
if [ $ROCM_SAVE_SOURCE = true ]; then
    SOURCE_DIR=${ROCM_SOURCE_DIR}
    if [ ${ROCM_FORCE_GET_CODE} = true ] && [ -d ${SOURCE_DIR}/rocRAND ]; then
        rm -rf ${SOURCE_DIR}/rocRAND
    fi
    mkdir -p ${SOURCE_DIR}
else
    SOURCE_DIR=`mktemp -d`
fi
cd ${SOURCE_DIR}

# Download rocRAND
if [ ${ROCM_FORCE_GET_CODE} = true ] || [ ! -d ${SOURCE_DIR}/rocRAND ]; then
    git clone https://github.com/ROCmSoftwarePlatform/rocRAND.git
    cd rocRAND
    git checkout ${ROCM_ROCRAND_CHECKOUT}
else
    echo "Skipping download of rocRAND, since ${SOURCE_DIR}/rocRAND already exists."
fi

if [ ${ROCM_FORCE_GET_CODE} = true ]; then
    echo "Finished downloading rocRAND. Exiting."
    exit 0
fi

cd ${SOURCE_DIR}/rocRAND
mkdir -p build/release
cd build/release
HIP_PLATFORM=hcc ROCM_PATH=${ROCM_INPUT_DIR} CXX=${ROCM_INPUT_DIR}/hcc/bin/hcc cmake -DCPACK_PACKAGING_INSTALL_PREFIX=${ROCM_OUTPUT_DIR}/ -DCPACK_GENERATOR=RPM ${ROCM_CPACK_RPM_PERMISSIONS} -DCMAKE_BUILD_TYPE=${ROCM_CMAKE_BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_OUTPUT_DIR}/ -DCMAKE_MODULE_PATH=${ROCM_INPUT_DIR}/hip/cmake/ -DBUILD_TEST=OFF ../../
# Linking can take a large amount of memory, and it will fail if you do not
# have enough memory available per thread. As such, this # logic limits the
# number of build threads in response to the amount of available memory on
# the system.
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

if [ ${ROCM_FORCE_BUILD_ONLY} = true ]; then
    echo "Finished building rocRAND. Exiting."
    exit 0
fi

if [ ${ROCM_FORCE_PACKAGE} = true ]; then
    make package
    echo "Copying `ls -1 rocrand-*.rpm` to ${ROCM_PACKAGE_DIR}"
    mkdir -p ${ROCM_PACKAGE_DIR}
    cp ./rocrand-*.rpm ${ROCM_PACKAGE_DIR}
    if [ ${ROCM_LOCAL_INSTALL} = false ]; then
        ROCM_PKG_IS_INSTALLED=`rpm -qa | grep rocrand | wc -l`
        if [ ${ROCM_PKG_IS_INSTALLED} -gt 0 ]; then
            PKG_NAME=`rpm -qa | grep rocrand | head -n 1`
            sudo rpm -e --nodeps ${PKG_NAME}
        fi
        sudo rpm -i ./rocrand-*.rpm
    fi
else
    ${ROCM_SUDO_COMMAND} make install

    ${ROCM_SUDO_COMMAND} mkdir -p ${ROCM_OUTPUT_DIR}/hiprand/include/../../include/
    ${ROCM_SUDO_COMMAND} mkdir -p ${ROCM_OUTPUT_DIR}/hiprand/lib/../../lib/cmake/hiprand
    if [ ${ROCM_LOCAL_INSTALL} = false ]; then
        echo ${ROCM_OUTPUT_DIR}/hiprand/lib | ${ROCM_SUDO_COMMAND} tee -a /etc/ld.so.conf.d/hiprand.conf
    fi
    ${ROCM_SUDO_COMMAND} ln -sfr ${ROCM_OUTPUT_DIR}/hiprand/include ${ROCM_OUTPUT_DIR}/hiprand/include/../../include/hiprand
    ${ROCM_SUDO_COMMAND} ln -sfr ${ROCM_OUTPUT_DIR}/hiprand/lib/libhiprand.so ${ROCM_OUTPUT_DIR}/hiprand/lib/../../lib/libhiprand.so
    ${ROCM_SUDO_COMMAND} ln -sfr ${ROCM_OUTPUT_DIR}/hiprand/lib/cmake/hiprand ${ROCM_OUTPUT_DIR}/hiprand/lib/../../lib/cmake/hiprand

    ${ROCM_SUDO_COMMAND} mkdir -p ${ROCM_OUTPUT_DIR}/rocrand/include/../../include/
    ${ROCM_SUDO_COMMAND} mkdir -p ${ROCM_OUTPUT_DIR}/rocrand/lib/../../lib/cmake/rocrand
    if [ ${ROCM_LOCAL_INSTALL} = false ]; then
        echo ${ROCM_OUTPUT_DIR}/rocrand/lib | ${ROCM_SUDO_COMMAND} tee -a /etc/ld.so.conf.d/rocrand.conf
    fi
    ${ROCM_SUDO_COMMAND} ln -sfr ${ROCM_OUTPUT_DIR}/rocrand/include ${ROCM_OUTPUT_DIR}/rocrand/include/../../include/rocrand
    ${ROCM_SUDO_COMMAND} ln -sfr ${ROCM_OUTPUT_DIR}/rocrand/lib/librocrand.so ${ROCM_OUTPUT_DIR}/rocrand/lib/../../lib/librocrand.so
    ${ROCM_SUDO_COMMAND} ln -sfr ${ROCM_OUTPUT_DIR}/rocrand/lib/cmake/rocrand ${ROCM_OUTPUT_DIR}/rocrand/lib/../../lib/cmake/rocrand
fi

if [ $ROCM_SAVE_SOURCE = false ]; then
    rm -rf ${SOURCE_DIR}
fi
