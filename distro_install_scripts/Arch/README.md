## Scripts for Installing ROCm on Arch Linux

This directory contains directions and scripts for installing ROCm on Arch Linux
Since there are no pre-built binaries for arch, the scripts will download, build, and install ROCm from source code downloaded from AMD's ROCm GitHub repositories

 > Currently there is still no packaging support for Arch

Note that the installation mechanism will, by default, attempt to update system-wide software (such as your kernel) in order to allow ROCm to successfully install.
You will need sudo access in order to complete those steps.
The scripts can optionally install all of the user-space components into local folders and thus avoid the need for sudo or root access.
However, installing the ROCK kernel drivers will still require such administrator privileges.

Finally, please be aware that **Arch is not officially supported by AMD**
All work related to this distro has been contributed by community members and is not guaranteed to work,
nor oficially tested
