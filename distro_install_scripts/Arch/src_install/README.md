## Tools to Install ROCm 2.0.0 on Arch Linux From Source

> Keep in mind that Arch is *NOT* officially supported. All work related to it
> is contributed by the community and should be treated as untested

The scripts in this directory will download, build, and install ROCm 2.0.0 from source on Arch Linux.
These scripts will download the source code for the ROCm software from AMD's public repositories, build the software locally, and install it onto your system in a desired location.
These scripts assume a fresh system install, so, by default, they will attempt to add system-wide packages that are required for building the various ROCm projects.

- [Directions for Globally Installing ROCm](#directions-for-globally-installing-rocm)
  * [Updating the Kernel](#updating-the-kernel)
  * [Installing ROCm and ROCm Utilities Globally](#installing-rocm-and-rocm-utilities-globally)
  * [Configuring Users to have GPU Access](#configuring-users-to-have-gpu-access)
  * [Installing ROCm Libraries Globally](#installing-rocm-libraries-globally)
- [Directions for Locally Installing ROCm](#directions-for-locally-installing-rocm)
  * [Install Basic System-Wide Dependencies.](#install-basic-system-wide-dependencies)
  * [Installing or Building ROCm and ROCm Utilities Locally](#installing-or-building-rocm-and-rocm-utilities-locally)
  * [Configuring Your Account and Environment](#configuring-your-account-and-environment)
  * [Installing ROCm Libraries Locally](#installing-rocm-libraries-locally)
- [Directions for Building ROCm Packages](#directions-for-building-rocm-packages)
  * [Packaging ROCm and ROCm Utilities](#packaging-rocm-and-rocm-utilities)
  * [Packaging ROCm Libraries](#packaging-rocm-libraries)
- [Rebuilding or Customizing a Single Piece of Software](#rebuilding-or-customizing-a-single-piece-of-software)
  * [Installing Dependencies](#installing-dependencies)
  * [Downloading the Software Package](#downloading-the-software-package)
  * [Modifying the Software Package](#modifying-the-software-package)
  * [Building the Modified Software Package](#building-the-modified-software-package)
    + [Building with Debug Symbols](#building-with-debug-symbols)
  * [Testing the Modified Software](#testing-the-modified-software)

### Directions for Globally Installing ROCm
The following directions will set up a fresh installation of Arch Linux with ROCm built from public source repositories.
The goal of the scripts run in these directions is to create a software installation that includes the same software and files created from a .deb package installation of ROCm.
In addition, there are scripts that will perform some of the same system setup commands that are included in the normal ROCm installation directions from <https://github.com/RadeonOpenCompute/ROCm>.

#### Updating the Kernel
The following script will prepare the system for ROCm by updating the kernel on your system to its newest version.
This script will ask you for your password, since it attempts to run a number of commands with `sudo` to install software to your system.

```bash
./00_prepare_system_arch.sh
```

It is recommended that you reboot after running this script.
The script will automatically query the user to ask if it should try to reboot the system after it finishes.
To skip this interactive query, pass "-y" or "-n" on the command line.

#### Installing ROCm and ROCm Utilities Globally
The following script will install ROCm and the user-land tools and utilities used in ROCm.

While this script runs, it may sometimes pause to ask you for your password, since it attempts to run a number of commands with `sudo`.
It does this in order to install software globally on your system.
If you want to avoid the need to enter your password at various points throughout the script, you could run the script itself with `sudo`.
This will cause all of the software builds to run with root access, which is not necessarily secure.
You could instead change time amount of time between password requests by modifying the `timestamp_timeout` value in your [sudoers file](https://www.sudo.ws/man/sudoers.man.html).

```bash
./01_install_rocm_arch.sh
```

This script will install the following software:

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

This script can take a number of optional arguments that may be useful when making a system-wide ROCm installation:
 - Options to control the script:
    - `b / --build_only`
       - This will force the script to only **B**uild the software, but not to install or package it. This can be useful when trying to make code modifications or debug builds. This flag cannot be set with `-g / --get_code_only`.
    - `-g / --get_code_only`
       - This tells the script to only **G**et the code for this component, but not to do any of the build or install steps. The data will be stored into the directory specified by the `-s / --source_dir` argument. If `-s` is not set when `-g` is set, the script will fail since there is nowhere to store the code. Cannot be passed in with `-b / --build_only`.
 - Options for configuring the build and installation:
    - `-d / --debug {#}`
        - This sets the **D**ebug level to build the ROCm software with. The default is "0", which is release mode with symbols stripped. "1" includes debug symbols and compiler optimizations. "2" is no compiler optimizations and with debug symbols.
    - `-i / --input_dir {PATH}`
        - This sets the **I**nput path where any ROCm software required to build these packages can be found. For instance, if you only want to build a subset of the ROCm packages because you have already installed ROCm into "/opt/rocm/", then this should be set to /opt/rocm/ (which may differ from your output path). By default, this points to /opt/rocm/, but if you are trying to build ROCm entirely into a different directory, you may want to set this to be the same as the output directory above.
    - `-o / --output_dir {PATH}`
       - This sets the **O**utput path for the ROCm software to be installed into. By default, the software will be put into "/opt/rocm/". Note that not all ROCm software has been tested outside of this directory structure.
    - `-p / --package {PATH}`
       -  This requests that, rather than just installing the software after building it, the tool instead builds a system-specific package (e.g. deb, rpm) of the software. The package will be stored in this flag's argument. The package's target installation directory will be based on `-o / --output_dir` option.
       - After building the package, the script will then attempt to install it onto the system.
    - `-s / --source_dir {PATH}`
       - This tells the scripts to keep the ROCm **S**ource code in the target location after it is built so that it can be modified and rebuilt later. By default, the scripts will download the source code into temporary directories and delete the source after installing the compiled ROCm software.
 - Options for interacting with the script:
    - `-y`
        - Answer **Y**es to any questions the script will ask, without requiring user interaction.
    - `-n`
        - Answer **N**o to any questions the script will ask, without requiring user interaction.

The script will automatically query the user to ask if it should try to run the next script after it finishes.
To skip this interactive query, pass "-y" or "-n" on the command line.

Note that this will not install the ROCK kernel drivers.
Instead, Arch Linux uses the drivers included in the upstream Linux kernel.

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
 - If you are not using `/opt/rocm/` as your installation directory, you will need to set the following environment variables for any GPU users:
    - `HIP_PLATFORM=hcc`
    - `HCC_HOME=${rocm_installation_directory}/hcc/`
    - `HSA_PATH=${rocm_installation_directory}/hsa/`
    - `ROCM_PATH=${rocm_installation_directory}`

It is recommended that you reboot after running this script.
The script will automatically query the user to ask if it should try to reboot the system after it finishes.
To skip this interactive query, pass "-y" or "-n" on the command line.

#### Installing ROCm Libraries Globally
The following script will download, build, and install the ROCm libraries.

While this script runs, it may sometimes pause to ask you for your password, since it attempts to run a number of commands with `sudo`.
It does this in order to install software globally on your system.
If you want to avoid the need to enter your password at various points throughout the script, you could run the script itself with `sudo`.
This will cause all of the software builds to run with root access, which is not necessarily secure.
You could instead change time amount of time between password requests by modifying the `timestamp_timeout` value in your [sudoers file](https://www.sudo.ws/man/sudoers.man.html).

```bash
./03_install_rocm_libraries_arch.sh
```

This script will install the following libraries:

 - rocBLAS
 - hipBLAS
 - rocFFT
 - rocRAND
 - rocPRIM
 - rocSPARSE
 - hipSPARSE
 - rocALUTION
 - MIOpenGEMM
 - MIOpen
    - This will install the HIP version of MIOpen by default.
 - HIP Thrust
 - ROCm SMI Lib
 - RCCL

This script can take a number of optional arguments that may be useful when making a system-wide ROCm installation:
 - Options to control the script:
    - `b / --build_only`
       - This will force the script to only **B**uild the software, but not to install or package it. This can be useful when trying to make code modifications or debug builds. This flag cannot be set with `-g / --get_code_only`.
    - `-g / --get_code_only`
       - This tells the script to only **G**et the code for this component, but not to do any of the build or install steps. The data will be stored into the directory specified by the `-s / --source_dir` argument. If `-s` is not set when `-g` is set, the script will fail since there is nowhere to store the code. Cannot be passed in with `-b / --build_only`.
 - Options for configuring the build and installation:
    - `-d / --debug {#}`
        - This sets the **D**ebug level to build the ROCm software with. The default is "0", which is release mode with symbols stripped. "1" includes debug symbols and compiler optimizations. "2" is no compiler optimizations and with debug symbols.
    - `-i / --input_dir {PATH}`
        - This sets the **I**nput path where any ROCm software required to build these packages can be found. For instance, if you only want to build a subset of the ROCm packages because you have already installed ROCm into "/opt/rocm/", then this should be set to /opt/rocm/ (which may differ from your output path). By default, this points to /opt/rocm/, but if you are trying to build ROCm entirely into a different directory, you may want to set this to be the same as the output directory above.
    - `-o / --output_dir {PATH}`
       - This sets the **O**utput path for the ROCm software to be installed into. By default, the software will be put into "/opt/rocm/". Note that not all ROCm software has been tested outside of this directory structure.
    - `-p / --package {PATH}`
       -  This requests that, rather than just installing the software after building it, the tool instead builds a system-specific package (e.g. deb, rpm) of the software. The package will be stored in this flag's argument. The package's target installation directory will be based on `-o / --output_dir` option.
       - After building the package, the script will then attempt to install it onto the system.
    - `-s / --source_dir {PATH}`
       - This tells the scripts to keep the ROCm **S**ource code in the target location after it is built so that it can be modified and rebuilt later. By default, the scripts will download the source code into temporary directories and delete the source after installing the compiled ROCm software.
 - Options for interacting with the script:
    - `-y`
        - Answer **Y**es to any questions the script will ask, without requiring user interaction.
    - `-n`
        - Answer **N**o to any questions the script will ask, without requiring user interaction.

### Directions for Locally Installing ROCm
The following directions will set up ROCm into a local installation.
In other words, rather than installing into some system-wide location that can be seen by all users (such as `/opt/rocm/`), these directions will instead download and build ROCm and put the resulting files in a local folder without modifying system-wide configuration parameters or folder.

This can be useful if you want to build a local ROCm installation for debug, research, or experimentation purposes.
The goal of the scripts run in these directions is to create a software installation that includes the same software and files created from a .deb package installation of ROCm, except installed to a non-global location.
In addition, there are scripts that will attempt to set up your account (rather than all accounts on the system) to have the right environment variables set to run ROCm.

Note that these tools will **NOT** install or set up the ROCm kernel driver, as this almost by definition requires system-wide access.
If you want to run ROCm on your system, you must first install system-wide kernel drivers (and other software dependencies).
In addition, any user that wants to use the GPU must be added to the `video` group in order to access the GPU.
These local installation directions to **not** perform this step for you.

#### Install Basic System-Wide Dependencies.
The following script will optionally install some system-wide dependencies that you will need to run ROCm.
This may be useful if you plan to build and install ROCm to a non-standard location, but you still want it to work later.
If you do not want to install any system-wide dependencies, you can skip this step.

```bash
./00_prepare_system_arch -r
```

The `-r / --required` flag asks this script to install any required dependencies that would normally be needed if you ran this script to perform a system-wide software installation.
It will not, however, update the kernel or other system-wide software as would normally be done for a system-wide software installation.

#### Installing or Building ROCm and ROCm Utilities Locally
The following scripts will build ROCm and the user-land tools and utilities used in ROCm.
These will be installed into a local directory or built into a package, and system-wide settings will not be changed.

To begin with, you may need to install system-wide software dependencies to even build ROCm.
This *will* require making some system-wide changes.
But, for instance, you need proper compilers and libraries installed on your system to even build ROCm.
These dependencies can be installed by running:

```bash
./01_src_install_rocm_arch.sh -r
```

After installing all of the system-wide dependencies, you can download, build, and install ROCm and its utilities to a local destination with the following command:

```bash
./01_install_rocm_arch.sh -l -i {rocm_installation_directory} -o {rocm_installation_directory}
```

This script will install the following software:

- ~ROCK kernel drivers (amdgpu and amdkfd)~ We assume these are present in the system
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

This script can take a number of optional arguments that may be useful when making a system-wide ROCm installation:
 - Options to control the script:
    - `b / --build_only`
       - This will force the script to only **B**uild the software, but not to install or package it. This can be useful when trying to make code modifications or debug builds. This flag cannot be set with `-g / --get_code_only`.
    - `-g / --get_code_only`
       - This tells the script to only **G**et the code for this component, but not to do any of the build or install steps. The data will be stored into the directory specified by the `-s / --source_dir` argument. If `-s` is not set when `-g` is set, the script will fail since there is nowhere to store the code. Cannot be passed in with `-b / --build_only`.
    - `r / --required`
        - This will force the system-wide installation of any **R**equired software or packages needed for the software to that will be built. This can be used at the same time as `-g / --get_code_only`
 - Options for configuring the build and installation:
    - `-d / --debug {#}`
        - This sets the **D**ebug level to build the ROCm software with. The default is "0", which is release mode with symbols stripped. "1" includes debug symbols and compiler optimizations. "2" is no compiler optimizations and with debug symbols.
    - `-i / --input_dir {PATH}`
        - This sets the **I**nput path where any ROCm software required to build these packages can be found. For instance, if you only want to build a subset of the ROCm packages because you have already installed ROCm into "/opt/rocm/", then this should be set to /opt/rocm/ (which may differ from your output path). By default, this points to /opt/rocm/, but if you are trying to build ROCm entirely into a different directory, you may want to set this to be the same as the output directory above.
    - `-o / --output_dir {PATH}`
       - This sets the **O**utput path for the ROCm software to be installed into. By default, the software will be put into "/opt/rocm/". Note that not all ROCm software has been tested outside of this directory structure.
    - `-p / --package {PATH}`
       -  This requests that, rather than just installing the software after building it, the tool instead builds a system-specific package (e.g. deb, rpm) of the software. The package will be stored in this flag's argument. The package's target installation directory will be based on `-o / --output_dir` option.
    - `-s / --source_dir {PATH}`
       - This tells the scripts to keep the ROCm **S**ource code in the target location after it is built so that it can be modified and rebuilt later. By default, the scripts will download the source code into temporary directories and delete the source after installing the compiled ROCm software.
 - Options for interacting with the script:
    - `-y`
        - Answer **Y**es to any questions the script will ask, without requiring user interaction.
    - `-n`
        - Answer **N**o to any questions the script will ask, without requiring user interaction.

The script will automatically query the user to ask if it should try to run the next script after it finishes.
To skip this interactive query, pass "-y" or "-n" on the command line.

#### Configuring Your Account and Environment
Running ROCm software requires some environment variables to be set so that binaries and libraries can be found when you try to run GPU-using software.
This script will add these proper environment variables into your local account (your `~/.bash_profile`) to ease the use of ROCm software.

Note that this script will **not** add your account into the `video` group.
This is required to use ROCm, and these local installation scripts do not do this.

```bash
./02_setup_rocm_users.sh -l -o {rocm_installation_directory}
```
#### Installing ROCm Libraries Locally
The following script will download, build, and install the ROCm libraries.
These will be installed into a local directory and system-wide settings will not be changed.

To begin with, you may need to install system-wide software dependencies that are required to build these libraries.
This *will* require making some system-wide changes.
But, for instance, you need proper compilers and dependencies installed to build some of these libraries.
These dependencies can be installed by running:

```bash
./03_install_rocm_libraries_arch.sh -r
```

After installing all of the system-wide dependencies, you can download, build, and install the ROCm libraries to a local destination with the following command:

```bash
./03_install_rocm_libraries_arch.sh -l -i ${rocm_installation_directory} -o {rocm_installation_directory}
```

This script will install the following libraries:

 - rocBLAS
 - hipBLAS
 - rocFFT
 - rocRAND
 - rocSPARSE
 - hipSPARSE
 - rocALUTION
 - MIOpenGEMM
 - MIOpen
    - This will install the HIP version of MIOpen by default.
 - HIP Thrust
 - ROCm SMI Lib
 - RCCL

This script can take a number of optional arguments that may be useful when making a system-wide ROCm installation:
 - Options to control the script:
    - `b / --build_only`
       - This will force the script to only **B**uild the software, but not to install or package it. This can be useful when trying to make code modifications or debug builds. This flag cannot be set with `-g / --get_code_only`.
    - `-g / --get_code_only`
       - This tells the script to only **G**et the code for this component, but not to do any of the build or install steps. The data will be stored into the directory specified by the `-s / --source_dir` argument. If `-s` is not set when `-g` is set, the script will fail since there is nowhere to store the code. Cannot be passed in with `-b / --build_only`.
    - `r / --required`
        - This will force the system-wide installation of any **R**equired software or packages needed for the software to that will be built. This can be used at the same time as `-g / --get_code_only`
 - Options for configuring the build and installation:
    - `-d / --debug {#}`
        - This sets the **D**ebug level to build the ROCm software with. The default is "0", which is release mode with symbols stripped. "1" includes debug symbols and compiler optimizations. "2" is no compiler optimizations and with debug symbols.
    - `-i / --input_dir {PATH}`
        - This sets the **I**nput path where any ROCm software required to build these packages can be found. For instance, if you only want to build a subset of the ROCm packages because you have already installed ROCm into "/opt/rocm/", then this should be set to /opt/rocm/ (which may differ from your output path). By default, this points to /opt/rocm/, but if you are trying to build ROCm entirely into a different directory, you may want to set this to be the same as the output directory above.
    - `-o / --output_dir {PATH}`
       - This sets the **O**utput path for the ROCm software to be installed into. By default, the software will be put into "/opt/rocm/". Note that not all ROCm software has been tested outside of this directory structure.
    - `-p / --package {PATH}`
       -  This requests that, rather than just installing the software after building it, the tool instead builds a system-specific package (e.g. deb, rpm) of the software. The package will be stored in this flag's argument. The package's target installation directory will be based on `-o / --output_dir` option.
       - After building the package, the script will then attempt to install it onto the system.
    - `-s / --source_dir {PATH}`
       - This tells the scripts to keep the ROCm **S**ource code in the target location after it is built so that it can be modified and rebuilt later. By default, the scripts will download the source code into temporary directories and delete the source after installing the compiled ROCm software.
 - Options for interacting with the script:
    - `-y`
        - Answer **Y**es to any questions the script will ask, without requiring user interaction.
    - `-n`
        - Answer **N**o to any questions the script will ask, without requiring user interaction.

### Directions for Building ROCm Packages

> Packaging is currently not implemented for Arch Linux

#### Packaging ROCm and ROCm Utilities

> Packaging is currently not implemented for Arch Linux

#### Packaging ROCm Libraries

> Packaging is currently not implemented for Arch Linux

### Rebuilding or Customizing a Single Piece of Software
One of the benefits of building ROCm software from source is that you can make modifications to software in order to fix bugs, test new ideas, experiment, add new features, or build with debug symbols.
This section will demonstrate how to use these scripts to make small custom modifications to a piece of software in the ROCm stack and then build it for your own use.

This section assumes that you have a ROCm 2.0.0 installation in the default `/opt/rocm/` location, though the directions would also work if you have ROCm installed into some other custom location.

The running example will show you how to make a custom version of the ROCr runtime which sits at the base of all ROCm software.
We will modify ROCr so that it prints a debug message to the screen whenever it is initialized.

#### Installing Dependencies
The installation scripts for each of the ROCm software packages can be found in the `./component_scripts/` directory.
These scripts can be used to download the source code for the software, install any system-wide dependencies, build the software, and install it.

Before downloading, modifying, or building any component, we need to install any dependencies.
For example, most of the ROCm source code is downloaded with the `git` utility, which may not yet be installed on your system.

In this example, we want to make a small modification to the ROCr runtime.
To install its dependencies, first run:
```bash
./component_scripts/02_rocr.sh -r
```

The `-r` flag (which can alternately be passed as `--required`) will install any required software for this package.

#### Downloading the Software Package
The next step in making a customization to some ROCm software is to download the source code.
Again, we are making a small modification to the ROCr runtime.
To download this software into the `~/rocm_source/` directory, use the following command:

```bash
./component_scripts/02_rocr.sh -g -s ~/rocm_source/
```

The `-g` flag (which can alternately be passed as `--get_code_only`) will cause this script to download ROCr without attempting to build it.
The destination directory, into which ROCr will be downloaded, is controlled by the `-s` flag (which can also be passed as `--source_dir`).

#### Modifying the Software Package
With the source code downloaded, the next step is to make any desired modifications to the software.
In this case, we would like to add a small debug printout whenever the ROCr runtime is initialized.

In this case, the ROCr runtime is initialized with the function `hsa_init()`, which can be found in the file `~/rocm_source/ROCR-Runtime/src/core/runtime/hsa.cpp`

We can make the following modifications to cause a printout whenever the initialization function is called:
```patch
--- a/src/core/runtime/hsa.cpp
+++ b/src/core/runtime/hsa.cpp
@@ -204,6 +204,7 @@ namespace HSA {
 //  Init/Shutdown routines
 //---------------------------------------------------------------------------//
 hsa_status_t hsa_init() {
+  printf("Attempting to initialize ROCr!\n");
   TRY;
   return core::Runtime::runtime_singleton_->Acquire();
   CATCH;
```

#### Building the Modified Software Package
With the modification complete, we must next build the software.
In this example, we will build our customized ROCr and put the resulting binaries into the directory `~/custom_rocm/`

```bash
./component_scripts/02_rocr.sh -l -s ~/rocm_source/ -i /opt/rocm/ -o ~/custom_rocm/
```

The `-s` flag (which can also be passed as `--source_dir`) points the script towards the location of our modification source code.
It will then build that modified source code and output it into the directory pointed to be the `-o` flag (which can alternately be passed as `--output_dir`).

The `-i` flag (which can be passed as `--input_dir`) should point to your normal ROCm installation directory.
This is used to handle the dependencies on other ROCm software.
For instance, the ROCr runtime we are building here depends on the ROCt Thunk that is installed as part of ROCm.
If you already have a full ROCm installation in `/opt/rocm/` then you can simply pass in `-i /opt/rocm/`.
However, if you installed ROCm into a non-standard location, you should pass that location in with the `-i` flag.

The `-l` flag (which can be passed as `--local` tells the script that you are not trying to install the resulting software into a system-wide location (and thus it will not try to call `sudo`).
If your output directory is something like `/opt/rocm`, you should not pass the `-l` flag.

##### Building with Debug Symbols
Note that this is also a good time to decide if you want to build your custom software with debug symbols (to help with debugging any problems that may come up).
By default, software will be built in Release mode with symbols stripped to reduce binary size.

If you would like to build your software in debug mode, just pass in `-d 1` or `-d 2`.
The former will build with compiler optimizations and debug symbols (RelWithDebInfo mode), while the latter will build without optimizations but with symbols (Debug mode).

#### Testing the Modified Software
After the above script has finished, your software should now be installed into `~/custom_rocm/`.
The ROCr runtime installs a number of headers into the directory `~/custom_rocm/include/` directory, and its main library into `~/custom_rocm/hsa/lib/`.

To test the modified ROCr runtime, we need to point new applications towards it.
ROCr is a shared library, and the environment variable `LD_LIBRARY_PATH` can be used to point applications towards new shared libraries instead of the ones normally found in system-defined paths.

First, let's look at a ROCm application that uses the default ROCr runtime.
`rocminfo` is an application that prints out information about the ROCm hardware on your system.

If we look at the output of the `ldd` command, we can see that it normally loads the ROCr runtime (`libhsa-runtime64.so.1`) from the system installation `/opt/rocm/hsa/lib/libhsa-runtime64.so.1`:

```bash
$ ldd /opt/rocm/bin/rocminfo
        linux-vdso.so.1 (0x00007ffff7ffa000)
        libhsa-runtime64.so.1 => /opt/rocm/hsa/lib/libhsa-runtime64.so.1 (0x00007ffff7b24000)
...
```

When we run this application, it prints out information as normal:
```bash
$ /opt/rocm/bin/rocminfo
=====================
HSA System Attributes
=====================
Runtime Version:         1.1
```

If we set the `LD_LIBRARY_PATH` environment variable to point towards our modified ROCr runtime library, we should see a different output:
```bash
$ LD_LIBRARY_PATH=~/custom_rocm/hsa/lib/ ldd /opt/rocm/bin/rocminfo
        linux-vdso.so.1 (0x00007ffff7ffa000)
        libhsa-runtime64.so.1 => /home/testuser/hsa/lib/libhsa-runtime64.so.1 (0x00007ffff7b24000)
...
$ LD_LIBRARY_PATH=~/custom_rocm/hsa/lib/ /opt/rocm/bin/rocminfo
Attempting to initialize ROCr!
=====================
HSA System Attributes
=====================
Runtime Version:         1.1
```
