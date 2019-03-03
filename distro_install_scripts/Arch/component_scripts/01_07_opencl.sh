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
source "$BASE_DIR/../common_options.sh"
parse_args "$@"

# Install pre-reqs for the ROCm OpenCL runtime.
if [ ${ROCM_LOCAL_INSTALL} = false ] || [ ${ROCM_INSTALL_PREREQS} = true ]; then
    echo "Installing software required to build ROCm OpenCL."
    echo "You will need to have root privileges to do this."
    sudo pacman -Sy --noconfirm --needed  git ocaml ocaml-findlib python2-z3 svn curl base-devel libglvnd cmake

    if [ ! -f /usr/lib/libgtest.a ] || [ ! -f /usr/lib/libgtest_main.a ]; then
        # Install/Build a new-enough version of Gtest
        GTEST_TEMP_DIR=`mktemp -d`
        cd ${GTEST_TEMP_DIR}
        git clone https://github.com/google/googletest.git
        cd googletest
        git checkout tags/release-1.8.1
        cd googletest
        mkdir build
        cd build
        cmake ..
        make -j `nproc`
        sudo mkdir -p /usr/lib
        sudo cp *.a /usr/lib
    fi
    if [ ${ROCM_INSTALL_PREREQS} = true ] && [ ${ROCM_FORCE_GET_CODE} = false ]; then
        exit 0
    fi
fi

# Set up source-code directory
if [ $ROCM_SAVE_SOURCE = true ]; then
    SOURCE_DIR=${ROCM_SOURCE_DIR}
    if [ ${ROCM_FORCE_GET_CODE} = true ] && [ -d ${SOURCE_DIR}/OCL ]; then
        rm -rf ${SOURCE_DIR}/OCL
    fi
    mkdir -p ${SOURCE_DIR}
else
    SOURCE_DIR=`mktemp -d`
fi
cd ${SOURCE_DIR}

# Download the ROCm OpenCL Runtime and Driver
if [ ${ROCM_FORCE_GET_CODE} = true ] || [ ! -d ${SOURCE_DIR}/OCL ]; then
    # Set up a temporary .gitconfig file for the user so that, in case they don't have one,
    # the pull succeeds without needing them to enter any information
    if [ -f ~/.gitconfig ]; then
        OLD_GITCONFIG_EXISTS=true
        mv ~/.gitconfig ${SOURCE_DIR}/temp_config &> /dev/null
    else
        OLD_GITCONFIG_EXISTS=false
    fi
    git config --global user.email "temp@temp.temp"
    git config --global user.name "Temp"
    git config --global color.ui false

    mkdir -p ${SOURCE_DIR}/bin/
    curl https://storage.googleapis.com/git-repo-downloads/repo > ${SOURCE_DIR}/bin/repo
    chmod a+x ${SOURCE_DIR}/bin/repo
    mkdir -p ${SOURCE_DIR}/OCL/
    cd ${SOURCE_DIR}/OCL/
    python2 ${SOURCE_DIR}/bin/repo init -u https://github.com/RadeonOpenCompute/ROCm-OpenCL-Runtime.git -b ${ROCM_VERSION_BRANCH} -m opencl.xml
    # Update the revision number to this precise ROCm version, even if its an
    # earlier one from this branch.
    sed -i 's#refs/tags/roc-[0-9]\.[0-9]\.[0-9]#refs/'${ROCM_OPENCL_CHECKOUT}'#' $(pwd)/.repo/manifests/opencl.xml
    ${SOURCE_DIR}/bin/repo sync

    rm -f ~/.gitconfig
    if [ $OLD_GITCONFIG_EXISTS = true ]; then
        mv ${SOURCE_DIR}/temp_config ~/.gitconfig &> /dev/null
    fi
else
    echo "Skipping download of the ROCm OpenCL runtime, since ${SOURCE_DIR}/opencl already exists."
fi

if [ ${ROCM_FORCE_GET_CODE} = true ]; then
    echo "Finished downloading ROCm OpenCL runtime. Exiting."
    exit 0
fi

