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

CMAKE_SOURCE_DIR=/tmp/

# Gets a new version of CMake and puts it into the directory ${ARG1}/cmake/
get_cmake() {
    if [ $# -lt 1 ]; then
        echo "ERROR. get_cmake() requires one argument -- the cmake destination directory."
        exit 1
    else
        CMAKE_SOURCE_DIR=${1}
    fi
    if [ ! -d ${CMAKE_SOURCE_DIR}/cmake/ ]; then
        mkdir -p ${CMAKE_SOURCE_DIR}/cmake/
        cd ${CMAKE_SOURCE_DIR}/cmake/
        wget https://cmake.org/files/v3.12/cmake-3.12.4-Linux-x86_64.tar.gz
        tar -xf cmake-3.12.4-Linux-x86_64.tar.gz
        mv ./cmake-3.12.4-Linux-x86_64/* ./
        cd ${CMAKE_SOURCE_DIR}
    else
        echo "${CMAKE_SOURCE_DIR}/cmake/ already exists."
        echo "Skipping download of a new version of CMake."
    fi
}
