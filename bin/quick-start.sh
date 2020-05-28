#!/bin/env bash

clean_dir_check=true
edits_check=true

build_script=build.sh

products_dirs="/cvmfs/dune.opensciencegrid.org/products/dune:/cvmfs/dune.opensciencegrid.org/dunedaq/products" 

starttime=$( date )

for pd in $( echo $products_dirs | tr ":" " " ) ; do
    if [[ ! -e $pd ]]; then
	echo "Unable to find needed products area \"$pd\"" >&2
	exit 1
    fi
done

cmake_version=v3_17_2
boost_version=v1_73_0
TRACE_version=v3_15_09

basedir=$PWD
builddir=$basedir/build

export USER=${USER:-$(whoami)}
export HOSTNAME=${HOSTNAME:-$(hostname)}

if [[ -z $USER || -z $HOSTNAME ]]; then
    echo "Problem getting one or both of the environment variables \$USER and \$HOSTNAME; exiting..." >&2
    exit 10
fi

if $clean_dir_check && [[ -n $( ls -a1 | grep -E -v "^quick-start.*" | grep -E -v "^\.\.?$" ) ]]; then

    cat<<EOF >&2                                                                               

There appear to be files in $basedir besides this script; this script
should only be run in a clean directory. Exiting...

EOF
    exit 20
fi

if $edits_check ; then

    qs_tmpdir=/tmp/${USER}_for_quick-start
    mkdir -p $qs_tmpdir

    cd $qs_tmpdir
    rm -f quick-start.sh
    repoloc=https://raw.githubusercontent.com/jcfreeman2/daq-buildtools/develop/bin/quick-start.sh
    curl -O $repoloc

    potential_edits=$( diff $basedir/quick-start.sh $qs_tmpdir/quick-start.sh )

    if [[ -n $potential_edits ]]; then

	cat<<EOF >&2                                                                                                             
Error: this script you're trying to run doesn't match with the version
of the script at the head of the develop branch in the daq-buildtool's
central repository. This may mean that this script makes obsolete
assumptions, etc., which could compromise your working
environment. Please delete this script and install your daq-buildtools
area according to the instructions at [LOCATION TBD]

EOF

	exit 40

    fi

    cd $basedir
fi # if $edits_check

cat<<EOF > $build_script

basedir=$basedir

if [[ "\$PWD" != "\$basedir" ]]; then
  echo "This script needs to be sourced out of \${basedir}; returning..."
  return 20
fi

if [[ -z \$DUNE_DAQ_BUILD_SCRIPT_SOURCED ]]; then

echo "This script hasn't yet been sourced in this shell; setting up the build environment"

export DUNE_DAQ_BUILD_SCRIPT_SOURCED=1

EOF

for pd in $( echo $products_dirs | tr ":" " " ); do

    cat<<EOF >> $build_script

. $pd/setup
if [[ "\$?" != 0 ]]; then
  echo "Executing \". $pd/setup\" resulted in a nonzero return value; returning..."
  return 10
fi

EOF

done


cat<<EOF >> $build_script

setup_returns=""
setup cmake $cmake_version 
setup_returns=\$setup_returns"\$? "
setup boost $boost_version -q e19:debug
setup_returns=\$setup_returns"\$? "
setup TRACE $TRACE_version
setup_returns=\$setup_returns"\$? "

echo "setup_returns=\$setup_returns"

builddir=$builddir
appframework_unittestdir=$basedir/app-framework/unittest
appframework_integrationtestdir=$basedir/app-framework/test
appframework_headerdir=$basedir/app-framework/include/app-framework/DAQModules
appframework_srcdir=$basedir/app-framework/src/DAQModules

fi    # if DUNE_DAQ_BUILD_SCRIPT_SOURCED wasn't defined

if [[ ! -d \$builddir ]]; then
    echo "Expected build directory $builddir not found; returning..." >&2
    return 10
fi


cd \$builddir

cmake ..

if [[ "\$?" != "0" ]]; then

echo "There was a problem running \"cmake ..\" from \$builddir (i.e., during" >&2
echo "CMake ${CMAKE_VERSION}'s config+generate phases). Scroll up for" >&2
echo "details. Returning..."

   return 20
fi

cmake --build . 

if [[ "\$?" != "0" ]]; then

echo "There was a problem running "cmake --build ." from $builddir (i.e.," >&2
echo "during CMake ${CMAKE_VERSION}'s build phase). Scroll up for" >&2
echo "details. Returning..."

    return 30
fi

echo "CMake's config+generate+build phases all completed successfully"

EOF


cat >CMakeLists.txt<<EOF


cmake_minimum_required(VERSION 3.12)

project(dune-app-framework LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_CXX_STANDARD_REQUIRED ON)


find_package(TRACE REQUIRED)
find_package(Boost REQUIRED COMPONENTS unit_test_framework program_options)

add_subdirectory(app-framework-base)
add_subdirectory(app-framework)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON CACHE BOOL "Set to ON to produce a compile_commands.json file which clang-tidy can use" FORCE)

EOF


packages="app-framework-base app-framework"

for package in $packages ; do
    echo "Cloning $package repo..."
    git clone https://github.com/DUNE-DAQ/${package}.git
done

mkdir -p $builddir

echo "Start time: $starttime"
echo "End time: "$(date)
echo "Script completed successfully"
exit 0

