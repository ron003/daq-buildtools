#!/bin/env bash

clean_dir_check=true
edits_check=true

build_script=source_me_to_build

products_dirs="/cvmfs/dune.opensciencegrid.org/products/dune:/cvmfs/dune.opensciencegrid.org/dunedaq/products" 

starttime_d=$( date )
starttime_s=$( date +%s )

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

packages="app-framework-base:develop app-framework:develop ers:dune/ers-00-26-00"

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

starttime_cfggen_d=\$( date )
starttime_cfggen_s=\$( date +%s )
cmake ..
retval="\$?"
endtime_cfggen_d=\$( date )
endtime_cfggen_s=\$( date +%s )

if [[ "\$retval" == "0" ]]; then

cfggentime=\$(( endtime_cfggen_s - starttime_cfggen_s ))
echo "CMake \${CMAKE_VERSION}'s config+generate stages took \$cfggentime seconds"
echo "Start time: \$starttime_cfggen_d"
echo "End time:   \$endtime_cfggen_d"

else

echo "There was a problem running \"cmake ..\" from \$builddir (i.e., the" >&2
echo "CMake \${CMAKE_VERSION}'s config+generate stages). Scroll up for" >&2
echo "details. Returning..."

   return 20
fi

starttime_build_d=\$( date )
starttime_build_s=\$( date +%s )
cmake --build . 
retval="\$?"
endtime_build_d=\$( date )
endtime_build_s=\$( date +%s )

if [[ "\$retval" == "0" ]]; then

buildtime=\$((endtime_build_s - starttime_build_s))

echo "CMake \${CMAKE_VERSION}'s build stage took \$buildtime seconds"
echo "Start time: \$starttime_build_d"
echo "End time:   \$endtime_build_d"


else

echo "There was a problem running "cmake --build ." from $builddir (i.e.," >&2
echo "CMake \${CMAKE_VERSION}'s build stage). Scroll up for" >&2
echo "details. Returning..."

    return 30
fi

echo
echo "config+generate stage took \$cfggentime seconds"
echo "Start time: \$starttime_cfggen_d"
echo "End time:   \$endtime_cfggen_d"
echo
echo "build stage took \$buildtime seconds"
echo "Start time: \$starttime_build_d"
echo "End time:   \$endtime_build_d"
echo
echo "CMake's config+generate+build stages all completed successfully"
echo

EOF


cat >CMakeLists.txt<<EOF

cmake_minimum_required(VERSION 3.12)

project(dune-app-framework LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_CXX_STANDARD_REQUIRED ON)


find_package(TRACE REQUIRED)
find_package(Boost REQUIRED COMPONENTS unit_test_framework program_options)

if (CMAKE_COMPILER_VERSION VERSION_LESS 9.3.0)
   add_compile_options( -Wno-virtual-move-assign ) # False positive: v8.2.0 complains even if there's no data in base class
endif()

add_subdirectory(ers)
add_subdirectory(app-framework-base)
add_subdirectory(app-framework)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON CACHE BOOL "Set to ON to produce a compile_commands.json file which clang-tidy can use" FORCE)

EOF


for package in $packages; do
    packagename=$( echo $package | sed -r 's/:.*//g' )
    packagebranch=$( echo $package | sed -r 's/.*://g' )
    echo "Cloning $packagename repo, will use $packagebranch branch..."
    git clone https://github.com/DUNE-DAQ/${packagename}.git
    cd ${packagename}
    git checkout $packagebranch

    if [[ "$?" != "0" ]]; then
	echo >&2
	echo "WARNING: unable to check out $packagebranch branch of ${packagename}. Among other consequences, your build may fail..." >&2
	echo >&2
    fi
    cd ..
done

mkdir -p $builddir

endtime_d=$( date )
endtime_s=$( date +%s )

echo
echo "Total time to run "$( basename $0)": "$(( endtime_s - starttime_s ))" seconds"
echo "Start time: $starttime_d"
echo "End time:   $endtime_d"
echo
echo "To build, run \". source_me_to_build\""
echo "To perform a clean build, run \"rm -rf $builddir/*\" before running the build command"
echo
echo "Script completed successfully"
echo
exit 0

