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
source scl_source enable devtoolset-7
BASE_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
set -e
trap 'lastcmd=$curcmd; curcmd=$BASH_COMMAND' DEBUG
trap 'errno=$?; print_cmd=$lastcmd; if [ $errno -ne 0 ]; then echo "\"${print_cmd}\" command failed with exit code $errno."; fi' EXIT
source "$BASE_DIR/common/common_options.sh"
parse_args "$@"

${BASE_DIR}/component_scripts/16_rocblas.sh "$@"
${BASE_DIR}/component_scripts/17_hipblas.sh "$@"
${BASE_DIR}/component_scripts/18_rocfft.sh "$@"
${BASE_DIR}/component_scripts/19_rocrand.sh "$@"
${BASE_DIR}/component_scripts/20_rocsparse.sh "$@"
${BASE_DIR}/component_scripts/21_hipsparse.sh "$@"
${BASE_DIR}/component_scripts/22_rocalution.sh "$@"
${BASE_DIR}/component_scripts/23_miopengemm.sh "$@"
${BASE_DIR}/component_scripts/24_miopen.sh "$@"
# By default, this installs miopen-hip, because PyTorch and Tensorflow use it
# If you want to use OpenVX you may need to install miopen-opencl instead of miopen-hip
