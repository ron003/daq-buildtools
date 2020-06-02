#!/bin/env bash

clean_dir_check=true
edits_check=true

build_script=source_me_to_build

products_dirs="/cvmfs/dune.opensciencegrid.org/dunedaq/products" 

starttime_d=$( date )
starttime_s=$( date +%s )

for pd in $( echo $products_dirs | tr ":" " " ) ; do
    if [[ ! -e $pd ]]; then
	echo "Unable to find needed products area \"$pd\"; exiting..." >&2
	exit 1
    fi
done

cmake_version=v3_17_2
boost_version=v1_70_0
cetlib_version=v3_10_00
TRACE_version=v3_15_09

gcc_version=v8_2_0
gcc_version_qualifier=e19  # Make sure this matches with the version


basedir=$PWD
builddir=$basedir/build
logdir=$basedir/log

packages="app-framework:develop ers:dune/ers-00-26-00"

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
area according to the instructions at https://github.com/DUNE-DAQ/app-framework/wiki/Compiling-and-running

EOF

	exit 40

    fi

    cd $basedir
fi # if $edits_check

cat<<EOF > $build_script

origdir=\$PWD
basedir=$basedir

if [[ -z \$DUNE_DAQ_BUILD_SCRIPT_SOURCED ]]; then

echo "This script hasn't yet been sourced (successfully) in this shell; setting up the build environment"

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
setup gcc $gcc_version
setup_returns=\$setup_returns"\$? "
setup boost $boost_version -q ${gcc_version_qualifier}:debug
setup_returns=\$setup_returns"\$? "
setup cetlib $cetlib_version -q ${gcc_version_qualifier}:debug
setup_returns=\$setup_returns"\$? "
setup TRACE $TRACE_version
setup_returns=\$setup_returns"\$? "

if [[ "\$setup_returns" =~ [1-9] ]]; then
  echo "At least one of the packages this script attempted to set up didn't set up correctly; returning..." >&2
  cd \$origdir
  return 1
fi

builddir=$builddir

export DUNE_DAQ_BUILD_SCRIPT_SOURCED=1

fi    # if DUNE_DAQ_BUILD_SCRIPT_SOURCED wasn't defined

if [[ ! -d \$builddir ]]; then
    echo "Expected build directory $builddir not found; returning..." >&2
    return 10
fi


cd \$builddir

build_log=/home/jcfree/deleteme2/log/build_attempt_\$( date | sed -r 's/[: ]+/_/g' ).log

starttime_cfggen_d=\$( date )
starttime_cfggen_s=\$( date +%s )
cmake .. |& tee \$build_log
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
echo "details or look at \${build_log}. Returning..."

   cd \$origdir
   return 20
fi

nprocs=\$( grep -E "^processor\s*:\s*[0-9]+" /proc/cpuinfo  | wc -l )
nprocs_argument=""
 
if [[ -n \$nprocs && \$nprocs =~ ^[0-9]+$ ]]; then
    echo "This script believes you have \$nprocs processors available on this system, and will use as many of them as it can"
    nprocs_argument=" -j \$nprocs"
else
    echo "Unable to determine the number of processors available, will not pass the "-j <nprocs>" argument on to the build stage" >&2
fi




starttime_build_d=\$( date )
starttime_build_s=\$( date +%s )
cmake --build . -- \$nprocs_argument |& tee -a \$build_log
retval=\${PIPESTATUS[0]}  # Captures the return value of cmake --build, not tee
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
echo "details or look at \${build_log}. Returning..."

    cd \$origdir
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
echo "Output of build is saved in \${build_log}."
echo
echo "CMake's config+generate+build stages all completed successfully"
echo

cd \$origdir

EOF


cat >CMakeLists.txt<<EOF

cmake_minimum_required(VERSION 3.12)

project(dune-app-framework LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_CXX_STANDARD_REQUIRED ON)


find_package(TRACE REQUIRED)

# May eventually want to uncomment the Boost find_package, but for the
# time being it's handled in the package's CMakeLists.txt files

#find_package(Boost REQUIRED COMPONENTS unit_test_framework program_options)

if (CMAKE_COMPILER_VERSION VERSION_LESS 9.3.0)
   add_compile_options( -Wno-virtual-move-assign ) # False positive: v8.2.0 complains even if there's no data in base class
endif()

add_subdirectory(ers)
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
mkdir -p $logdir

endtime_d=$( date )
endtime_s=$( date +%s )

echo
echo "Total time to run "$( basename $0)": "$(( endtime_s - starttime_s ))" seconds"
echo "Start time: $starttime_d"
echo "End time:   $endtime_d"
echo
echo "To build, run \". $basedir/source_me_to_build\""
echo "To perform a clean build, run \"rm -rf $builddir/*\" before running the build command"
echo
echo "Script completed successfully"
echo
exit 0

