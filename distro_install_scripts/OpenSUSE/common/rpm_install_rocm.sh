#!/bin/bash
###############################################################################
# Copyright (c) 2018-2019 Advanced Micro Devices, Inc.
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

echo "Preparing to set up ROCm requirements. You must be root/sudo for this."
sudo dnf install -y dkms kernel-headers-`uname -r` kernel-devel-`uname -r` wget bzip2

# 2.0.0 is an old release, so the deb packages have moved over to an archive
# tarball. Let's set up a local repo to allow us to do the install here.
# Store the repo in the source directory or a temp directory.
if [ $ROCM_SAVE_SOURCE = true ]; then
    SOURCE_DIR=${ROCM_SOURCE_DIR}
    if [ ${ROCM_FORCE_GET_CODE} = true ] && [ -d ${SOURCE_DIR}/rocm_2.0.0 ]; then
        rm -rf ${SOURCE_DIR}/rocm_2.0.0
    fi
    mkdir -p ${SOURCE_DIR}
else
    SOURCE_DIR=`mktemp -d`
fi
cd ${SOURCE_DIR}
if [ ! -f ${SOURCE_DIR}/yum_2.0.0.tar.bz2 ]; then
    wget http://repo.radeon.com/rocm/archive/yum_2.0.0.tar.bz2
fi
if [ ! -d yum_2.0.0.89 ]; then
    tar -xf yum_2.0.0.tar.bz2
fi
cd yum_2.0.0.89
REAL_SOURCE_DIR=`realpath ${SOURCE_DIR}`
sudo sh -c "echo [ROCm] > /etc/yum.repos.d/rocm.repo"
sudo sh -c "echo name=ROCm >> /etc/yum.repos.d/rocm.repo"
sudo sh -c "echo baseurl=file://${REAL_SOURCE_DIR}/yum_2.0.0.89/ >> /etc/yum.repos.d/rocm.repo"
sudo sh -c "echo enabled=1 >> /etc/yum.repos.d/rocm.repo"
sudo sh -c "echo gpgcheck=0 >> /etc/yum.repos.d/rocm.repo"

# On Fedora, we can skip the kernel module because the proper KFD
# version was backported so our user-land tools can work cleanly.
# In addition, the ROCm 2.0.0 DKMS module fails to build against this
# kernel, so we must skip the driver.

# ROCm requirements
sudo dnf install -y gcc-c++

# We must build HCC from source because the RPM that ships in the AMD binary
# repo does not work here. Ask the user if they want to do this.
ROCM_BUILD_HCC_FROM_SOURCE=true
if [ ${ROCM_FORCE_YES} = true ]; then
    ROCM_BUILD_HCC_FROM_SOURCE=true
elif [ ${ROCM_FORCE_NO} = true ]; then
    ROCM_BUILD_HCC_FROM_SOURCE=false
else
    echo ""
    echo "This script will require you to build HCC from source."
    echo "This can take a long time."
    read -p "Do you wish to proceed to download/build HCC (y/n)? " answer
    case ${answer:0:1} in
        y|Y )
            ROCM_RUN_NEXT_SCRIPT=true
            echo 'User chose "yes". Will build HCC and install HIP etc.'
        ;;
        * )
            ROCM_BUILD_HCC_FROM_SOURCE=false
            echo 'User chose "no". Will not install HCC or HIP.'
            echo 'The ROCm librearies will thus not work either.'
        ;;
    esac
fi

sudo dnf --setopt=install_weak_deps=False install -y hsakmt-roct hsakmt-roct-dev hsa-rocr-dev hsa-ext-rocr-dev rocm-smi rocm-cmake rocminfo rocprofiler-dev rocm-opencl rocm-opencl-devel rocm-clang-ocl
if [ ${ROCM_BUILD_HCC_FROM_SOURCE} = true ]; then
    echo "Installing HCC and HIP requires us to rebuild them from source."
    echo "This may take a while..."
    pushd ${BASE_DIR}/../src_install/component_scripts/
    HCC_TEMP_DIR=`mktemp -d`
    ./01_09_hcc.sh -s ${HCC_TEMP_DIR}/src/ -p ${HCC_TEMP_DIR}/pkg
    HIP_TEMP_DIR=`mktemp -d`
    ./01_10_hip.sh -s ${HIP_TEMP_DIR}/src/ -p ${HIP_TEMP_DIR}/pkg
    popd
    sudo dnf --setopt=install_weak_deps=False install -y rocm-device-libs atmi comgr rocr_debug_agent rocm_bandwidth_test rocm-dev rocm-utils
else
    sudo dnf --setopt=install_weak_deps=False install -y rocm-device-libs atmi comgr rocr_debug_agent rocm_bandwidth_test rocm-utils
fi
sudo rm -f /etc/yum.repos.d/rocm.repo
mkdir -p /opt/rocm/.info/
echo ${ROCM_VERSION_LONG} | sudo tee /opt/rocm/.info/version
sudo mkdir -p /etc/udev/rules.d/
echo 'SUBSYSTEM=="kfd", KERNEL=="kfd", TAG+="uaccess", GROUP="video"' | sudo tee /etc/udev/rules.d/70-kfd.rules

# Detect if you are actually logged into the system or not.
# Containers, for instance, may not have you as a user with
# a meaningful value for logname
num_users=`who am i | wc -l`
if [ ${num_users} -gt 0 ]; then
    sudo usermod -a -G video `logname`
else
    echo ""
    echo "Was going to attempt to add your user to the 'video' group."
    echo "However, it appears that we cannot determine your username."
    echo "Perhaps you are running inside a container?"
    echo ""
fi

# Remove other OpenCL installations for stuff that isn't ROCm, or our OpenCL
# programs may crash with a lot of noise.
for app in pocl libclc beignet; do
    num_pkgs=`dnf list installed ${app} 2>/dev/null | wc -l`
    if [ ${num_pkgs} -gt 0 ]; then
        sudo dnf remove -y ${app}
    fi
done

if [ ${ROCM_FORCE_YES} = true ]; then
    ROCM_RUN_NEXT_SCRIPT=true
elif [ ${ROCM_FORCE_NO} = true ]; then
    ROCM_RUN_NEXT_SCRIPT=false
else
    echo ""
    echo "The next script will set up users on the system to have GPU access."
    read -p "Do you want to automatically run the next script now? (y/n)? " answer
    case ${answer:0:1} in
        y|Y )
            ROCM_RUN_NEXT_SCRIPT=true
            echo 'User chose "yes". Running next setup script.'
        ;;
        * )
            echo 'User chose "no". Not running the next script.'
        ;;
    esac
fi

if [ ${ROCM_RUN_NEXT_SCRIPT} = true ]; then
    ${BASE_DIR}/02_setup_rocm_users.sh "$@"
fi
