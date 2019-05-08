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

# Install pre-reqs. We need DKMS for installing and building the driver.
# If getting the driver source by extracting the RPM, we will need wget
if [ ${ROCM_LOCAL_INSTALL} = false ] || [ ${ROCM_INSTALL_PREREQS} = true ]; then
    echo "Installing software required to build ROCK kernel driver."
    echo "You will need to have root privileges to do this."
    sudo zypper -n in kernel-devel dkms wget xz
fi

# Set up source-code directory
if [ $ROCM_SAVE_SOURCE = true ]; then
    SOURCE_DIR=${ROCM_SOURCE_DIR}/rock/
    if [ ${ROCM_FORCE_GET_CODE} = true ] && [ -d ${SOURCE_DIR} ]; then
        rm -rf ${SOURCE_DIR}
    fi
    mkdir -p ${SOURCE_DIR}
else
    SOURCE_DIR=`mktemp -d`
fi
cd ${SOURCE_DIR}
mkdir -p install_files/

# Download rocm-dkms source code
if [ ${ROCM_FORCE_GET_CODE} = true ] || [ ! -d ${SOURCE_DIR}/install_files/usr/ ]; then
    echo "Downloading ROCK kernel drivers."
    # One way to download this is to get the already-packaged DKMS and extract
    # the source code from it. Unlike the rest of the ROCm packages, the kernel
    # driver package actually includes the source code, since DKMS modules are
    # rebuilt every time the kernel is updated.
    #cd ${SOURCE_DIR}/install_files/
    #wget http://repo.radeon.com/rocm/yum/rpm/rock-dkms-2.0-89.noarch.rpm
    #rpm2cpio rock-dkms-2.0-89.noarch.rpm | cpio -idm
    # However, this work below gets our source from github and "recreates" the
    # package. These build scripts carry some of the DKMS files with them
    # so you don't need to download the entire thing from repo.radeon.com
    cd ${SOURCE_DIR}/
    git clone --branch ${ROCM_VERSION_BRANCH} --single-branch --depth 1 https://github.com/RadeonOpenCompute/ROCK-Kernel-Driver.git
    cd ${SOURCE_DIR}/ROCK-Kernel-Driver
    git fetch --depth=1 origin "+refs/${ROCM_ROCK_CHECKOUT}:refs/${ROCM_ROCK_CHECKOUT}"
    git checkout ${ROCM_ROCK_CHECKOUT}

    cd ${SOURCE_DIR}/install_files/
    pushd ${BASE_DIR}/rock_files/
    cp -RL ./* ${SOURCE_DIR}/install_files/
    popd

    cd ${SOURCE_DIR}/install_files/usr/src/amdgpu-2.0-89/
    cp -R ${SOURCE_DIR}/ROCK-Kernel-Driver/drivers/gpu/drm/amd ${SOURCE_DIR}/install_files/usr/src/amdgpu-2.0-89/
    cd ${SOURCE_DIR}/install_files/usr/src/amdgpu-2.0-89/
    tar -xJf ${SOURCE_DIR}/install_files/usr/src/amdgpu-2.0-89/firmware.tar.xz
    cd ${SOURCE_DIR}/install_files/
    mkdir -p ${SOURCE_DIR}/install_files/usr/src/amdgpu-2.0-89/include/drm/ttm
    for file in amd_rdma.h gpu_scheduler.h spsc_queue.h; do
        cp ${SOURCE_DIR}/ROCK-Kernel-Driver/include/drm/${file} ${SOURCE_DIR}/install_files/usr/src/amdgpu-2.0-89/include/drm/
    done
    cp ${SOURCE_DIR}/ROCK-Kernel-Driver/drivers/gpu/drm/scheduler/gpu_scheduler_trace.h ${SOURCE_DIR}/install_files/usr/src/amdgpu-2.0-89/include/drm/
    cp ${SOURCE_DIR}/ROCK-Kernel-Driver/include/drm/ttm/* ${SOURCE_DIR}/install_files/usr/src/amdgpu-2.0-89/include/drm/ttm/
    mkdir -p ${SOURCE_DIR}/install_files/usr/src/amdgpu-2.0-89/include/kcl
    cp ${SOURCE_DIR}/ROCK-Kernel-Driver/include/kcl/* ${SOURCE_DIR}/install_files/usr/src/amdgpu-2.0-89/include/kcl/
    mkdir -p ${SOURCE_DIR}/install_files/usr/src/amdgpu-2.0-89/include/uapi/drm
    cp ${SOURCE_DIR}/ROCK-Kernel-Driver/include/uapi/drm/amdgpu_drm.h ${SOURCE_DIR}/install_files/usr/src/amdgpu-2.0-89/include/uapi/drm/
    mkdir -p ${SOURCE_DIR}/install_files/usr/src/amdgpu-2.0-89/include/uapi/linux
    cp ${SOURCE_DIR}/ROCK-Kernel-Driver/include/uapi/linux/kfd_ioctl.h ${SOURCE_DIR}/install_files/usr/src/amdgpu-2.0-89/include/uapi/linux/
    mkdir -p ${SOURCE_DIR}/install_files/usr/src/amdgpu-2.0-89/radeon/
    cp ${SOURCE_DIR}/ROCK-Kernel-Driver/drivers/gpu/drm/radeon/cik_reg.h ${SOURCE_DIR}/install_files/usr/src/amdgpu-2.0-89/radeon/
    cp -R ${SOURCE_DIR}/ROCK-Kernel-Driver/drivers/gpu/drm/scheduler ${SOURCE_DIR}/install_files/usr/src/amdgpu-2.0-89/
    cp ${SOURCE_DIR}/install_files/usr/src/amdgpu-2.0-89/amd/dkms/sources ${SOURCE_DIR}/install_files/usr/src/amdgpu-2.0-89/
    cp -R ${SOURCE_DIR}/ROCK-Kernel-Driver/drivers/gpu/drm/ttm ${SOURCE_DIR}/install_files/usr/src/amdgpu-2.0-89/
else
    echo "Skipping download of ROCK kernel drivers, since ${SOURCE_DIR}/install_files/usr/ already exists."
fi

if [ ${ROCM_FORCE_GET_CODE} = true ]; then
    echo "Finished downloading ROCK kernel drivers. Exiting."
    exit 0
fi

if [ ${ROCM_FORCE_BUILD_ONLY} = true ]; then
    echo "Nothing to build for ROCK kernel driver unless you are installing. Exiting."
    exit 0
fi

ROCM_SKIP_INSTALLING=false
if [ ${ROCM_LOCAL_INSTALL} = false ]; then
    # Check to see if the kernel-devel package exists for this kernel.
    # If it does not, we likely will not be able to build the ROCK
    # driver when it tries to install the DKMS package. As such, we
    # should ask the user if they want to go ahead and try.
    ROCM_SKIP_INSTALLING=false
    KERNEL_DEVEL_PKGS=kernel-devel
    if [ ${KERNEL_DEVEL_PKGS} -lt 1 ]; then
        if [ ${ROCM_FORCE_YES} = true ]; then
            ROCM_SKIP_INSTALLING=true
        elif [ ${ROCM_FORCE_NO} = true ]; then
            ROCM_SKIP_INSTALLING=false
        else
            echo ""
            echo "Cannot find kernel development packages for kernel `uname -r`."
            echo "It is likely that the installation of the ROCK driver will not"
            echo "complete successfully because it cannot build against your kernel."
            echo ""
            echo "This can happen if you are running in a container or you are running"
            echo "a custom kernel."
            read -p "Do you want to skip installing the ROCK driver? (y/n)? " answer
            case ${answer:0:1} in
                y|Y )
                    ROCM_SKIP_INSTALLING=true
                    echo 'User chose "yes". Skipping the installation of ROCK driver.'
                ;;
                * )
                    echo 'User chose "no". Attempting to install the ROCK driver.'
                ;;
            esac
        fi
    fi
fi

if [ ${ROCM_FORCE_PACKAGE} = true ]; then
    cd ${SOURCE_DIR}/install_files/
    pushd ${BASE_DIR}/../common/
    cp ./rock-dkms.spec ${SOURCE_DIR}/install_files/
    popd
    RPM_TEMP_DIR=`mktemp -d`
    rpmbuild -bb --clean --define "_topdir ${RPM_TEMP_DIR}" ./rock-dkms.spec
    cp ${RPM_TEMP_DIR}/RPMS/noarch/rock-dkms-*.rpm .
    rm -rf ${RPM_TEMP_DIR}
    echo "Copying `ls -1 rock-dkms-*.rpm` to ${ROCM_PACKAGE_DIR}"
    mkdir -p ${ROCM_PACKAGE_DIR}
    cp rock-dkms-*.rpm ${ROCM_PACKAGE_DIR}
    if [ ${ROCM_LOCAL_INSTALL} = false ] && [ ${ROCM_SKIP_INSTALLING} = false ]; then
        ROCM_PKG_IS_INSTALLED=`rpm -qa | grep rock-dkms | wc -l`
        if [ ${ROCM_PKG_IS_INSTALLED} -gt 0 ]; then
            PKG_NAME=`rpm -qa | grep rock-dkms | head -n 1`
            sudo rpm -e --nodeps ${PKG_NAME}
        fi
        sudo rpm -i rock-dkms-*.rpm
    fi
else
    if [ ${ROCM_LOCAL_INSTALL} = false ] && [ ${ROCM_SKIP_INSTALLING} = false ]; then
        ${ROCM_SUDO_COMMAND} cp -R ${SOURCE_DIR}/install_files/etc/* /etc/
        ${ROCM_SUDO_COMMAND} cp -R ${SOURCE_DIR}/install_files/usr/* /usr/
        CHECK_INSTALLED=`dkms status amdgpu/2.0-89 | grep installed | wc -l`
        CHECK_BUILT=`dkms status amdgpu/2.0-89 | grep built | wc -l`
        CHECK_ADDED=`dkms status amdgpu/2.0-89 | grep added | wc -l`
        if [ ${CHECK_INSTALLED} -gt 0 ] || [ ${CHECK_BUILT} -gt 0 ] || [ ${CHECK_ADDED} -gt 0 ]; then
            ${ROCM_SUDO_COMMAND} dkms remove amdgpu/2.0-89 --all
        fi
        ${ROCM_SUDO_COMMAND} dkms add amdgpu/2.0-89
        ${ROCM_SUDO_COMMAND} dkms build amdgpu/2.0-89
        ${ROCM_SUDO_COMMAND} dkms install amdgpu/2.0-89
    else
        echo "Skipping build and installation of ROCK drivers."
    fi
fi

if [ $ROCM_SAVE_SOURCE = false ]; then
    rm -rf ${SOURCE_DIR}
fi
