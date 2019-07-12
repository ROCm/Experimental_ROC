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
    echo "Installing software required to build the ROCr debug agent."
    echo "You will need to have root privileges to do this."
    sudo pacman -Sy --noconfirm --needed base-devel cmake pkgconf git patch libelf
    if [ ${ROCM_INSTALL_PREREQS} = true ] && [ ${ROCM_FORCE_GET_CODE} = false ]; then
        exit 0
    fi
fi

# Set up source-code directory
if [ $ROCM_SAVE_SOURCE = true ]; then
    SOURCE_DIR=${ROCM_SOURCE_DIR}
    if [ ${ROCM_FORCE_GET_CODE} = true ] && [ -d ${SOURCE_DIR}/rocr_debug_agent ]; then
        rm -rf ${SOURCE_DIR}/rocr_debug_agent
    fi
    mkdir -p ${SOURCE_DIR}
else
    SOURCE_DIR=`mktemp -d`
fi
cd ${SOURCE_DIR}

# Download ROCr debug agent
if [ ${ROCM_FORCE_GET_CODE} = true ] || [ ! -d ${SOURCE_DIR}/rocr_debug_agent ]; then
    git clone -b ${ROCM_VERSION_BRANCH} https://github.com/ROCm-Developer-Tools/rocr_debug_agent.git
    cd ${SOURCE_DIR}/rocr_debug_agent/
    git checkout ${ROCR_DEBUG_AGENT_CHECKOUT}

    # The debug agent in ROCm 2.0.0 does not build with GCC 8.
    # If we have that, patch the problem out.
    GCC_VERSION=`gcc --version | head -n 1 | awk '{print $NF}' | awk -F "." '{print $1}'`
    if [ ${GCC_VERSION} -ge 8 ]; then
        patch -p 1 < ${BASE_DIR}/patches/01_14_rocr_debug_agent.patch
    fi
else
    echo "Skipping download of ROCr debug agent, since ${SOURCE_DIR}/rocr_debug_agent already exists."
fi

if [ ${ROCM_FORCE_GET_CODE} = true ]; then
    echo "Finished downloading ROCr debug agent. Exiting."
    exit 0
fi

cd ${SOURCE_DIR}/rocr_debug_agent/src
mkdir -p build
cd build

# Time for a pretty gross workaround. The ROCm device libraries installs
# outdated copies of hsa.h and amd_hsa_*.h to ROCM_INSTALL/include/.  This
# means that if you try to point the ROCr build system at ROCM_INSTALL/include/
# directory, ROCr will pick up outdated verisons of these files and the built
# will fail spectacularly. We can't just fix this in our current ROCm Device
# Libs build because someone may want to use this script to build ROCr on a
# from-package ROCm installation.
# We also can't include a different include, as these bad hsa files are
# dumped into the same directory as our required hsakmt.h Thunk headers.
# INSTEAD, our ugly hack is to make a temporary "ROCm include directory" that
# removes the outdated hsa files, and point our build system towards that.
# Then delete it after our build is complete.
TEMP_INCLUDE_DIR=`mktemp -d`
cp -LR ${ROCM_INPUT_DIR}/include/* ${TEMP_INCLUDE_DIR}
rm -f ${TEMP_INCLUDE_DIR}/hsa.h
rm -f ${TEMP_INCLUDE_DIR}/amd_hsa_*.h
# Since the temporary include directory can change each time this script is
# called, delete any old build stuff sitting around.
rm -rf ${SOURCE_DIR}/rocr_debug_agent/src/build/*
cmake -DCMAKE_BUILD_TYPE=${ROCM_CMAKE_BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_OUTPUT_DIR}/ -DCMAKE_PREFIX_PATH="${ROCM_INPUT_DIR}/opencl/bin/x86_64/" -DCMAKE_INCLUDE_PATH="${TEMP_INCLUDE_DIR};${ROCM_INPUT_DIR}/include/hsa/" -DCPACK_PACKAGING_INSTALL_PREFIX=${ROCM_OUTPUT_DIR}/ -DCPACK_GENERATOR=DEB ..
make -j `nproc`

if [ ${ROCM_FORCE_BUILD_ONLY} = true ]; then
    echo "Finished building ROCr debug agent. Exiting."
    exit 0
fi

if [ ${ROCM_FORCE_PACKAGE} = true ]; then
    echo "Sorry, packaging not yet implemented for this distribution"
    exit 2
#     make package
#     echo "Copying `ls -1 rocr_debug_agent-*.deb` to ${ROCM_PACKAGE_DIR}"
#     mkdir -p ${ROCM_PACKAGE_DIR}
#     cp ./rocr_debug_agent-*.deb ${ROCM_PACKAGE_DIR}
#     if [ ${ROCM_LOCAL_INSTALL} = false ]; then
#         sudo dpkg -i ./rocr_debug_agent-*.deb
#     fi
else
    ${ROCM_SUDO_COMMAND} make install
fi

if [ $ROCM_SAVE_SOURCE = false ]; then
    rm -rf ${SOURCE_DIR}
fi
