#!/bin/env bash

# safer bash
set -o errexit
set -o pipefail
set -o nounset

# Instructions for building emacs from source.

# This emacs build script is free software; you can redistribute it and/or
# modify it under the terms of the MIT license.

#======================================================================
# User configuration
#======================================================================

# Provide the version of emacs being built
emacs_version=29.2

# Additional makefile options.  E.g., "-j 4" for parallel builds.  Parallel
# builds are faster, however it can cause a build to fail if the project
# makefile does not support parallel build.
make_flags="-j 2"

# File locations.  Use 'install_dir' to specify where gcc will be installed.
# The other directories are used only during the build process, and can later be
# deleted.
#
# WARNING: do not make 'source_dir' and 'build_dir' the same, or
# subdirectory of each other! It will cause build problems.
install_dir=${HOME}/opt/emacs-${emacs_version}
build_dir=/var/tmp/$(whoami)/emacs-${emacs_version}_build
source_dir=/var/tmp/$(whoami)/emacs-${emacs_version}_source
tarfile_dir=/var/tmp/$(whoami)/emacs-${emacs_version}_tarballs

#======================================================================
# Support functions
#======================================================================


__die()
{
    echo $*
    exit 1
}


__banner()
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


__wget()
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


#======================================================================
# Directory creation
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
# obtain the tarfiles via an alternative manner, and place in the
# "$tarfile_dir"

__banner Downloading source code

emacs_tarfile=emacs-${emacs_version}.tar.gz

__wget https://ftp.gnu.org/gnu/emacs  $emacs_tarfile

# Check tarfiles are found, if not found, dont proceed
for f in $emacs_tarfile
do
    if [ ! -f "$tarfile_dir/$f" ]; then
        __die tarfile not found: $tarfile_dir/$f
    fi
done


#======================================================================
# Unpack source tarfiles
#======================================================================


__banner Unpacking source code

__untar  "$source_dir"  "$tarfile_dir/$emacs_tarfile"


#======================================================================
# Clean environment
#======================================================================


# Before beginning the configuration and build, clean the current shell of all
# environment variables, and set only the minimum that should be required. This
# prevents all sorts of unintended interactions between environment variables
# and the build process.  Or you can comment-out this section if you do wish to
# take environment variables, such as custom compilers found on $PATH.

__banner Cleaning environment

# store USER, HOME and then completely clear environment
U=$USER
H=$HOME

regexp="^[0-9A-Za-z_]*$"
for i in $(env | awk -F"=" '{print $1}') ;
do
    if [[  $i =~ $regexp ]]; then   # skip functions
        unset $i || true   # ignore unset fails
    fi
done
unset regexp

# restore
export USER=$U
export HOME=$H
export PATH=/usr/local/bin:/usr/bin:/bin:/sbin:/usr/sbin

echo sanitised shell environment follows:
env


#======================================================================
# Configure
#======================================================================


__banner Configuring source code

cd "${build_dir}"

# We can control which optional components to enable during the emacs build.
# However for them to be built, we typically require the corresponding
# development packages to be installed in the system.  Below are some Ubuntu
# commands that install some useful components:
#
# sudo apt-get install -y libjansson-dev    # for with-json
# sudo apt-get install -y libsqlite3-dev    # for with-sqlite3
# sudo apt-get install -y libgccjit-11-dev  # for with-native-compilation
# sudo apt-get install libtree-sitter-dev   # for with-tree-sitter

# On Centos/Rocky/Redhat platforms, the following commands can be used to
# install various dependencies. Note that some of these packages come from EPEL,
# so that package source needs to be enabled first.
#
# (enable EPEL)
# dnf install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
#
# yum install wget
# yum groupinstall "Development Tools"
# yum install libgccjit-devel
# yum install gnutls-devel
# yum install ncurses-devel
# yum install jansson-devel
# yum install gtk3-devel
# yum install libXpm-devel
# yum install libjpeg-devel
# yum install libpng-devel
# yum install sqlite-devel
# yum install libxml2-devel

$source_dir/emacs-${emacs_version}/configure \
                  --prefix=$install_dir  \
                  --with-json=ifavailable \
                  --with-sqlite3=ifavailable \
                  --with-jpeg=ifavailable \
                  --with-png=ifavailable \
                  --with-gif=ifavailable \
                  --with-tiff=ifavailable  \
                  --with-x-toolkit=gtk3 \
                  --with-tree-sitter=ifavailable \
                  --with-native-compilation  # requires libgccjit-devel

#======================================================================
# Compiling
#======================================================================


cd "$build_dir"

nice make $make_flags

#======================================================================
# Install
#======================================================================


__banner Installing

nice make install


#======================================================================
# Post build
#======================================================================


__banner "Summary"

# Create a shell script that users can source to bring emacs into shell
# environment

cat << EOF > ${install_dir}/activate
# source this script to bring emacs ${emacs_version} into your environment
export PATH=${install_dir}/bin:\$PATH
export LD_LIBRARY_PATH=${install_dir}/lib:${install_dir}/lib64:\$LD_LIBRARY_PATH
export MANPATH=${install_dir}/share/man:\$MANPATH
export INFOPATH=${install_dir}/share/info:\$INFOPATH
EOF

echo emacs has been installed at:
echo
echo "    ${install_dir}"
echo
echo You can activate emacs $emacs_version by sourcing this activation script:
echo
echo "    " source ${install_dir}/activate
echo
echo You can now clean the following directories:
echo
echo "  - $build_dir"
echo "  - $source_dir"

#======================================================================
# Completion
#======================================================================

__banner Complete

trap : 0

#end