# Build ROCm OpenCL runtime
cd ${SOURCE_DIR}/OCL/opencl/
mkdir -p build && cd build
cmake -DCMAKE_BUILD_TYPE=${ROCM_CMAKE_BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_OUTPUT_DIR}/opencl/ -DLLVM_USE_LINKER=gold -DCMAKE_LIBRARY_PATH=${ROCM_INPUT_DIR}/lib -DCMAKE_INCLUDE_PATH=${ROCM_INPUT_DIR}/include -DCMAKE_PREFIX_PATH=${ROCM_INPUT_DIR}/ -DCLANG_ANALYZER_ENABLE_Z3_SOLVER=OFF -DCPACK_PACKAGING_INSTALL_PREFIX=${ROCM_OUTPUT_DIR}/ -DCPACK_GENERATOR=DEB ..

# Build the OpenCL runtime can take a large amount of memory, and it will
# fail if you do not have enough memory available per thread. As such, this
# logic limits the number of build threads in response to the amount of
# available memory on the system.
MEM_AVAIL=`cat /proc/meminfo | grep MemTotal | awk {'print $2'}`
AVAIL_THREADS=`nproc`

# Originally tried to
# Give about 4 GB to each building thread
# 1 Gig seemed enough running 24 threads on 32GB
MAX_THREADS=`echo $(( ${MEM_AVAIL} / $(( 1024 * 1024))))`
if [ ${MAX_THREADS} -lt ${AVAIL_THREADS} ]; then
    NUM_BUILD_THREADS=${MAX_THREADS}
else
    NUM_BUILD_THREADS=${AVAIL_THREADS}
fi
if [ ${NUM_BUILD_THREADS} -lt 1 ]; then
    NUM_BUILD_THREADS=1
fi

make -j ${NUM_BUILD_THREADS}

if [ ${ROCM_FORCE_BUILD_ONLY} = true ]; then
    echo "Finished building ROCm OpenCL runtime. Exiting."
    exit 0
fi

