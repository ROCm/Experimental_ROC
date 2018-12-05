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
    if [ ${IS_MIOPEN_CALL} = false ]; then
        echo "Usage: $0 [-h] [-d {#}] [-l] [-g] [-r] [-y/-n] [-o {directory}] [-i {directory}] [-s {directory}]"
    else
        echo "Usage: $0 [-h] [-d {#}] [-l] [-g] [-r] [-y/-n] [-o {directory}] [-i {directory}] [-s {directory}] [--force_opencl]"
    fi
    echo ""
    echo "    -d / --debug {#}: Build the requested software in debug mode, "
    echo "      with debug symbols. The default is 0, which is release mode "
    echo "      with symbols stripped. 1 includes debug symbols and compiler "
    echo "      optimizations. 2 is no optimizations and with debug symbols."
    echo "    -l / --local. This tells the scripts if you are performing a "
    echo "      local installation of this ROCm software. Local installations "
    echo "      will not attempt to modify any system files which are changed "
    echo "      as part of a normal ROCm installation process. This is useful "
    echo "      if you are trying to install into a particular destination "
    echo "      directory. This defaults to false."
    echo "    -o / --output_dir {directory}. This sets the output path for "
    echo "      the requested software to be installed into. By default, "
    echo "      the software will be put into /opt/rocm/."
    echo "    -i / --input_dir {directory}. This sets the path for an existing "
    echo "      ROCm installation so dependencies can be met if you are trying "
    echo "      to build individual packages instead of only depending on "
    echo "      other thing you have built. By default, dependencies will be "
    echo "      satisfied by checking in /opt/rocm/."
    echo "    -s / --source_dir {directory}. Tells the scripts to keep the "
    echo "      requested software source code in the target location after "
    echo "      it is built so that it can be modified and rebuilt later. By "
    echo "      default, the scripts will download the source code into "
    echo "      temporary directories and delete the source after installing "
    echo "      the compiled software."
    echo "    -g / --get_code. This tells the script to only download the code "
    echo "      for this component, but not to do any of the build or install "
    echo "      steps. The data will be stored into the directory specified by "
    echo "      the -s argument. If this is not set, the script will fail "
    echo "      since there is nowhere to store the code. -d, -l, -o, and -i "
    echo "      are all ignored when this flag is set."
    echo "    -r / --required. This will force the system-wide installation "
    echo "      of any required software or packages needed for the software "
    echo "      that will be built. When this flag is passed in, -d, -l, -o, "
    echo "      and -i options will all be ignored and the script will exit "
    echo "      without building anything. Can be run along-side -g."
    echo "    -y.  This tells the script to automatically answer 'yes' to any "
    echo "      questions that it will ask the user, without requiring user "
    echo "      interaction. Cannot be simultaneously passed with -n."
    echo "    -n.  This tells the script to automatically answer 'no' to any "
    echo "      questions that it will ask the user, without requiring user "
    echo "      interaction. Cannot be simultaneously passed with -y."
    if [ ${IS_MIOPEN_CALL} = true ]; then
        echo "    --force_opencl. Build MIOpen for OpenCL. The default is to "
        echo "      build MIOpen for HIP."
    fi
    echo ""
}

parse_args() {
    OPTS=`getopt -o d:o:s:i:lgrynh --long debug:,output_dir:,source_dir:,input_dir:,local,get_code,required,miopen_option,force_opencl,help -n 'parse-options' -- "$@"`
    if [ $? != 0 ]; then
        echo "Failed to parse command-line options with `getopt`" >&2
        exit 1
    fi

    eval set -- "$OPTS"

    while true; do
        case "$1" in
            -d | --debug ) ROCM_BUILD_DEBUG=true; ROCM_DEBUG_LEVEL="$2"; shift 2 ;;
            -o | --output_dir ) ROCM_CHANGE_OUTPUT=true; ROCM_OUTPUT_DIR="$2"; shift 2 ;;
            -s | --source_dir ) ROCM_SAVE_SOURCE=true; ROCM_SOURCE_DIR="$2"; shift 2 ;;
            -i | --input_dir ) ROCM_CHANGE_INPUT=true; ROCM_INPUT_DIR="$2"; shift 2 ;;
            -l | --local ) ROCM_LOCAL_INSTALL=true; unset ROCM_SUDO_COMMAND; shift ;;
            -g | --get_code ) ROCM_FORCE_GET_CODE=true; ROCM_LOCAL_INSTALL=true; shift ;;
            -r | --required ) ROCM_INSTALL_PREREQS=true; shift ;;
            -y ) ROCM_FORCE_YES=true; shift ;;
            -n ) ROCM_FORCE_NO=true; shift ;;
            --miopen_option ) IS_MIOPEN_CALL=true; shift ;;
            --force_opencl ) MIOPEN_FORCE_OPENCL=true; shift ;;
            -h | --help ) PRINT_HELP=true; shift ;;
            * ) break ;;
          esac
    done

    # Note that we set ROCM_LOCAL_INSTALL when doing a GET_CODE so we do not
    # try to install any pre-requisite software.

    if [ $PRINT_HELP = true ]; then
        display_help
        exit 0
    fi

    if [ ${ROCM_FORCE_GET_CODE} = true ] && [ ${ROCM_SAVE_SOURCE} = false ]; then
        echo "ERROR. Trying to download source code without specifying a detination."
        echo "Please set a source-code destination directory with the -s flag."
        exit 1
    fi

    if [ ${ROCM_FORCE_YES} = true ] && [ ${ROCM_FORCE_NO} = true ]; then
        echo "ERROR: Cannot set both -y and -n as default script answers."
        echo ""
        display_help
        exit 1
    fi

    if [ ${ROCM_FORCE_GET_CODE} = false ] && [ $ROCM_BUILD_DEBUG = true ]; then
        re='^[-]?[0-9]+$'
        if ! [[ $ROCM_DEBUG_LEVEL =~ $re ]]; then
            echo "ERROR: Debug level (0-2) should be passed to -d option."
            echo ""
            display_help
            exit 1
        fi
        if [ $ROCM_DEBUG_LEVEL -lt 0 ] || [ $ROCM_DEBUG_LEVEL -gt 2 ]; then
            echo "ERROR: Unable to set debug level less than 0 or greater than 2."
            echo ""
            display_help
            exit 1
        fi
        if [ $ROCM_DEBUG_LEVEL -eq 1 ]; then
            ROCM_CMAKE_BUILD_TYPE=RelWithDebInfo
        fi
        if [ $ROCM_DEBUG_LEVEL -eq 2 ]; then
            ROCM_CMAKE_BUILD_TYPE=Debug
        fi
    fi
}
