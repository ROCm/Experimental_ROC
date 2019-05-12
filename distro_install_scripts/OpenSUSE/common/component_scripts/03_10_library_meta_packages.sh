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

# This script only builds meta-packages which do not have source code.
# If we are not building packages, skip it.
if [ ${ROCM_FORCE_PACKAGE} = false ]; then
    exit 0
fi

# Need to be able to build RPM files if we want to create meta-packages
if [ ${ROCM_LOCAL_INSTALL} = false ] || [ ${ROCM_INSTALL_PREREQS} = true ]; then
    echo "Installing software required to build meta-packages"
    echo "You will need to have root privileges to do this."
    sudo zypper -n in rpm-build
    if [ ${ROCM_INSTALL_PREREQS} = true ] && [ ${ROCM_FORCE_GET_CODE} = false ]; then
        exit 0
    fi
fi

# Set up source-code directory
if [ $ROCM_SAVE_SOURCE = true ]; then
    SOURCE_DIR=${ROCM_SOURCE_DIR}
    if [ ${ROCM_FORCE_GET_CODE} = true ] && [ -d ${SOURCE_DIR}/meta_packages ]; then
        rm -rf ${SOURCE_DIR}/meta_packages
    fi
else
    SOURCE_DIR=`mktemp -d`
fi
mkdir -p ${SOURCE_DIR}/meta_packages
cd ${SOURCE_DIR}/meta_packages

if [ ${ROCM_FORCE_GET_CODE} = true ]; then
    echo "No code download is required for this. Exiting."
    exit 0
fi

if [ ${ROCM_FORCE_BUILD_ONLY} = true ]; then
    echo "No build is required for this. Existing."
    exit 0
fi

# Our libraries ROCm meta-package is:
#  * rocm-libs, which depends/installs: rocblas, rocfft, rocrand, and hipblas
if [ ${ROCM_FORCE_PACKAGE} = true ]; then
    for pkg_name in rocm-libs; do
        mkdir -p ${SOURCE_DIR}/meta_packages/${pkg_name}
        cd ${SOURCE_DIR}/meta_packages/${pkg_name}/
        pushd ${BASE_DIR}/../common/
        cp ./${pkg_name}.spec ${SOURCE_DIR}/meta_packages/${pkg_name}/
        popd
        sed -i 's/ROCM_PKG_VERSION/'${ROCM_VERSION_LONG}'/g' ./${pkg_name}.spec
        sed -i 's#ROCM_OUTPUT_DIR#'${ROCM_OUTPUT_DIR%/}'#g' ./${pkg_name}.spec
        mkdir -p $(pwd)/${ROCM_OUTPUT_DIR}/.info/
        echo ${ROCM_VERSION_LONG} > $(pwd)/${ROCM_OUTPUT_DIR}/.info/version-libs
        RPM_TEMP_DIR=`mktemp -d`
        rpmbuild -bb --clean --define "_topdir ${RPM_TEMP_DIR}" ./${pkg_name}.spec
        cp ${RPM_TEMP_DIR}/RPMS/x86_64/${pkg_name}-*.rpm .
        rm -rf ${RPM_TEMP_DIR}
        echo "Copying `ls -1 ${pkg_name}-*.rpm` to ${ROCM_PACKAGE_DIR}"
        mkdir -p ${ROCM_PACKAGE_DIR}
        cp ${pkg_name}-*.rpm ${ROCM_PACKAGE_DIR}
        if [ ${ROCM_LOCAL_INSTALL} = false ]; then
            ROCM_PKG_IS_INSTALLED=`rpm -qa | grep ${pkg_name} | wc -l`
            if [ ${ROCM_PKG_IS_INSTALLED} -gt 0 ]; then
                FULL_PKG_NAME=`rpm -qa | grep ${pkg_name} | head -n 1`
                sudo rpm -e --nodeps ${FULL_PKG_NAME}
            fi
            sudo rpm -i ${pkg_name}-*.rpm
        fi
    done
fi

if [ $ROCM_SAVE_SOURCE = false ]; then
    rm -rf ${SOURCE_DIR}
fi
