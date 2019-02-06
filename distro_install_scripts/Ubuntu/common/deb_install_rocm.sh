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

sudo apt -y install wget lsb-core

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
if [ ! -f ${SOURCE_DIR}/apt_2.0.0.tar.bz2 ]; then
    wget http://repo.radeon.com/rocm/archive/apt_2.0.0.tar.bz2
fi
if [ ! -d apt_2.0.0.89 ]; then
    tar -xf apt_2.0.0.tar.bz2
fi
cd apt_2.0.0.89
cat rocm.gpg.key | sudo apt-key add -
REAL_SOURCE_DIR=`realpath ${SOURCE_DIR}`
echo "deb [trusted=yes arch=amd64] file:///${REAL_SOURCE_DIR}/apt_2.0.0.89/ xenial main" | sudo tee /etc/apt/sources.list.d/rocm.list

sudo apt update

if [ `lsb_release -rs` = "18.10" ]; then
    # On Ubuntu 18.10, we can skip the kernel module because the proper
    # KFD version is available in the upstream kernel to allow our user-land
    # tools to work. This misses some features, but ROCm 2.0.0 kernel module
    # fails to build on Ubuntu 18.10, so this is our only option.
    sudo apt -y install rocm-dev rocm-cmake atmi rocm_bandwidth_test
    sudo mkdir -p /opt/rocm/.info/
    echo ${ROCM_VERSION_LONG} | sudo tee /opt/rocm/.info/version
    mkdir -p /etc/udev/rules.d/
    echo 'SUBSYSTEM=="kfd", KERNEL=="kfd", TAG+="uaccess", GROUP="video"' | sudo tee /etc/udev/rules.d/70-kfd.rules
else
    sudo apt -y install rocm-dkms rocm-cmake atmi rocm_bandwidth_test
fi

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

sudo apt-key del "CA8B B472 7A47 B4D0 9B4E  E896 9386 B48A 1A69 3C5C"
sudo rm /etc/apt/sources.list.d/rocm.list

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

if [ ${ROCM_RUN_NEXT_SCRIPT}=true ]; then
    ${BASE_DIR}/02_setup_rocm_users.sh "$@"
fi
