#!/bin/env bash

empty_dir_check=true
edits_check=true

setup_script=setup_build_environment
build_script=build_daq_software.sh

products_dirs="/cvmfs/dune.opensciencegrid.org/dunedaq/DUNE/products" 

starttime_d=$( date )
starttime_s=$( date +%s )

for pd in $( echo $products_dirs | tr ":" " " ) ; do
    if [[ ! -e $pd ]]; then
	echo "Unable to find needed products area \"$pd\"; exiting..." >&2
	exit 1
    fi
done

gcc_version=v8_2_0
gcc_version_qualifier=e19  # Make sure this matches with the version

boost_version=v1_70_0
cetlib_version=v3_10_00
cmake_version=v3_17_2
nlohmann_json_version=v3_9_0b
TRACE_version=v3_15_09
folly_version=v2020_05_25
ers_version=v0_26_00c
ninja_version=v1_10_0

basedir=$PWD
builddir=$basedir/build
logdir=$basedir/log
srcdir=$basedir/sourcecode

dbt_version="develop"

precloned_packages="daq-buildtools:${dbt_version}"

export USER=${USER:-$(whoami)}
export HOSTNAME=${HOSTNAME:-$(hostname)}

if [[ -z $USER || -z $HOSTNAME ]]; then
    echo "Problem getting one or both of the environment variables \$USER and \$HOSTNAME; exiting..." >&2
    exit 10
fi

if $empty_dir_check && [[ -n $( ls -a1 | grep -E -v "^quick-start.*" | grep -E -v "^\.\.?$" ) ]]; then

    cat<<EOF >&2                                                                               

There appear to be files in $basedir besides this script; this script
should only be run in a clean directory. Exiting...

EOF
    exit 20

elif ! $empty_dir_check ; then

    cat<<EOF >&2

WARNING: The check for whether any files besides this script exist in
its directory has been switched off. This may mean assumptions the
script makes are violated, resulting in undesired behavior.

EOF

    sleep 5

fi

if $edits_check ; then

    qs_tmpdir=/tmp/${USER}_for_quick-start
    mkdir -p $qs_tmpdir

    cd $qs_tmpdir
    rm -f quick-start.sh
    repoloc=https://raw.githubusercontent.com/DUNE-DAQ/daq-buildtools/${dbt_version}/bin/quick-start.sh
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

else 

cat<<EOF >&2

WARNING: The feature whereby this script checks itself to see if it's
different than its version at the head of the central repo's develop
branch has been switched off. User assumes the risk that the script
may make out-of-date assumptions.

EOF

sleep 5

fi # if $edits_check

cat<<EOF > $setup_script

if [[ -z \$DBT_SETUP_BUILD_ENVIRONMENT_SCRIPT_SOURCED ]]; then

echo "This script hasn't yet been sourced (successfully) in this shell; setting up the build environment"

if [[ -z \$DBT_INSTALL_DIR ]]; then
  export DBT_INSTALL_DIR=\$(cd \$(dirname \${BASH_SOURCE}) && pwd)/install
fi
export CMAKE_PREFIX_PATH=\$CMAKE_PREFIX_PATH:\$DBT_INSTALL_DIR/lib64:\$DBT_INSTALL_DIR/lib

EOF

for pd in $( echo $products_dirs | tr ":" " " ); do

    cat<<EOF >> $setup_script

. $pd/setup
if [[ "\$?" != 0 ]]; then
  echo "Executing \". $pd/setup\" resulted in a nonzero return value; returning..."
  return 10
fi

EOF

done


cat<<EOF >> $setup_script

setup_returns=""
setup cmake $cmake_version 
setup_returns=\$setup_returns"\$? "
setup gcc $gcc_version
setup_returns=\$setup_returns"\$? "
setup boost $boost_version -q ${gcc_version_qualifier}:prof
setup_returns=\$setup_returns"\$? "
setup cetlib $cetlib_version -q ${gcc_version_qualifier}:prof
setup_returns=\$setup_returns"\$? "
setup TRACE $TRACE_version
setup_returns=\$setup_returns"\$? "
setup folly $folly_version -q ${gcc_version_qualifier}:prof
setup_returns=\$setup_returns"\$? "
setup ers $ers_version -q ${gcc_version_qualifier}:prof
setup_returns=\$setup_returns"\$? "
setup nlohmann_json $nlohmann_json_version -q ${gcc_version_qualifier}:prof
setup_returns=\$setup_returns"\$? "

