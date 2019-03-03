## Scripts for Installing ROCm on Arch Linux

This directory contains directions and scripts for installing ROCm on Arch Linux
Since there are no pre-built binaries for arch, the scripts will download, build, and install ROCm from source code downloaded from AMD's ROCm GitHub repositories

- These scripts can also be used to build custom versions of any one of the ROCm software packages after installing the rest of the ROCm software system from binary packages.
- These scripts can also be used to build binary packages of any of the ROCm software.

Note that both of these installation mechanisms will, by default, attempt to update system-wide software (such as your kernel) in order to allow ROCm to successfully install.
You will need sudo access in order to complete those steps.
The scripts can optionally install all of the user-space components into local folders and thus avoid the need for sudo or root access.
However, installing the ROCK kernel drivers will still require such administrator privileges.
