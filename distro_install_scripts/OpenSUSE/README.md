## Scripts for Installing ROCm on OpenSUSE

This directory contains directions and scripts for installing ROCm on various versions of OpenSUSE.
Each folder has scripts for installing ROCm on a particular version of Fedora; these scripts can be used to install from AMD's binary files or to build, install ROCm from AMD's source distributions, and build binary packages.

At this time, these tools have been tested on:

- [Leap 15](Leap_15)&dagger;

&dagger;Distributions marked with this symbol are not targets that AMD officially supports or tests against.
As such, tools that target such distributions should be considered experimental.
Bug reports and pull requests for these distros are welcome, but AMD does not guarantee any level of support for them.

The folder `common` contains scripts that are common between multiple OpenSUSE versions and can be safely ignored if you want to directly run the installation or build scripts.