setup ninja $ninja_version 2>/dev/null # Don't care if it fails
if [[ "\$?" != "0" ]]; then
  echo "Unable to set up ninja $ninja_version; this will likely result in a slower build process" >&2
fi


if ! [[ "\$setup_returns" =~ [1-9] ]]; then
  echo "All setup calls on the packages returned 0, indicative of success"
else
  echo "At least one of the required packages this script attempted to set up didn't set up correctly; returning..." >&2
  return 1
fi

export DBT_SETUP_BUILD_ENVIRONMENT_SCRIPT_SOURCED=1
echo "This script has been sourced successfully"
echo

else

echo "This script appears to have already been sourced successfully; returning..." >&2
return 10

fi    # if DBT_SETUP_BUILD_ENVIRONMENT_SCRIPT_SOURCED wasn't defined


EOF

cat<<EOF > $build_script
#!/bin/bash

run_tests=false
clean_build=false 
verbose=false
pkgname_specified=false
perform_install=false
lint=false

for arg in "\$@" ; do
  if [[ "\$arg" == "--help" ]]; then
    echo "Usage: "./\$( basename \$0 )" --clean --unittest --lint --install --verbose --help "
    echo
    echo " --clean means the contents of ./build are deleted and CMake's config+generate+build stages are run"
    echo " --unittest means that unit test executables found in ./build/*/unittest are all run"
    echo " --lint means you check for deviations from the DUNE style guide, https://github.com/DUNE-DAQ/styleguide/blob/develop/dune-daq-cppguide.md" 
    echo " --install means that you want the code from your package(s) installed in the directory which was pointed to by the DBT_INSTALL_DIR environment variable before the most recent clean build"
    echo " --verbose means that you want verbose output from the compiler"

    echo
    echo "All arguments are optional. With no arguments, CMake will typically just run "
    echo "build, unless build/CMakeCache.txt is missing"
    echo
    exit 0    

  elif [[ "\$arg" == "--clean" ]]; then
    clean_build=true
  elif [[ "\$arg" == "--unittest" ]]; then
    run_tests=true
  elif [[ "\$arg" == "--lint" ]]; then
    lint=true
  elif [[ "\$arg" == "--verbose" ]]; then
    verbose=true
  elif [[ "\$arg" == "--pkgname" ]]; then
    echo "Use of --pkgname is deprecated; run with \" --help\" to see valid options. Exiting..." >&2
    exit 1
  elif [[ "\$arg" == "--install" ]]; then
    perform_install=true
  else
    echo "Unknown argument provided; run with \" --help\" to see valid options. Exiting..." >&2
    exit 1
  fi
done

if [[ -z \$DBT_SETUP_BUILD_ENVIRONMENT_SCRIPT_SOURCED ]]; then
echo
echo "It appears you haven't yet sourced \"./setup_build_environment\" yet; please source it before running this script. Exiting..."
echo
exit 2
fi

if [[ ! -d $builddir ]]; then
    echo "Expected build directory $builddir not found; exiting..." >&2
    exit 1
fi

cd $builddir

