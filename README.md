# openocd-blackfin

## Source

    ftp://ftp.analog.com/pub/tools/patches/gnu_sources/cces/2.10.0/openocd-cces-2.10.0-src.tar.gz


## Build

To build this OpenOCD source package, you will need a Linux machine for building.
For building Win32 host OpenOCD, you will need a cross compiler targeted for Win32.
You can use mingw-w64.

BuildToolChain in buildscript directory can be used to build OpenOCD and libraries
in this package. If you build it natively on Linux, run

    ./BuildToolChain openocd

If you build for Win32 host, run

    ./BuildToolChain -H i686-w64-mingw32 openocd

