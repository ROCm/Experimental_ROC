## Scripts for Installing ROCm on Fedora 29

This directory contains directions and scripts for installing ROCm on OpenSUSE Leap 15.
There files for installing are in the following subfolder

- [./src_install](src_install) will download, build, and install ROCm from source code downloaded from AMD's ROCm GitHub repositories
    - These scripts can also be used to build custom versions of any one of the ROCm software packages after installing the rest of the ROCm software system from binary packages.
    - These scriptscan also be used to build binary packages of any of the ROCm software.

Note that the installation mechanisms will, by default, attempt to update system-wide software (such as your kernel) in order to allow ROCm to successfully install.
You will need sudo access in order to complete those steps.
The source code installation method can optionally install all of the user-space components into local folders and thus avoid the need for sudo or root access.

### ROCm on OpenSUSE Leap 15 is Experimental
Please note that OpenSUSE Leap 15 is not a ROCm platform that AMD officially supports or tests against at this time.
As such, tools that target this distribution should be considered experimental.
Bug reports and pull requests for OpenSUSE Leap 15 are welcome, but AMD does not guarantee any level of support for this setup.
