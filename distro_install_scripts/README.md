## Scripts for Building and Installing ROCm 1.9.2 for Various Linux Distributions

This directory contains directions and scripts for installing ROCm 1.9.2 on various Linux distributions.
This includes tools for automatically setting up a new system to install ROCm from binaries such as .rpm and .deb files (or AMD's binary repos).
This project also contains scripts to allow users to download, optionally modify, and build each piece of the ROCm platform from source code.

These tools to install ROCm from AMD's binary distribution may be useful for users who want an easy way to set up their system to use ROCm without needing to manually step through written directions.
In addition, they can be used (and modified) to automate installations and to potentially install ROCm on distributions that are not officially supported by AMD.

The tools to build ROCm from source may be useful for users who want to avoid installing binary distributions on their platform or who wish to package ROCm themselves.
They can also be used build pieces of the ROCm stack with debug symbols to help with software debugging, or to make custom modifications to ROCm software.

These tools have been built and tested on the following distributions:

- [CentOS](CentOS)
    - [CentOS 7.4](CentOS/CentOS_7.4)
    - [CentOS 7.5](CentOS/CentOS_7.5)
- [Red Hat Enterprise Linux (RHEL)](RHEL)
    - [RHEL 7.4](RHEL/RHEL_7.4)
    - [RHEL 7.5](RHEL/RHEL_7.5)
- [Ubuntu](Ubuntu)
    - [Ubuntu 16.04.5 LTS](Ubuntu/Ubuntu_16.04)
    - [Ubuntu 18.04.1 LTS](Ubuntu/Ubuntu_18.04)
    - [Ubuntu 18.10](Ubuntu/Ubuntu_18.10)

Each major distribution is held in its own directory, and each version of that distribution has its own subdirectory.
Within those version-specific directories are separate folders for the scripts to install ROCm from binaries and to build ROCm and its components from source.

### Community Feedback and New Distros
We are always looking for community input! If you would like to add tools and directions for installing ROCm on a distribution not listed above, feel free to submit a pull request with the patches.
Please try to follow a similar directory and file structure as is used for the distributions that already exist.
