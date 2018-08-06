#!/usr/bin/env bash

# Instructions for building llvm & clang 6.0.1 from source.

# This script is free software; you can redistribute it and/or modify it under
# the terms of the MIT license.


#======================================================================
# User configuration
#======================================================================


# Version of llvm being built
llvm_version=6.0.1

# Additional makefile options.  E.g., "-j 4" for parallel builds.  Parallel
# builds are faster, however it can cause a build to fail if the project
# makefile does not support parallel build.
#make_flags=""

# File locations.  Use 'install_dir' to specify where final binarieswill be
# installed.  The other directories are used only during the build process, and
# can later be deleted.
#
# WARNING: do not make 'source_dir' and 'build_dir' the same, or subdirectory of
# each other! It will cause build problems.
install_dir=${HOME}/opt/llvm-${llvm_version}
build_dir=/var/tmp/$(whoami)/llvm-${llvm_version}_build
source_dir=/var/tmp/$(whoami)/llvm-${llvm_version}_sources
tarfile_dir=/var/tmp/$(whoami)/llvm-${llvm_version}_tarballs


#======================================================================
# Support functions
#======================================================================


__die()
{
    echo $*
    exit 1
}


function __banner()
{
    echo "============================================================"
    echo $*
    echo "============================================================"
}


__untar()
{
    dir="$1";
    file="$2"
    case $file in
        *xz)
            tar xJ -C "$dir" -f "$file"
            ;;
        *bz2)
            tar xj -C "$dir" -f "$file"
            ;;
        *gz)
            tar xz -C "$dir" -f "$file"
            ;;
        *)
            __die "don't know how to unzip $file"
            ;;
    esac
}


__abort()
{
        cat <<EOF
***************
*** ABORTED ***
***************
An error occurred. Exiting...
EOF
        exit 1
}


function __wget()
{
    urlroot=$1; shift
    tarfile=$1; shift

    if [ ! -e "$tarfile_dir/$tarfile" ]; then
        wget --verbose ${urlroot}/$tarfile --directory-prefix="$tarfile_dir"
    else
        echo "already downloaded: $tarfile  '$tarfile_dir/$tarfile'"
    fi
}


# Set script to abort on any command that results an error status
trap '__abort' 0
set -e


#======================================================================
# Create directories
#======================================================================


__banner Creating directories

for d in "$install_dir" "$build_dir" "$source_dir" "$tarfile_dir" ;
do
    test  -d "$d" || mkdir --verbose -p $d
done


#======================================================================
# Download source code
#======================================================================


# This step requires internet access.  If you dont have internet access, then
# obtain the tarfiles via an alternative manner, and place in the "$tarfile_dir"

llvm_tarfile=llvm-${llvm_version}.src.tar.xz
clang_tarfile=cfe-${llvm_version}.src.tar.xz
compiler_rt_tarfile=compiler-rt-${llvm_version}.src.tar.xz
libcxx_tarfile=libcxx-${llvm_version}.src.tar.xz
libcxxabi_tarfile=libcxxabi-${llvm_version}.src.tar.xz
extra_tarfile=clang-tools-extra-${llvm_version}.src.tar.xz
libunwind_tarfile=libunwind-${llvm_version}.src.tar.xz

for f in ${llvm_tarfile} ${clang_tarfile} ${compiler_rt_tarfile} \
         ${libcxx_tarfile} ${libcxxabi_tarfile} ${extra_tarfile} \
         ${libunwind_tarfile} ;
do
    echo $f
    __wget http://releases.llvm.org/${llvm_version}  $f
done


#======================================================================
# Unpack source tarfiles
#======================================================================


__banner Unpacking source code

# We are using llvm feature of in-source builds.  If each dependency is placed
# within the llvm source directory, at the appropriate location, they will
# automatically get built during the build of llvm.

__untar  "$source_dir"  "$tarfile_dir/$llvm_tarfile"
mv $source_dir/llvm-${llvm_version}.src $source_dir/llvm

__untar  "$source_dir"  "$tarfile_dir/$clang_tarfile"
mv $source_dir/cfe-${llvm_version}.src $source_dir/llvm/tools/clang

__untar  "$source_dir"  "$tarfile_dir/$compiler_rt_tarfile"
mv $source_dir/compiler-rt-${llvm_version}.src $source_dir/llvm/projects/compiler-rt

__untar  "$source_dir"  "$tarfile_dir/$libcxx_tarfile"
mv $source_dir/libcxx-${llvm_version}.src $source_dir/llvm/projects/libcxx

__untar  "$source_dir"  "$tarfile_dir/$libcxxabi_tarfile"
mv $source_dir/libcxxabi-${llvm_version}.src $source_dir/llvm/projects/libcxxabi

__untar  "$source_dir"  "$tarfile_dir/$libunwind_tarfile"
mv $source_dir/libunwind-${llvm_version}.src $source_dir/llvm/projects/libunwind

__untar  "$source_dir"  "$tarfile_dir/$extra_tarfile"
mv $source_dir/clang-tools-extra-${llvm_version}.src $source_dir/llvm/tools/clang/tools/extra


#======================================================================
# Clean environment
#======================================================================


# Before beginning the configuration and build, clean the current shell of all
# environment variables, and set only the minimum that should be required. This
# prevents all sorts of unintended interactions between environment variables
# and the build process.

__banner Cleaning environment

# store USER, HOME and then completely clear environment
U=$USER
H=$HOME

for i in $(env | awk -F"=" '{print $1}') ;
do
    unset $i || true   # ignore unset fails
done

# restore
export USER=$U
export HOME=$H
export PATH=/usr/local/bin:/usr/bin:/bin:/sbin:/usr/sbin

echo shell environment follows:
env


#======================================================================
# Configure
#======================================================================


__banner Configuring source code

# Note: this needs cmake installs, and needs to be version > 3.4
which cmake

# Explanation of some configuration switches:
#
# LLVM_TARGETS_TO_BUILD=X86,DLLVM_BUILD_32_BITS:BOOL=OFF -- build 64bit x86_64
# only
#
# LIBCXXABI_USE_LLVM_UNWINDER=YES -- we are including libcxxabi & unwindd in the
# we are using libc++abi, so configure it to use libunwind; this will then get
# implicitly linked into binaries that link to libc++abi.

cd  ${build_dir}
cmake \
    -G "Unix Makefiles" \
    -DLLVM_TARGETS_TO_BUILD=X86 \
    -DLLVM_BUILD_32_BITS:BOOL=OFF \
    -DCMAKE_INSTALL_PREFIX="$install_dir" \
    -DCMAKE_BUILD_TYPE="Release" \
    -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON  \
    -DLIBCXXABI_USE_LLVM_UNWINDER=YES \
    ${source_dir}/llvm


#======================================================================
# Compiling
#======================================================================


cd "$build_dir"
make $make_flags

# If desired, run the test phase by uncommenting following line

#make check


#======================================================================
# Install
#======================================================================


__banner Installing

make install


#======================================================================
# Post build
#======================================================================


__banner Complete

trap : 0

#end
