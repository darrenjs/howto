#!/usr/bin/env bash

# Instructions for building llvm & clang 6.0.1 from source.

# This script will download, configure and build llvm, using an existing gcc
# compiler.  The gcc used can be either the system default, or a user's custom
# gcc. For use of a custom gcc, its location must be provided via the
# 'gcc_custom_prefix_dir' configuration variable below

# Other experiences of building llvm from source:
#
# https://stackoverflo.co/questions/47734094/build-clang-fro-source-using-specific-gcc-toolchain


#----------------------------------------------------------------------
# LICENSE
#
# This script is free software; you can redistribute it and/or modify it under
# the terms of the MIT license.
#
#----------------------------------------------------------------------


#======================================================================
# User configuration
#======================================================================


# Version of llvm being built
llvm_version=6.0.1

# Additional makefile options.  E.g., "-j 4" for parallel builds.
make_flags="-j 2"

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

# Set the path to your gcc directory.  To use a custom gcc installation, provide
# its location in 'gcc_custom_prefix_dir' variable.

gcc_custom_prefix_dir=${HOME}/opt/gcc-8.2.0

if [ -n "$gcc_custom_prefix_dir" ] ; then
    echo using custom gcc at $gcc_custom_prefix_dir
    gcc_prefix_dir="$gcc_custom_prefix_dir"
    gcc_bin_dir=${gcc_prefix_dir}/bin
    gcc_lib_dir=${gcc_prefix_dir}/lib64
else
    # If not using a custom gcc, use the system gcc, which is found at these
    # (usual) location. Modify these if your system gcc is at a different
    # location.  which is normally located as below
    gcc_prefix_dir=/
    gcc_bin_dir=/bin
    gcc_lib_dir=/lib64
fi

# Note: llvm needs cmake, and version > 3.0
CMAKE=$(which cmake)


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
# Check gcc directories
#======================================================================


if [ -n "$gcc_custom_prefix_dir" ] ; then
    test -d "$gcc_custom_prefix_dir" || __die "gcc_custom_prefix_dir directory not found: $gcc_custom_prefix_dir"
fi
test -d "$gcc_prefix_dir" || __die "gcc_prefix_dir directory not found: $gcc_prefix_dir"
test -d "$gcc_bin_dir"    || __die "gcc_bin_dir directory not found: $gcc_bin_dir"
test -d "$gcc_lib_dir"    || __die "gcc_lib_dir directory not found: $gcc_lib_dir"


#======================================================================
# Create directories
#======================================================================


__banner Creating directories

# ensure workspace directories don't already exist
for d in  "$build_dir" "$source_dir" ; do
    if [ -d  "$d" ]; then
        __die "directory already exists - please remove and try again: $d"
    fi
done

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
mv -v $source_dir/llvm-${llvm_version}.src $source_dir/llvm

__untar  "$source_dir"  "$tarfile_dir/$clang_tarfile"
mv -v $source_dir/cfe-${llvm_version}.src $source_dir/llvm/tools/clang

__untar  "$source_dir"  "$tarfile_dir/$compiler_rt_tarfile"
mv -v $source_dir/compiler-rt-${llvm_version}.src $source_dir/llvm/projects/compiler-rt

__untar  "$source_dir"  "$tarfile_dir/$libcxx_tarfile"
mv -v $source_dir/libcxx-${llvm_version}.src $source_dir/llvm/projects/libcxx

__untar  "$source_dir"  "$tarfile_dir/$libcxxabi_tarfile"
mv -v $source_dir/libcxxabi-${llvm_version}.src $source_dir/llvm/projects/libcxxabi

__untar  "$source_dir"  "$tarfile_dir/$libunwind_tarfile"
mv -v $source_dir/libunwind-${llvm_version}.src $source_dir/llvm/projects/libunwind

__untar  "$source_dir"  "$tarfile_dir/$extra_tarfile"
mv -v $source_dir/clang-tools-extra-${llvm_version}.src $source_dir/llvm/tools/clang/tools/extra


#======================================================================
# Clean environment
#======================================================================


# Before beginning the configuration and build, clean the current shell of all
# environment variables, and set only the minimum that should be required. This
# prevents all sorts of unintended interactions between environment variables
# and the build process.

__banner Cleaning environment

# store USER, HOME and then completely clear environment
U="$USER"
H="$HOME"

for i in $(env | awk -F"=" '{print $1}') ;
do
    unset $i || true   # ignore unset failures
done

# restore, and set PATH and LD_LIBRARY_PATH to bring gcc into environment
export USER="$U"
export HOME="$H"
export PATH="$gcc_bin_dir":/usr/local/bin:/usr/bin:/bin:/sbin:/usr/sbin
export LD_LIBRARY_PATH="$gcc_lib_dir"

echo shell environment follows:
env


#======================================================================
# Configure
#======================================================================


__banner Configuring source code

# Explanation of some configuration switches:
#
# LLVM_TARGETS_TO_BUILD=X86,DLLVM_BUILD_32_BITS:BOOL=OFF -- build 64bit x86_64
# only
#
# LIBCXXABI_USE_LLVM_UNWINDER=YES -- we are including libcxxabi & unwindd in the
# we are using libc++abi, so configure it to use libunwind; this will then get
# implicitly linked into binaries that link to libc++abi.

cd ${build_dir}
"$CMAKE" \
    -G "Unix Makefiles" \
    -DCMAKE_C_COMPILER="$gcc_bin_dir/gcc" \
    -DCMAKE_CXX_COMPILER="$gcc_bin_dir/g++" \
    -DGCC_INSTALL_PREFIX="$gcc_prefix_dir" \
    -DCMAKE_CXX_LINK_FLAGS="-L$gcc_lib_dir" -Wl,-rpath,"$gcc_lib_dir" \
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


# Create a shell script that users can source to bring llvm into shell
# environment
cat << EOF > ${install_dir}/env.sh
# Source this script to bring llvm ${llvm_version} into your environment.
# This also attempts to activate the gcc compiler used

if [ -f "${gcc_custom_prefix_dir}/env.sh" ] ; then
  source "${gcc_custom_prefix_dir}/env.sh"
fi

export PATH=${install_dir}/bin:\$PATH
export LD_LIBRARY_PATH=${install_dir}/lib:${install_dir}/lib64:\$LD_LIBRARY_PATH
export MANPATH=${install_dir}/share/man:\$MANPATH
export INFOPATH=${install_dir}/share/info:\$INFOPATH

EOF

__banner Complete

trap : 0

#end
