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
    echo "Installing software required to build comgr."
    echo "You will need to have root privileges to do this."
    sudo pacman -Sy --noconfirm --needed base-devel cmake pkgconf git
    if [ ${ROCM_INSTALL_PREREQS} = true ] && [ ${ROCM_FORCE_GET_CODE} = false ]; then
        exit 0
    fi
fi

# Set up source-code directory
if [ $ROCM_SAVE_SOURCE = true ]; then
    SOURCE_DIR=${ROCM_SOURCE_DIR}
    if [ ${ROCM_FORCE_GET_CODE} = true ] && [ -d ${SOURCE_DIR}/ROCm-CompilerSupport ]; then
        rm -rf ${SOURCE_DIR}/ROCm-CompilerSupport
    fi
    mkdir -p ${SOURCE_DIR}
else
    SOURCE_DIR=`mktemp -d`
fi
cd ${SOURCE_DIR}

# comgr requires AMD's LLVM, which is not installed from packages by default.
# As such, we need to check if the LLVM directory exists in the ROCM_INPUT_DIR.
# If it does not, we fall back to checking the ROCM_OUTPUT_DIR, since maybe
# the user just build LLVM before calling this script. IF they have not,
# we ask them if they would like to build LLVM first. If they do not, then
# this script will not work and we fail.
ROCM_LLVM_DIR=${ROCM_INPUT_DIR}/llvm/
if [ ! -d ${ROCM_INPUT_DIR}/llvm ]; then
    if [ -d ${ROCM_OUTPUT_DIR}/llvm ]; then
        ROCM_LLVM_DIR=${ROCM_OUTPUT_DIR}/llvm/
    elif [ -d ${SOURCE_DIR}/llvm ]; then
        ROCM_LLVM_DIR=${SOURCE_DIR}/llvm/
    elif [ -d ${SOURCE_DIR}/llvm_temp_install ]; then
        ROCM_LLVM_DIR=${SOURCE_DIR}/llvm_temp_install/
    else
        ROCM_REBUILD_LLVM=false
        echo ""
        echo "Unable to find ROCm LLVM in ${ROCM_INPUT_DIR}/llvm/, ${ROCM_OUTPUT_DIR}/llvm/,"
        echo "${SOURCE_DIR}/llvm/, or ${SOURCE_DIR}/llvm_temp_install/."
        echo "This is required in order to build comgr."
        if [ ${ROCM_FORCE_BUILD_ONLY} = true ]; then
            echo "However, you have chosen to do builds only, so we cannot install ROCm LLVM."
            echo "Unable to continue."
            exit 1
        fi
        if [ ${ROCM_FORCE_YES} = true ]; then
            echo "Forcing a build of the ROCm LLVM because of the '-y' flag."
            ROCM_REBUILD_LLVM=true
        elif [ ${ROCM_FORCE_NO} = true ]; then
            echo "Skipping a build of the ROCm LLVM because of the '-n' flag."
        else
            echo ""
            read -p "Do you want to try to build ROCm LLVM to fulfill this prerequisite (y/n)? " answer
            case ${answer:0:1} in
                y|Y )
                    ROCM_REBUILD_LLVM=true
                    echo 'User chose "yes". Forcing a build of ROCm LLVM.'
                ;;
                * )
                    echo 'User chose "no". Skipping a build of ROCm LLVM.'
                ;;
            esac
        fi

        if [ ${ROCM_REBUILD_LLVM} = true ]; then
            ${BASE_DIR}/01_11_rocm_device_libs.sh "$@"
            ROCM_LLVM_DIR=${ROCM_OUTPUT_DIR}/llvm/
        else
            echo "Unable to continue the build of comgr."
            exit 1
        fi
    fi
fi

# Download comgr
if [ ${ROCM_FORCE_GET_CODE} = true ] || [ ! -d ${SOURCE_DIR}/ROCm-CompilerSupport ]; then
    git clone https://github.com/RadeonOpenCompute/ROCm-CompilerSupport.git
    cd ROCm-CompilerSupport
    git checkout ${ROCM_COMGR_CHECKOUT}
else
    echo "Skipping download of comgr, since ${SOURCE_DIR}/ROCm-CompilerSupport already exists."
fi

if [ ${ROCM_FORCE_GET_CODE} = true ]; then
    echo "Finished downloading comgr. Exiting."
    exit 0
fi

cd ${SOURCE_DIR}/ROCm-CompilerSupport
cd lib/comgr/
mkdir -p build
cd build
cmake -DCMAKE_BUILD_TYPE=${ROCM_CMAKE_BUILD_TYPE} -DCMAKE_PREFIX_PATH="${ROCM_LLVM_DIR};${ROCM_INPUT_DIR}/lib" -DLLVM_DIR=${ROCM_LLVM_DIR} -DCMAKE_INSTALL_PREFIX=${ROCM_OUTPUT_DIR}/ -DCPACK_PACKAGING_INSTALL_PREFIX=${ROCM_OUTPUT_DIR}/ -DCPACK_GENERATOR=DEB ..
make -j `nproc`

if [ ${ROCM_FORCE_BUILD_ONLY} = true ]; then
    echo "Finished building comgr. Exiting."
    exit 0
fi

# if [ ${ROCM_FORCE_PACKAGE} = true ]; then
#     make package
#     echo "Copying `ls -1 comgr-*.deb` to ${ROCM_PACKAGE_DIR}"
#     mkdir -p ${ROCM_PACKAGE_DIR}
#     cp ./comgr-*.deb ${ROCM_PACKAGE_DIR}
#     if [ ${ROCM_LOCAL_INSTALL} = false ]; then
#         ROCM_PKG_IS_INSTALLED=`dpkg -l comgr | grep '^.i' | wc -l`
#         if [ ${ROCM_PKG_IS_INSTALLED} -gt 0 ]; then
#             PKG_NAME=`dpkg -l comgr | grep '^.i' | awk '{print $2}'`
#             sudo dpkg -r --force-depends ${PKG_NAME}
#         fi
#         sudo dpkg -i ./comgr-*.deb
#     fi
# else
    ${ROCM_SUDO_COMMAND} make install
    ${ROCM_SUDO_COMMAND} mkdir -p ${ROCM_OUTPUT_DIR}/include/comgr/
    #${ROCM_SUDO_COMMAND} cp ${ROCM_OUTPUT_DIR}/include/amd_comgr.h ${ROCM_OUTPUT_DIR}/include/comgr/
    #${ROCM_SUDO_COMMAND} cp ${ROCM_OUTPUT_DIR}/lib/libamd_comgr.so ${ROCM_OUTPUT_DIR}/lib/libcomgr.so
    #${ROCM_SUDO_COMMAND} cp ${ROCM_OUTPUT_DIR}/share/amd_comgr/ ${ROCM_OUTPUT_DIR}/
# fi

if [ $ROCM_SAVE_SOURCE = false ]; then
    rm -rf ${SOURCE_DIR}
fi
