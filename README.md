# Experimental ROC

Experimental ROC is a project designs to showcase interesting software and tools for the Radeon Open Compute Platform that are not yet officially supported by AMD.
ROCm is an extensible, open source software platform to enable GPU computation for modern AMD GPUs on Linux.
As part of the process of opening the source code for this software stack, AMD has also described many details of its GPU hardware.

This project is designed to take advantage of this open software and hardware ecosystem to demonstrate interesting techniques and capabilities that have not yet made it onto the official AMD ROCm roadmap.
The software provided here is released in an experimental capacity (as the name implies), with no guarantee of support.
However, it is being released with the goal of helping the community, and feedback is welcome.

## Projects

### Linux Distribution Install and Build Tools

This project, located in [./distro_install_scripts](distro_install_scripts), contains directions and scripts for building, packaging, and installing ROCm on various Linux distributions.
It includes tools for automatically setting up a new system to install ROCm from binaries such as .rpm and .deb files.
It also contains scripts to allow users to download, optionally modify, and build each piece of the ROCm platform from source code.
The latter scripts also allow user to build custom binary packages.

These tools to install ROCm from AMD's binary distribution may be useful for users who want an easy way to set up their system to use ROCm without needing to manually stepping through written directions.
In addition, they can be used (and modified) to automate installations and to potentially install ROCm on distributions that are not officially supported by AMD.

The tools to build ROCm from source may be useful for users who want to avoid installing binary distributions on their platform or who wish to package ROCm themselves.
They can also be used build pieces of the ROCm stack with debug symbols to help with software debugging, or to make custom modifications to ROCm software.
