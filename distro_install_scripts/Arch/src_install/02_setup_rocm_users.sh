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
source "$BASE_DIR/common_options.sh"
parse_args "$@"

ROCM_REBOOT_SYSTEM=false

if [ ${ROCM_INSTALL_PREREQS} = true ] || [ ${ROCM_FORCE_GET_CODE} = true ]; then
    exit 0
fi

if [ ${ROCM_LOCAL_INSTALL} = false ]; then
    echo 'ADD_EXTRA_GROUPS=1' | sudo tee -a /etc/adduser.conf
    echo 'EXTRA_GROUPS=video' | sudo tee -a /etc/adduser.conf
    echo 'export PATH=$PATH:'"${ROCM_OUTPUT_DIR}"'/bin:'"${ROCM_OUTPUT_DIR}"'/opencl/bin/x86_64' | sudo tee -a /etc/profile.d/rocm.sh
    if [ "${ROCM_OUTPUT_DIR}" != "/opt/rocm/" ]; then
        echo "export ROCM_PATH=${ROCM_OUTPUT_DIR}/" | sudo tee -a /etc/profile.d/rocm.sh
        echo "export HSA_PATH=${ROCM_OUTPUT_DIR}/hsa/" | sudo tee -a /etc/profile.d/rocm.sh
        echo "export HCC_HOME=${ROCM_OUTPUT_DIR}/hcc/" | sudo tee -a /etc/profile.d/rocm.sh
        echo "export HIP_PLATFORM=hcc" | sudo tee -a /etc/profile.d/rocm.sh
    fi
    if [ ${ROCM_FORCE_YES} = true ]; then
        ROCM_REBOOT_SYSTEM=true
    elif [ ${ROCM_FORCE_NO} = true ]; then
        ROCM_REBOOT_SYSTEM=false
    else
        echo "It is recommended that you reboot your system after running this script."
        read -p "Do you want to reboot now? (y/n)? " answer
        case ${answer:0:1} in
            y|Y )
                ROCM_REBOOT_SYSTEM=true
                echo 'User chose "yes". System will be rebooted.'
            ;;
            * )
                echo 'User chose "no". System will not be rebooted.'
            ;;
        esac
    fi
else
    echo 'export LD_LIBRARY_PATH='"${ROCM_OUTPUT_DIR}"'/opencl/lib/x86_64:'"${ROCM_OUTPUT_DIR}"'/hsa/lib:'"${ROCM_OUTPUT_DIR}"'/lib:'"${ROCM_OUTPUT_DIR}"'/hsa-amd-aqlprofile/lib/:$LD_LIBRARY_PATH' | tee -a ~/.bash_profile
    echo 'export PATH=$PATH:'"${ROCM_OUTPUT_DIR}"'/bin:'"${ROCM_OUTPUT_DIR}"'/opencl/bin/x86_64' | tee -a ~/.bash_profile
    if [ "${ROCM_OUTPUT_DIR}" != "/opt/rocm/" ]; then
        echo "export ROCM_PATH=${ROCM_OUTPUT_DIR}/" | tee -a ~/.bash_profile
        echo "export HSA_PATH=${ROCM_OUTPUT_DIR}/hsa/" | tee -a ~/.bash_profile
        echo "export HCC_HOME=${ROCM_OUTPUT_DIR}/hcc/" | tee -a ~/.bash_profile
        echo "export HIP_PLATFORM=hcc" | tee -a ~/.bash_profile
    fi
fi

if [ ${ROCM_REBOOT_SYSTEM} = true ]; then
    echo ""
    echo "Attempting to reboot the system."
    echo "You will need to have root privileges to do this."
    echo `sudo /sbin/reboot`
    echo ""
    echo ""
    echo "It appears that rebooting failed."
    echo "Are you doing something like running inside of a container?"
    echo "If so, you can likely proceed to the next script."
fi
