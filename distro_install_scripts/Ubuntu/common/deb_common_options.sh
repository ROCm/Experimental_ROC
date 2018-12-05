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
ROCM_BUILD_DEBUG=false
ROCM_DEBUG_LEVEL=0
ROCM_CMAKE_BUILD_TYPE=Release
ROCM_CHANGE_OUTPUT=false
ROCM_OUTPUT_DIR=/opt/rocm
ROCM_SAVE_SOURCE=false
ROCM_SOURCE_DIR=/tmp/
ROCM_CHANGE_INPUT=false
ROCM_INPUT_DIR=/opt/rocm
ROCM_LOCAL_INSTALL=false
ROCM_FORCE_GET_CODE=false
ROCM_INSTALL_PREREQS=false
ROCM_FORCE_YES=false
ROCM_FORCE_NO=false
# Internal parse variable to force OpenCL for MIOpen builds instead of HIP
MIOPEN_FORCE_OPENCL=false
PRINT_HELP=false

IS_MIOPEN_CALL=false

ROCM_SUDO_COMMAND=sudo

display_help() {
    echo "Usage: $0 [-h] [-y/-n]"
    echo ""
    echo "    Script to install ROCm software from .deb packages."
    echo "    This script may require you to enter your sudoers password in "
    echo "    order to install system-wide ROCM software and dependencies."
    echo "    are all ignored when this flag is set."
    echo "    The following options can be used to configure this script:"
    echo ""
    echo "    -y.  This tells the script to automatically answer 'yes' to any "
    echo "      questions that it will ask the user, without requiring user "
    echo "      interaction. Cannot be simultaneously passed with -n."
    echo "    -n.  This tells the script to automatically answer 'no' to any "
    echo "      questions that it will ask the user, without requiring user "
    echo "      interaction. Cannot be simultaneously passed with -y."
    echo ""
}

parse_args() {
    OPTS=`getopt -o ynh --long help -n 'parse-options' -- "$@"`
    if [ $? != 0 ]; then
        echo "Failed to parse command-line options with `getopt`" >&2
        exit 1
    fi

    eval set -- "$OPTS"

    while true; do
        case "$1" in
            -y ) ROCM_FORCE_YES=true; shift ;;
            -n ) ROCM_FORCE_NO=true; shift ;;
            -h | --help ) PRINT_HELP=true; shift ;;
            * ) break ;;
          esac
    done

    if [ $PRINT_HELP = true ]; then
        display_help
        exit 0
    fi

    if [ ${ROCM_FORCE_YES} = true ] && [ ${ROCM_FORCE_NO} = true ]; then
        echo "ERROR: Cannot set both -y and -n as default script answers."
        echo ""
        display_help
        exit 1
    fi
}