# if [ ${ROCM_FORCE_PACKAGE} = true ]; then
#     # Making the packages from the OpenCL runtime build is not as simple as
#     # calling make package. We are going to package/dpkg-deb this ourselves.
#     OPENCL_PKG_VERSION=`git log -1 --date=iso | grep Date | awk '{print $2}' | sed 's/-//g'`
#     OPENCL_BUILD_DIR=$(pwd)
#     # Get files ready in rocm-opencl-deb
#     mkdir -p rocm-opencl-deb
#     cd ${OPENCL_BUILD_DIR}/rocm-opencl-deb
#     mkdir -p ./${ROCM_OUTPUT_DIR}/opencl/bin/x86_64/
#     cd ${OPENCL_BUILD_DIR}/rocm-opencl-deb/${ROCM_OUTPUT_DIR}/opencl/bin/x86_64/
#     cp ${OPENCL_BUILD_DIR}/bin/clinfo .
#     cp ${OPENCL_BUILD_DIR}/compiler/llvm/bin/clang-[0-9] ./clang
#     cp ${OPENCL_BUILD_DIR}/compiler/llvm/bin/ld.lld ./ld.lld
#     cp ${OPENCL_BUILD_DIR}/compiler/llvm/bin/llvm-link .
#     cd ${OPENCL_BUILD_DIR}/rocm-opencl-deb/
#     mkdir -p ./${ROCM_OUTPUT_DIR}/opencl/lib/x86_64/
#     cd ${OPENCL_BUILD_DIR}/rocm-opencl-deb/${ROCM_OUTPUT_DIR}/opencl/lib/x86_64/
#     cp ${OPENCL_BUILD_DIR}/lib/libOpenCL.so.1 .
#     cp ${OPENCL_BUILD_DIR}/lib/libamdocl64.so .
#     cd ${OPENCL_BUILD_DIR}/rocm-opencl-deb/
#     # Make the .deb control files.
#     rm -rf ${OPENCL_BUILD_DIR}/rocm-opencl-deb/DEBIAN/
#     find . -type f -printf '%P ' | xargs md5sum > ${OPENCL_BUILD_DIR}/temp_md5sums
#     mkdir -p ${OPENCL_BUILD_DIR}/rocm-opencl-deb/DEBIAN/
#     cp ${OPENCL_BUILD_DIR}/temp_md5sums ${OPENCL_BUILD_DIR}/rocm-opencl-deb/DEBIAN/md5sums
#     for file in control postinst prerm; do
#         pushd ${BASE_DIR}/../common/deb_files/
#         cp ./opencl-${file} ${OPENCL_BUILD_DIR}/rocm-opencl-deb/DEBIAN/${file}
#         popd
#     done
#     sed -i 's/ROCM_OPENCL_PKG_VER/'${OPENCL_PKG_VERSION}'/g' ${OPENCL_BUILD_DIR}/rocm-opencl-deb/DEBIAN/control
#     cp -R ${OPENCL_BUILD_DIR}/rocm-opencl-deb ${OPENCL_BUILD_DIR}/rocm-opencl-1.2.0-${OPENCL_PKG_VERSION}_amd64
#     # Create the .deb file
#     cd ${OPENCL_BUILD_DIR}
#     dpkg-deb --build rocm-opencl-1.2.0-${OPENCL_PKG_VERSION}_amd64
#     echo "Copying `ls -1 rocm-opencl-*.deb` to ${ROCM_PACKAGE_DIR}"
#     mkdir -p ${ROCM_PACKAGE_DIR}
#     cp rocm-opencl-*.deb ${ROCM_PACKAGE_DIR}
#     if [ ${ROCM_LOCAL_INSTALL} = false ]; then
#         ROCM_PKG_IS_INSTALLED=`dpkg -l rocm-opencl | grep '^.i' | wc -l`
#         if [ ${ROCM_PKG_IS_INSTALLED} -gt 0 ]; then
#             PKG_NAME=`dpkg -l rocm-opencl | grep '^.i' | awk '{print $2}'`
#             sudo dpkg -r --force-depends ${PKG_NAME}
#         fi
#         sudo dpkg -i rocm-opencl-*.deb
#     fi
#
#     # Get the files ready in rocm-opencl-dev-deb
#     cd ${OPENCL_BUILD_DIR}
#     mkdir -p rocm-opencl-dev-deb
#     cd ${OPENCL_BUILD_DIR}/rocm-opencl-dev-deb
#     mkdir -p ./${ROCM_OUTPUT_DIR}/opencl/include/CL/
#     cp -R ${OPENCL_BUILD_DIR}/../api/opencl/khronos/headers/opencl2.2/ /tmp/
#     cp -R /tmp/opencl2.2/CL/ ./${ROCM_OUTPUT_DIR}/opencl/include/
#     rm -f ./${ROCM_OUTPUT_DIR}/opencl/include/CL/cl_d3d*
#     rm -f ./${ROCM_OUTPUT_DIR}/opencl/include/CL/cl_dx9*
#     rm -f ./${ROCM_OUTPUT_DIR}/opencl/include/CL/cl2.hpp
#     rm -rf /tmp/opencl2.2/
#     cp ${OPENCL_BUILD_DIR}/../compiler/llvm/tools/clang/lib/Headers/opencl-c.h ./${ROCM_OUTPUT_DIR}/opencl/include/
#     mkdir -p ./${ROCM_OUTPUT_DIR}/opencl/lib/x86_64/bitcode/
#     for bc_file in `find ${OPENCL_BUILD_DIR}/library/amdgcn/ -name \*.bc`; do
#         cp ${bc_file} ./${ROCM_OUTPUT_DIR}/opencl/lib/x86_64/bitcode/
#     done
#     cd ./${ROCM_OUTPUT_DIR}/opencl/lib/x86_64/
#     ln -sf ./libOpenCL.so.1 ./libOpenCL.so
#     cd ${OPENCL_BUILD_DIR}/rocm-opencl-dev-deb
#     # Make the .deb control files.
#     rm -rf ${OPENCL_BUILD_DIR}/rocm-opencl-dev-deb/DEBIAN/
#     find . -type f -printf '%P ' | xargs md5sum > ${OPENCL_BUILD_DIR}/temp_md5sums
#     mkdir -p ${OPENCL_BUILD_DIR}/rocm-opencl-dev-deb/DEBIAN/
#     cp ${OPENCL_BUILD_DIR}/temp_md5sums ${OPENCL_BUILD_DIR}/rocm-opencl-dev-deb/DEBIAN/md5sums
#     pushd ${BASE_DIR}/../common/deb_files/
#     cp ./opencl-dev-control ${OPENCL_BUILD_DIR}/rocm-opencl-dev-deb/DEBIAN/control
#     popd
#     sed -i 's/ROCM_OPENCL_PKG_VER/'${OPENCL_PKG_VERSION}'/g' ${OPENCL_BUILD_DIR}/rocm-opencl-dev-deb/DEBIAN/control
#     cp -R ${OPENCL_BUILD_DIR}/rocm-opencl-dev-deb ${OPENCL_BUILD_DIR}/rocm-opencl-dev-1.2.0-${OPENCL_PKG_VERSION}_amd64
#     # Create the .deb file
#     cd ${OPENCL_BUILD_DIR}
#     dpkg-deb --build rocm-opencl-dev-1.2.0-${OPENCL_PKG_VERSION}_amd64
#     echo "Copying `ls -1 rocm-opencl-dev-*.deb` to ${ROCM_PACKAGE_DIR}"
#     mkdir -p ${ROCM_PACKAGE_DIR}
#     cp rocm-opencl-dev-*.deb ${ROCM_PACKAGE_DIR}
#     if [ ${ROCM_LOCAL_INSTALL} = false ]; then
#         ROCM_PKG_IS_INSTALLED=`dpkg -l rocm-opencl-dev | grep '^.i' | wc -l`
#         if [ ${ROCM_PKG_IS_INSTALLED} -gt 0 ]; then
#             PKG_NAME=`dpkg -l rocm-opencl-dev | grep '^.i' | awk '{print $2}'`
#             sudo dpkg -r --force-depends ${PKG_NAME}
#         fi
#         sudo dpkg -i rocm-opencl-dev-*.deb
#     fi
# else
    ${ROCM_SUDO_COMMAND} make install

    if [ ${ROCM_LOCAL_INSTALL} = false ]; then
        ${ROCM_SUDO_COMMAND} mkdir -p /etc/OpenCL/vendors/
        ${ROCM_SUDO_COMMAND} cp ${SOURCE_DIR}/OCL/opencl/api/opencl/config/amdocl64.icd /etc/OpenCL/vendors/
        echo 'export PATH=$PATH:'"${ROCM_OUTPUT_DIR}/bin:${ROCM_OUTPUT_DIR}/profiler/bin:${ROCM_OUTPUT_DIR}/opencl/bin/x86_64" | ${ROCM_SUDO_COMMAND} tee -a /etc/profile.d/rocm.sh
    fi

    # Fix up OpenCL installation locations

    # Should have this in ${ROCM_OUTPUT_DIR}/opencl/lib/x86_64/:
    # bitcode  libamdocl64.so  libcltrace.so  libOpenCL.so  libOpenCL.so.1
    ${ROCM_SUDO_COMMAND} mkdir -p ${ROCM_OUTPUT_DIR}/opencl/lib/x86_64/bitcode/
    ${ROCM_SUDO_COMMAND} cp ${ROCM_OUTPUT_DIR}/opencl/lib/*.bc ${ROCM_OUTPUT_DIR}/opencl/lib/x86_64/bitcode/
    ${ROCM_SUDO_COMMAND} cp ${ROCM_OUTPUT_DIR}/opencl/lib/libOpenCL.so.1.2 ${ROCM_OUTPUT_DIR}/opencl/lib/x86_64/
    ${ROCM_SUDO_COMMAND} ln -sf ${ROCM_OUTPUT_DIR}/opencl/lib/x86_64/libOpenCL.so.1.2 ${ROCM_OUTPUT_DIR}/opencl/lib/x86_64/libOpenCL.so.1
    ${ROCM_SUDO_COMMAND} ln -sf ${ROCM_OUTPUT_DIR}/opencl/lib/x86_64/libOpenCL.so.1 ${ROCM_OUTPUT_DIR}/opencl/lib/x86_64/libOpenCL.so
    ${ROCM_SUDO_COMMAND} rm -f ${ROCM_OUTPUT_DIR}/opencl/lib/lib*
    ${ROCM_SUDO_COMMAND} rm -rf ${ROCM_OUTPUT_DIR}/opencl/lib/clang/

    # Now that libs are in place, load them in, rebuild the ld cache
    if [ ${ROCM_LOCAL_INSTALL} = false ]; then
        echo "${ROCM_OUTPUT_DIR}/opencl/lib/x86_64" | ${ROCM_SUDO_COMMAND} tee -a /etc/ld.so.conf.d/x86_64-rocm-opencl.conf
        ${ROCM_SUDO_COMMAND} ldconfig
    fi

    # $ ls /opt/rocm/opencl/bin/x86_64/
    # clang  clinfo  ld.lld  llc  llvm-link  llvm-objdump  opt
    ${ROCM_SUDO_COMMAND} mkdir -p ${ROCM_OUTPUT_DIR}/opencl/bin/x86_64/
    # missing llc, llvm-link, llvm-objdump opt, but these are not
    # needed for libOpenCL.so operation
    for i in clang clang-[0-9] clinfo ld.lld lld; do ${ROCM_SUDO_COMMAND} mv ${ROCM_OUTPUT_DIR}/opencl/bin/$i ${ROCM_OUTPUT_DIR}/opencl/bin/x86_64/; done
    ${ROCM_SUDO_COMMAND} rm -f ${ROCM_OUTPUT_DIR}/opencl/bin/git-clang-format
    ${ROCM_SUDO_COMMAND} rm -f ${ROCM_OUTPUT_DIR}/opencl/bin/ld64.lld
    ${ROCM_SUDO_COMMAND} rm -f ${ROCM_OUTPUT_DIR}/opencl/bin/lld-link
    ${ROCM_SUDO_COMMAND} rm -f ${ROCM_OUTPUT_DIR}/opencl/bin/roc-cl
    ${ROCM_SUDO_COMMAND} rm -f ${ROCM_OUTPUT_DIR}/opencl/bin/wasm-ld
    ${ROCM_SUDO_COMMAND} rm -f ${ROCM_OUTPUT_DIR}/opencl/bin/hmaptool

    # $ ls /opt/rocm/opencl/include/
    # CL  opencl-c.h
    #$ ls /opt/rocm/opencl/include/CL/
    #cl_ext.h  cl_gl_ext.h  cl_gl.h  cl.h  cl.hpp  cl_platform.h  opencl.h
    ${ROCM_SUDO_COMMAND} cp -R ${ROCM_OUTPUT_DIR}/opencl/include/opencl2.2/ /tmp/
    ${ROCM_SUDO_COMMAND} rm -rf ${ROCM_OUTPUT_DIR}/opencl/include/*
    ${ROCM_SUDO_COMMAND} mkdir -p ${ROCM_OUTPUT_DIR}/opencl/include/CL/
    ${ROCM_SUDO_COMMAND} cp -R /tmp/opencl2.2/CL/ ${ROCM_OUTPUT_DIR}/opencl/include/
    ${ROCM_SUDO_COMMAND} rm -f ${ROCM_OUTPUT_DIR}/opencl/include/CL/cl_d3d*
    ${ROCM_SUDO_COMMAND} rm -f ${ROCM_OUTPUT_DIR}/opencl/include/CL/cl_dx9*
    ${ROCM_SUDO_COMMAND} rm -f ${ROCM_OUTPUT_DIR}/opencl/include/CL/cl2.hpp
    ${ROCM_SUDO_COMMAND} rm -rf /tmp/opencl2.2/
# fi

if [ $ROCM_SAVE_SOURCE = false ]; then
    rm -rf ${SOURCE_DIR}
fi
