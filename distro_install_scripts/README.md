## Scripts for Building and Installing ROCm 2.0.0 for Various Linux Distributions

This directory contains directions and scripts for installing ROCm 2.0.0 on various Linux distributions.
This includes tools for automatically setting up a new system to install ROCm from binaries such as .rpm and .deb files (from AMD's binary repository).
This project also contains scripts to allow users to download, optionally modify, and build each piece of the ROCm platform from source code.

The tools to install ROCm from AMD's binary distribution may be useful for users who want an easy way to set up their system to use ROCm without needing to manually step through written directions.
In addition, they can be used (and modified) to automate installations and to potentially install ROCm on distributions that are not officially supported by AMD.

The tools to build ROCm from source may be useful for users who want to avoid installing binary distributions on their platform or who wish to package ROCm themselves.
They can also be used to build pieces of the ROCm stack with debug symbols to help with software debugging, or to make custom modifications to ROCm software.

These tools have been built and tested on the following distributions:

- [Arch Linux](Arch)&dagger;
- [CentOS](CentOS)
    - [CentOS 7.4](CentOS/CentOS_7.4)
    - [CentOS 7.5](CentOS/CentOS_7.5)
    - [CentOS 7.6](CentOS/CentOS_7.6)
- [Fedora](Fedora)
    - [Fedora 28](Fedora/Fedora_28)&dagger;
    - [Fedora 29](Fedora/Fedora_29)&dagger;
- [OpenSUSE](OpenSUSE)
    - [Leap 15](OpenSUSE/Leap_15)&dagger;
- [Red Hat Enterprise Linux (RHEL)](RHEL)
    - [RHEL 7.4](RHEL/RHEL_7.4)
    - [RHEL 7.5](RHEL/RHEL_7.5)
    - [RHEL 7.6](RHEL/RHEL_7.6)
- [Ubuntu](Ubuntu)
    - [Ubuntu 16.04.5 LTS](Ubuntu/Ubuntu_16.04)
    - [Ubuntu 18.04.1 LTS](Ubuntu/Ubuntu_18.04)
    - [Ubuntu 18.10](Ubuntu/Ubuntu_18.10)&dagger;

Each major distribution is held in its own directory, and each version of that distribution has its own subdirectory.
Within those version-specific directories are separate folders for the scripts to install ROCm from binaries and to build ROCm and its components from source.

&dagger;Distributions marked with this symbol are not targets that AMD officially supports or tests against.
As such, tools that target such distributions should be considered experimental.
Bug reports and pull requests for these distros are welcome, but AMD does not guarantee any level of support for them.

### Community Feedback and New Distros
We are always looking for community input! If you would like to add tools and directions for installing ROCm on a distribution not listed above, feel free to submit a pull request with the patches.
Please try to follow a similar directory and file structure as is used for the distributions that already exist.
Such distributions should be marked with a "&dagger;" to indicate that they are experimental and/or community-driven.
