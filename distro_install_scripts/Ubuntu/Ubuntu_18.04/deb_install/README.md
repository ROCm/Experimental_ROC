## Install ROCm 1.9.2 on Ubuntu 18.04 Using APT
The scripts in this directory will install ROCm 1.9.2 on Ubuntu 18.04.1 LTS.
These scripts will download the files from the AMD ROCm apt repository and install them onto your system.
These scripts assume a fresh system install, so they will attempt to add packages that are required for ROCm.

### Directions for Installing ROCm 1.9.2
The following directions will set up a fresh installation of Ubuntu with ROCm using the .deb packages distributed by AMD.
The goal of these scripts is to create a ROCm software installatino using similar directions to those contained at <https://github.com/RadeonOpenCompute/ROCm>.

#### Updating the Kernel
The following script will prepare the system for ROCm 1.9.2 by updating the kernel on your system to its newest version.
This script will ask you for your password, since it attempts to run a number of commands with `sudo` to install software to your system.

```bash
./00_prepare_system_ubuntu_18.04.sh
```

It is recommended that you reboot after running this script.
The script will automatically query the user to ask if it should try to reboot the system after it finishes.
To skip this interactive query, pass "-y" or "-n" on the command line.

#### Installing ROCm and ROCm Utilities Globally
The following script will install ROCm and the user-land tools and utilities used in ROCm.
This script will ask you for your password, since it attempts to run a number of commands with `sudo` to install software to your system.

```bash
./01_install_rocm_ubuntu_18.04.sh
```

This script will install the following software into `/opt/rocm/`:

- ROCK kernel drivers (amdgpu and amdkfd)
- ROCt Thunk (kernel/driver interface)
- ROCr user-land runtime
- ROCm OpenCL runtime and compiler
- HCC runtime and compiler
- HIP compiler
- ROCm device-optimized low-level libraries
- ATMI (Asynchronous Task and Memory Interface) runtime
- ROCr debug agent tool
- ROC Profiler tool
- rocm-smi system management tool
- rocminfo system reporting tool
- ROCm bandwidth test tool
- ROCm cmake scripts
- clang-ocl tool to offline compile OpenCL kernels for ROCm
- ROCm code object manager tool

#### Configuring Users to have GPU Access
If you want to allow all users on the system to use ROCm GPUs, you may want to run the following script that enables GPU access for all users that will be added from this point on.
It will also add ROCm software into every user's `PATH` environment variable.
This script will ask you for your password, since it attempts to run a number of commands with `sudo` to install software to your system.

```bash
./02_setup_rocm_users.sh
```

If you do not want to enable GPU access for all users on your system, then you can choose to manually set the following things for users who should have GPU access:

 - Add GPU users to the `video` group
 - Put the following ROCm binary directories in the user's `PATH` environment variable. This assumes that your ROCm installation directory is `/opt/rocm/`
    - `/opt/rocm/bin/`
    - `/opt/rocm/opencl/bin/x86_64/`

It is recommended that you reboot after running this script.
The script will automatically query the user to ask if it should try to reboot the system after it finishes.
To skip this interactive query, pass "-y" or "-n" on the command line.

#### Installing ROCm Libraries Globally
The following script will download and install the following ROCm libraries:

 - rocBLAS
 - hipBLAS
 - rocFFT
 - rocRAND
 - MIOpenGEMM
 - MIOpen
    - This will install the HIP version of MIOpen by default.

This script will ask you for your password, since it attempts to run a number of commands with `sudo` to install software to your system.
```bash
./03_install_rocm_libraries_ubuntu_18.04.sh
```
