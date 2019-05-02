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

ROCM_RUN_NEXT_SCRIPT=false

if [ ${ROCM_LOCAL_INSTALL} = false ] || [ ${ROCM_INSTALL_PREREQS} = true ]; then
    echo "Installing software required to build ROCm."
    echo "You will need to have root privileges to do this."
    sudo zypper -n in coreutils git cmake pkg-config pciutils pciutils-devel
fi

# On Fedora, we can skip the kernel module because the proper KFD
# version was backported so our user-land tools can work cleanly.
# In addition, the ROCm 2.0.0 DKMS module fails to build against this
# kernel, so we must skip the driver.

#${BASE_DIR}/component_scripts/01_00_rock-dkms.sh "$@"
${BASE_DIR}/component_scripts/01_01_roct.sh "$@"
${BASE_DIR}/component_scripts/01_02_rocr.sh "$@"
${BASE_DIR}/component_scripts/01_03_rocm_smi.sh "$@"
${BASE_DIR}/component_scripts/01_04_rocm_cmake.sh "$@"
${BASE_DIR}/component_scripts/01_05_rocminfo.sh "$@"
${BASE_DIR}/component_scripts/01_06_rocprofiler.sh "$@"
${BASE_DIR}/component_scripts/01_07_opencl.sh "$@"
${BASE_DIR}/component_scripts/01_08_clang-ocl.sh "$@"
${BASE_DIR}/component_scripts/01_09_hcc.sh "$@"
${BASE_DIR}/component_scripts/01_10_hip.sh "$@"
${BASE_DIR}/component_scripts/01_11_rocm_device_libs.sh "$@"
${BASE_DIR}/component_scripts/01_12_atmi.sh "$@"
${BASE_DIR}/component_scripts/01_13_comgr.sh "$@"
${BASE_DIR}/component_scripts/01_14_rocr_debug_agent.sh "$@"
${BASE_DIR}/component_scripts/01_15_rocm_bandwidth_test.sh "$@"
${BASE_DIR}/component_scripts/01_16_rocm_meta_packages.sh "$@"

if [ ${ROCM_LOCAL_INSTALL} = false ]; then
    # Detect if you are actually logged into the system or not.
    # Containers, for instance, may not have you as a user with
    # a meaningful value for logname
    num_users=`who am i | wc -l`
    if [ ${num_users} -gt 0 ]; then
        ${ROCM_SUDO_COMMAND} usermod -a -G video `logname`
    else
        echo ""
        echo "Was going to attempt to add your user to the 'video' group."
        echo "However, it appears that we cannot determine your username."
        echo "Perhaps you are running inside a container?"
        echo ""
    fi
fi

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