if \$clean_build; then 
  
   # Want to be damn sure of we're in the right directory, rm -rf * is no joke...

   if  [[ \$( echo \$PWD | sed -r 's!.*/(.*)!\1!' ) =~ ^build/*$ ]]; then
     echo "Clean build requested, will delete all the contents of build directory \"\$PWD\"."
     echo "If you wish to abort, you have 5 seconds to hit Ctrl-c"
     sleep 5
     rm -rf *
   else
     echo "SCRIPT ERROR: you requested a clean build, but this script thinks that $builddir isn't the build directory." >&2
     echo "Please contact John Freeman at jcfree@fnal.gov and notify him of this message" >&2
     exit 10
   fi

fi


build_log=$logdir/build_attempt_\$( date | sed -r 's/[: ]+/_/g' ).log

# We usually only need to explicitly run the CMake configure+generate
# makefiles stages when it hasn't already been successfully run;
# otherwise we can skip to the compilation. We use the existence of
# CMakeCache.txt to tell us whether this has happened; notice that it
# gets renamed if it's produced but there's a failure.

if ! [ -e CMakeCache.txt ];then

generator_arg=
if [ "x\${SETUP_NINJA}" != "x" ]; then
  generator_arg="-G Ninja"
fi

can_unbuffer=false
if [[ -n \$( which unbuffer ) ]]; then
  can_unbuffer=true
fi

starttime_cfggen_d=\$( date )
starttime_cfggen_s=\$( date +%s )

if \$can_unbuffer ; then
unbuffer cmake -DCMAKE_INSTALL_PREFIX=\$DBT_INSTALL_DIR \${generator_arg} $srcdir |& tee \$build_log
else
cmake -DCMAKE_INSTALL_PREFIX=\$DBT_INSTALL_DIR \${generator_arg} $srcdir |& tee \$build_log
fi

retval=\${PIPESTATUS[0]}  # Captures the return value of cmake, not tee
endtime_cfggen_d=\$( date )
endtime_cfggen_s=\$( date +%s )

if [[ "\$retval" == "0" ]]; then

sed -i -r '1 i\# If you want to add or edit a variable, be aware that the config+generate stage is skipped in $build_script if this file exists' $builddir/CMakeCache.txt
sed -i -r '2 i\# Consider setting variables you want cached with the CACHE option in the relevant CMakeLists.txt file instead' $builddir/CMakeCache.txt

cfggentime=\$(( endtime_cfggen_s - starttime_cfggen_s ))
echo "CMake's config+generate stages took \$cfggentime seconds"
echo "Start time: \$starttime_cfggen_d"
echo "End time:   \$endtime_cfggen_d"

else

mv -f CMakeCache.txt CMakeCache.txt.most_recent_failure

echo
echo "There was a problem running \"cmake $srcdir\" from $builddir (i.e.," >&2
echo "CMake's config+generate stages). Scroll up for" >&2
echo "details or look at \${build_log}. Exiting..."
echo

    exit 30
fi

else

echo "The config+generate stage was skipped as CMakeCache.txt was already found in $builddir"

fi # !-e CMakeCache.txt

nprocs=\$( grep -E "^processor\s*:\s*[0-9]+" /proc/cpuinfo  | wc -l )
nprocs_argument=""
 
if [[ -n \$nprocs && \$nprocs =~ ^[0-9]+$ ]]; then
    echo "This script believes you have \$nprocs processors available on this system, and will use as many of them as it can"
    nprocs_argument=" -j \$nprocs"
else
    echo "Unable to determine the number of processors available, will not pass the \"-j <nprocs>\" argument on to the build stage" >&2
fi




starttime_build_d=\$( date )
starttime_build_s=\$( date +%s )

build_options=""
if \$verbose; then
  build_options=" --verbose"
fi

if \$can_unbuffer ; then
unbuffer cmake --build . \$build_options -- \$nprocs_argument |& tee -a \$build_log
else
cmake --build . \$build_options -- \$nprocs_argument |& tee -a \$build_log
fi

retval=\${PIPESTATUS[0]}  # Captures the return value of cmake --build, not tee
endtime_build_d=\$( date )
endtime_build_s=\$( date +%s )

if [[ "\$retval" == "0" ]]; then

buildtime=\$((endtime_build_s - starttime_build_s))

else

echo
echo "There was a problem running \"cmake --build .\" from $builddir (i.e.," >&2
echo "CMake's build stage). Scroll up for" >&2
echo "details or look at the build log via \"more \${build_log}\". Exiting..."
echo

   exit 40
fi

num_estimated_warnings=\$( grep "warning: " \${build_log} | wc -l )

echo

if [[ -n \$cfggentime ]]; then
  echo
  echo "config+generate stage took \$cfggentime seconds"
  echo "Start time: \$starttime_cfggen_d"
  echo "End time:   \$endtime_cfggen_d"
  echo
else
  echo "config+generate stage was skipped"
fi
echo "build stage took \$buildtime seconds"
echo "Start time: \$starttime_build_d"
echo "End time:   \$endtime_build_d"
echo
echo "Output of build contains an estimated \$num_estimated_warnings warnings, and can be viewed later via: "
echo "\"more \${build_log}\""
echo

if [[ -n \$cfggentime ]]; then
  echo "CMake's config+generate+build stages all completed successfully"
  echo
else
  echo "CMake's build stage completed successfully"
fi

if \$perform_install ; then
  cd $builddir

  cmake --build . --target install -- -j \$nprocs
 
  if [[ "\$?" == "0" ]]; then
    echo 
    echo "Installation complete."
    echo "This implies your code successfully compiled before installation; you can either scroll up or run \"more \$build_log\" to see build results"
  else
    echo
    echo "Installation failed. There was a problem running \"cmake --build . --target install -- -j \$nprocs\"" >&2
    echo "Exiting..." >&2
    exit 50
  fi
 
fi



if \$run_tests ; then
     COL_YELLOW="\e[33m"
     COL_NULL="\e[0m"
     COL_RED="\e[31m"
     echo 
     echo
     echo
     echo 
     test_log=$logdir/unit_tests_\$( date | sed -r 's/[: ]+/_/g' ).log

     cd $builddir

     for pkgname in \$( find . -mindepth 1 -maxdepth 1 -type d -not -name CMakeFiles ); do

       unittestdirs=\$( find $builddir/\$pkgname -type d -name "unittest" -not -regex ".*CMakeFiles.*" )

       if [[ -z \$unittestdirs ]]; then
             echo
             echo -e "\${COL_RED}No unit tests have been written for \$pkgname\${COL_NULL}"
             echo
             continue
       fi

       num_unit_tests=0

       for unittestdir in \$unittestdirs; do
           echo
           echo
           echo "RUNNING UNIT TESTS IN \$unittestdir"
           echo "======================================================================"
           for unittest in \$unittestdir/* ; do
               if [[ -x \$unittest ]]; then
                   echo
                   echo -e "\${COL_YELLOW}Start of unit test suite \"\$unittest\"\${COL_NULL}" |& tee -a \$test_log
                   \$unittest -l all |& tee -a \$test_log
                   echo -e "\${COL_YELLOW}End of unit test suite \"\$unittest\"\${COL_NULL}" |& tee -a \$test_log
                   num_unit_tests=\$((num_unit_tests + 1))
               fi
           done
 
       done
 
       echo 
       echo -e "\${COL_YELLOW}Testing complete for package \"\$pkgname\". Ran \$num_unit_tests unit test suites.\${COL_NULL}"
     done
     
     echo
     echo "Test results are saved in \$test_log"
     echo
fi

if \$lint; then
    cd $basedir

    if [[ ! -d ./styleguide ]]; then
      echo "Cloning styleguide into $basedir so linting can be applied"
      git clone https://github.com/DUNE-DAQ/styleguide.git
    fi

    for pkgdir in \$( find build -mindepth 1 -maxdepth 1 -type d -not -name CMakeFiles ); do
        pkgname=\$( echo \$pkgdir | sed -r 's!.*/(.*)!\1!' )
        ./styleguide/cpplint/dune-cpp-style-check.sh build sourcecode/\$pkgname
    done
fi



EOF
chmod +x $build_script


mkdir -p $builddir
mkdir -p $logdir
mkdir -p $srcdir

cd $srcdir
for package in $precloned_packages; do
    packagename=$( echo $package | sed -r 's/:.*//g' )
    packagebranch=$( echo $package | sed -r 's/.*://g' )
    echo "Cloning $packagename repo, will use $packagebranch branch..."
    git clone https://github.com/DUNE-DAQ/${packagename}.git
    cd ${packagename}
    git checkout $packagebranch

    if [[ "$?" != "0" ]]; then
	echo >&2
	echo "Error: unable to check out $packagebranch branch of ${packagename}. Exiting..." >&2
	echo >&2
	exit 55
    fi
    cd ..
done

superproject_cmakeliststxt=$srcdir/daq-buildtools/configs/CMakeLists.txt
if [[ -e $superproject_cmakeliststxt ]]; then
    cp $superproject_cmakeliststxt $srcdir
else
    echo "Error: expected file \"$superproject_cmakeliststxt\" doesn't appear to exist. Exiting..." >&2
    exit 60
fi

setup_runtime=$srcdir/daq-buildtools/scripts/setup_runtime_environment
if [[ -e $setup_runtime ]]; then
    cp $setup_runtime $basedir
else
    echo "Error: expected file \"$setup_runtime\" doesn't appear to exist. Exiting..." >&2
    exit 70
fi

endtime_d=$( date )
endtime_s=$( date +%s )

echo
echo "Total time to run "$( basename $0)": "$(( endtime_s - starttime_s ))" seconds"
echo "Start time: $starttime_d"
echo "End time:   $endtime_d"
echo
echo "See https://github.com/DUNE-DAQ/appfwk/wiki/Compiling-and-running for build instructions"
echo
echo "Script completed successfully"
echo
exit 0

