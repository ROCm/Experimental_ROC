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

ROCM_REBOOT_SYSTEM=false

if [ ${ROCM_INSTALL_PREREQS} = true ]; then
    exit 0
else
    echo "Preparing to update OpenSuSE to allow for ROCm installation."
    echo "You will need to have root privileges to do this."
    if [ "`which sudo`" = "" ]; then
        if [ "`whoami`" = "root" ]; then
            zypper -n in coreutils sudo
        else
            echo "ERROR. Installing software on this system will require either"
            echo "running as root, or access to the 'sudo' application."
            echo "sudo is not installed, and you are not root. Failing."
            exit 1
        fi
    fi

    if [ ! "`which nvcc`" = "" ]; then
        # If we have CUDA for OpenSuSE, nVidia provides CUDA 10 and 10.1
        # This means we need a newer version of CMake than normally available
        CMAKE_VERSION_GOOD=false
        if [ ! "`which cmake`" = "" ]; then
            CMAKE_VERSION=$(cmake --version | grep version | awk '{print $3;}' | awk -F. '{ printf("%d.%d\n", $1,$2); }' )
            if [ $CMAKE_VERSION -ge 3.13 ]; then
                CMAKE_VERSION_GOOD=true
            fi
        fi

        if [ ${CMAKE_VERSION_GOOD} = false ]; then
            echo "We'll need CMake to build all the projects and we've noticed"
            echo "you have CUDA installed. nVidia provides officially only CUDA 10+"
            echo "for OpenSuSE, this means we need to guarantee CMake version is"
            echo "at least 3.13."
            echo "CMake on Leap15's repos is 3.10 so we'll get it from Tumbleweed"
            # We are going to install CMake from whatever's on Tumbleweed right now
            # this is guaranteed to be new enough
            sudo zypper ar -ef -p 50 http://download.opensuse.org/tumbleweed/repo/oss "rocmTWtemp"
            sudo zypper --gpg-auto-import-keys ref
            sudo zypper -n in cmake
            # We don't want this repo to stick around, though
            sudo zypper rr "rocmTWtemp"
        fi
    fi

    if [ ${ROCM_FORCE_YES} = true ]; then
        ROCM_REBOOT_SYSTEM=true
    elif [ ${ROCM_FORCE_NO} = true ]; then
        ROCM_REBOOT_SYSTEM=false
    else
        echo ""
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
fi

if [ ${ROCM_REBOOT_SYSTEM} = true ]; then
    echo ""
    echo "Attempting to reboot the system."
    echo "You will need to have root privileges to do this."
    echo `sudo /usr/sbin/reboot`
    echo ""
    echo ""
    echo "It appears that rebooting failed."
    echo "Are you doing something like running inside of a container?"
    echo "If so, you can likely proceed to the next script."
fi
