#!/bin/bash
# set -o errexit 
set -o nounset 
# set -o pipefail

HERE=$(cd $(dirname $(readlink -f ${BASH_SOURCE})) && pwd)

# Import find_work_area function
source ${DBT_ROOT}/scripts/dbt-setup-tools.sh

BASEDIR=$(find_work_area)
test -n ${BASEDIR:-} || error "DBT Work area directory not found. Exiting..." 

BUILDDIR=${BASEDIR}/build
LOGDIR=${BASEDIR}/log
SRCDIR=${BASEDIR}/sourcecode
#########################################################################################

run_tests=false
package_to_test=
clean_build=false 
debug_build=false
verbose=false
cmake_trace=false
cmake_graphviz=false
declare -i n_jobs=0
perform_install=false
lint=false
package_to_lint=

args=("$@")

declare -i i_arg=0

while ((i_arg < $#)); do

  arg=${args[$i_arg]}
  nextarg=
  if ((i_arg + 1 < $#)); then
      nextarg=${args[$((i_arg+1))]}
  fi
  i_arg=$((i_arg + 1))

  if [[ "$arg" == "--help" ]]; then
    cat << EOF

      Usage: "./$( basename $0 )" --clean --debug --jobs <number parallel build jobs> --unittest <optional package name> --lint <optional package name> --install --verbose --help 
      
       --clean means the contents of ./build are deleted and CMake's config+generate+build stages are run
       --debug means you want to build your software with optimizations off and debugging info on
       --jobs means you want to specify the number of jobs used by cmake to build the project
       --unittest means that unit test executables found in ./build/<optional package name>/unittest are run, or all unit tests in ./build/*/unittest are run if no package name is provided
       --lint means you check for deviations in ./sourcecode/<optional package name> from the DUNE style guide, https://github.com/DUNE-DAQ/styleguide/blob/develop/dune-daq-cppguide.md, or deviations in all local repos if no package name is provided
       --install means that you want the code from your package(s) installed in the directory which was pointed to by the DBT_INSTALL_DIR environment variable before the most recent clean build
       --verbose means that you want verbose output from the compiler
       --cmake-trace enable cmake tracing
       --cmake-graphviz geneates a target dependency graph

    
    All arguments are optional. With no arguments, CMake will typically just run 
    build, unless build/CMakeCache.txt is missing    
    
EOF

    exit 0    

  elif [[ "$arg" == "--clean" ]]; then
    clean_build=true
  elif [[ "$arg" == "--debug" ]]; then
    debug_build=true
  elif [[ "$arg" == "--unittest" ]]; then
    run_tests=true
    if [[ -n ${nextarg:-} && "$nextarg" =~ ^[^\-] ]]; then
        package_to_test=$nextarg
        i_arg=$((i_arg + 1))
    fi
  elif [[ "$arg" == "--lint" ]]; then
    lint=true
    if [[ -n ${nextarg:-} && "$nextarg" =~ ^[^\-] ]]; then
        package_to_lint=$nextarg
        i_arg=$((i_arg + 1))
    fi
  elif [[ "$arg" == "--verbose" ]]; then
    verbose=true
  elif [[ "$arg" == "--cmake-trace" ]]; then
    cmake_trace=true
  elif [[ "$arg" == "--cmake-graphviz" ]]; then
    cmake_graphviz=true
  elif [[ "$arg" == "--jobs" ]]; then
    if [[ -n ${nextarg:-} && "$nextarg" =~ ^[^\-] ]]; then
        n_jobs=$nextarg
        i_arg=$((i_arg + 1))
    fi
  elif [[ "$arg" == "--pkgname" ]]; then
    error "Use of --pkgname is deprecated; run with \" --help\" to see valid options. Exiting..."
  elif [[ "$arg" == "--install" ]]; then
    perform_install=true

  else
    error "Unknown argument provided; run with \" --help\" to see valid options. Exiting..."
  fi

done

if [[ -z ${DBT_SETUP_BUILD_ENVIRONMENT_SCRIPT_SOURCED:-} ]]; then
 
error "$( cat<<EOF

It appears you haven't yet executed "dbt-setup-build-environment"; please do so before running this 
script. Exiting...

EOF
)"
fi

test -d $BUILDDIR || error "Expected build directory \"$BUILDDIR\" not found. Exiting..." 
cd $BUILDDIR

if ${clean_build}; then 
  
   # Want to be damn sure of we're in the right directory, rm -rf * is no joke...

   if  [[ $( echo $PWD | sed -r 's!.*/(.*)!\1!' ) =~ ^build/*$ ]]; then
     echo "Clean build requested, will delete all the contents of build directory \"$PWD\"."
     echo "If you wish to abort, you have 5 seconds to hit Ctrl-c"
     sleep 5
     rm -rf *
   else
       error "$( cat <<EOF

You requested a clean build, but this script thinks that $BUILDDIR isn't 
the build directory. Please contact John Freeman at jcfree@fnal.gov and notify him of this message.

EOF
)"
   fi

fi


build_log=$LOGDIR/build_attempt_$( date | sed -r 's/[: ]+/_/g' ).log

CMAKE="cmake"

if $cmake_trace; then
  CMAKE="${CMAKE} --trace"
fi

# Are these the requirements for the cmake command???:
# 1. Use Ninja generator by default for speed
# 2. Allow for colored output
#    - currently Ninja does not have a way to force color when not tty
# 3. No single line progress
#    - Ninja currently has no option for multi-line when tty -- filter
#      required
#    - "perfect" 1-2-3-4... happens when piped, but color is lost
#      1-1-1-2-2-2-2-2-3-3-4...
#      during single (with cr); filter could make perfect
# 4. No buffering - print lines (e.g progress) near real time (i.e ASAP)
#    - Ninja "single line" is a single line unless the filter
#      \r as a "record separator". Normally the filter would want to
#      consume it all until the \n.
# 5. save to log file
#    NOTE: less can handle color in the log file using the -R option.
# 6. dbt-build.sh should not "eat" successive lines pasted; dont require big pipeline
# 7. pty script readily available
# Note: using "script" is fundamentally flawed as output can not be filtered
#       outside the "command argument" -- adding filtering inside defeats
#       the purpose.
#
# A python script which does not wait for \n to process.
py_filter_simple='import sys
out=""; lastRT="\r"
xx=sys.stdin.read(1)
while xx:
    if   xx in "\n\r":
        if not (out=="" and lastRT=="\r"):
            sys.stdout.write(out+"\n"); sys.stdout.flush()
        lastRT=xx; out=""
    else: out+=xx
    xx=sys.stdin.read(1)'
py_filter='import sys,re
class Re:
    def __init__(self, reg_ex,flags=0): self.compiled=re.compile(reg_ex,flags)
    def search(self,arg1): # "match" is anchored, "search" is not.
        self.match_obj = self.compiled.search( arg1 ); return self.match_obj
re_progress = Re(r"^\[\d+/\d+]")
out=""; lastRT="\r"; lastProgress=""
xx=sys.stdin.read(1)
while xx:
    if   xx in "\n\r":
        if not (out=="" and lastRT=="\r"):
            if re_progress.search(out):
                thisProgress = re_progress.match_obj.group(0)
                if thisProgress != lastProgress:
                    sys.stdout.write(out+"\n"); sys.stdout.flush()
                lastProgress = thisProgress
            else: sys.stdout.write(out+"\n"); sys.stdout.flush()
        lastRT=xx; out=""
    else: out+=xx
    xx=sys.stdin.read(1)'

awk_filter='BEGIN{RS="[\n\r]";lastRT="\r"}
{if(!($0==""&&lastRT=="\r")){printf "%s%c",$0,"\n";fflush()}lastRT=RT}'

py_pty='import sys,os,signal
stdin,stdout,stderr=0,1,2
ptm,pts=os.openpty();pid=os.fork()
if pid == 0:
    os.dup2(pts, stdout)
    #os.execvp(sys.argv[1], sys.argv[1:])
    sts = os.system(sys.argv[1]); sys.exit(sts>>8)
os.close(pts)
signal.signal(signal.SIGINT, signal.SIG_IGN)
while True:
    try:            chunk = os.read(ptm, 4096)
    except OSError: break
    try:                    os.write(stdout, chunk)
    except BrokenPipeError: os.kill(pid, signal.SIGTERM); break
wait_pid, status = os.waitpid(pid, 0); exit(status >> 8)'


# We usually only need to explicitly run the CMake configure+generate
# makefiles stages when it hasn't already been successfully run;
# otherwise we can skip to the compilation. We use the existence of
# CMakeCache.txt to tell us whether this has happened; notice that it
# gets renamed if it's produced but there's a failure.

if ! [ -e CMakeCache.txt ]; then

  generator_arg=
  if [ "x${SETUP_NINJA}" != "x" ]; then
    generator_arg="-G Ninja"
  fi


  starttime_cfggen_d=$( date )
  starttime_cfggen_s=$( date +%s )

  # Will use $cmd if needed for error message
  cmd="${CMAKE} -DMOO_CMD=$(which moo) -DDBT_ROOT=${DBT_ROOT} -DDBT_DEBUG=${debug_build} -DCMAKE_INSTALL_PREFIX=$DBT_INSTALL_DIR ${generator_arg} $SRCDIR" 

  echo "Executing '$cmd'"
  # Extra "set -o pipefail;" statement to push a cmake error out of the pipe
  # Yes, it's black magic
  #script -qefc "set -o pipefail; ${cmd} |& sed -e 's/\r/\n/g' " $build_log
  #socat - EXEC:"${cmd}",pty |& python -c "$py_filter" |& tee $build_log
  #socat - EXEC:"${cmd}",pty |& awk "$awk_filter" |& tee $build_log
  socat - SYSTEM:"set -o pipefail; ${cmd} |& cat",pty 2>/dev/null | tee $build_log # same as script (no color, good "progress") except does
  retval=${PIPESTATUS[0]}  # Captures the return value of cmake, not tee
  endtime_cfggen_d=$( date )
  endtime_cfggen_s=$( date +%s )

  if [[ "$retval" == "0" ]]; then

    sed -i -r '1 i\# If you want to add or edit a variable, be aware that the config+generate stage is skipped in $build_script if this file exists' $BUILDDIR/CMakeCache.txt
    sed -i -r '2 i\# Consider setting variables you want cached with the CACHE option in the relevant CMakeLists.txt file instead' $BUILDDIR/CMakeCache.txt

    cfggentime=$(( endtime_cfggen_s - starttime_cfggen_s ))
    echo "CMake's config+generate stages took $cfggentime seconds"
    echo "Start time: $starttime_cfggen_d"
    echo "End time:   $endtime_cfggen_d"

  else

    mv -f CMakeCache.txt CMakeCache.txt.most_recent_failure

    error "$( cat <<EOF 

This script ran into a problem running 

$cmd 

from $BUILDDIR (i.e., CMake's config+generate stages). 
Scroll up for details or look at the build log via 

more ${build_log}

Exiting...

EOF
    )"

  exit 40
  fi

else

  echo "The config+generate stage was skipped as CMakeCache.txt was already found in $BUILDDIR"

fi # !-e CMakeCache.txt

if ${cmake_graphviz}; then
  cmd="${CMAKE} --graphviz=graphviz/targets.dot ."
  ${cmd}
  exit $?
fi

nprocs=$( grep -E "^processor\s*:\s*[0-9]+" /proc/cpuinfo  | wc -l )
nprocs_argument=""

if (( $n_jobs <= 0)); then 
  if [[ -n $nprocs && $nprocs =~ ^[0-9]+$ ]]; then
    echo "This script believes you have $nprocs processors available on this system, and will use as many of them as it can"
    nprocs_argument=" -j $nprocs"
  else
    echo "Unable to determine the number of processors available, will not pass the \"-j <nprocs>\" argument on to the build stage" >&2
  fi
else
  nprocs_argument=" -j ${n_jobs}"
fi

starttime_build_d=$( date )
starttime_build_s=$( date +%s )

build_options=""
if $verbose; then
  build_options="${build_options} --verbose"
fi

if ! $cmake_trace ; then
  build_options="${build_options} $nprocs_argument"
fi

# Will use $cmd if needed for error message
cmd="${CMAKE} --build . $build_options"
echo "Executing '$cmd'"
# Extra "set -o pipefail;" statement to push a cmake error out of the pipe
# Yes, it's black magic
#script -qefc "set -o pipefail; ${cmd} |& sed -e 's/\r/\n/g'" $build_log
#script -qefc "set -o pipefail; ${cmd} |& cat" $build_log
#script -qefc "set -o pipefail; ${cmd}" $build_log
#socat - EXEC:"${cmd}",pty |& awk "$awk_filter" |& tee $build_log
#socat - EXEC:"${cmd}",pty |& python -c "$py_filter" |& tee $build_log
#socat - SYSTEM:"set -o pipefail; ${cmd} |& cat",pty 2>/dev/null | tee $build_log # same as script (no color, good "progress") except does not eat pasted lines
#socat - EXEC:"${cmd}",pty |& tee $build_log
#socat - EXEC:"${cmd}",pty,setsid,ctty |& tee $build_log
python -c "$py_pty" "${cmd}" |& python -c "$py_filter" |& tee $build_log

retval=${PIPESTATUS[0]}  # Captures the return value of cmake --build, not tee
endtime_build_d=$( date )
endtime_build_s=$( date +%s )

if [[ "$retval" == "0" ]]; then

  buildtime=$((endtime_build_s - starttime_build_s))

else

  error "$( cat<<EOF 

This script ran into a problem running 

$cmd 

from $BUILDDIR (i.e.,
CMake's build stage). Scroll up for details or look at the build log via 

more ${build_log}

Exiting...

EOF
  )"

  exit 40
fi

num_estimated_warnings=$( grep "warning: " ${build_log} | wc -l )

echo

if [[ -n ${cfggentime:-} ]]; then
  echo
  echo "config+generate stage took $cfggentime seconds"
  echo "Start time: $starttime_cfggen_d"
  echo "End time:   $endtime_cfggen_d"
  echo
else
  echo "config+generate stage was skipped"
fi
echo "build stage took $buildtime seconds"
echo "Start time: $starttime_build_d"
echo "End time:   $endtime_build_d"
echo
echo "Output of build contains an estimated $num_estimated_warnings warnings, and can be viewed later via: "
echo 
echo "   more ${build_log}"
echo

if [[ -n ${cfggentime:-} ]]; then
  echo "CMake's config+generate+build stages all completed successfully"
  echo
else
  echo "CMake's build stage completed successfully"
fi

if $perform_install ; then
  cd $BUILDDIR

  # Will use $cmd if needed for error message
  cmd="cmake --build . --target install -- $nprocs_argument"
  ${cmd}
 
  if [[ "$?" == "0" ]]; then
    echo 
    echo "Installation complete."
    echo "This implies your code successfully compiled before installation; you can either scroll up or run \"more $build_log\" to see build results"
  else
    error "Installation failed. There was a problem running \"$cmd\". Exiting.."
  fi
 
fi


if $run_tests ; then
  COL_YELLOW="\e[33m"
  COL_NULL="\e[0m"
  COL_RED="\e[31m"
  echo 
  echo
  echo
  echo 
  test_log=$LOGDIR/unit_tests_$( date | sed -r 's/[: ]+/_/g' ).log

  cd $BUILDDIR

  source ${DBT_ROOT}/scripts/dbt-setup-runtime-environment.sh

  if [[ -z $package_to_test ]]; then
    package_list=$( find . -mindepth 1 -maxdepth 1 -type d -not -name CMakeFiles )
  else
          package_list=$package_to_test
  fi

  for pkgname in $package_list ; do

    unittestdirs=$( find $BUILDDIR/$pkgname -type d -name "unittest" -not -regex ".*CMakeFiles.*" )

    if [[ -z $unittestdirs ]]; then
      echo
      echo -e "${COL_RED}No unit tests have been written for $pkgname${COL_NULL}"
      echo
      continue
    fi

    num_unit_tests=0

    for unittestdir in $unittestdirs; do
      echo
      echo
      echo "RUNNING UNIT TESTS IN $unittestdir"
      echo "======================================================================"
      for unittest in $unittestdir/* ; do
        if [[ -x $unittest ]]; then
          echo
          echo -e "${COL_YELLOW}Start of unit test suite \"$unittest\"${COL_NULL}" |& tee -a $test_log
          $unittest -l all |& tee -a $test_log
          echo -e "${COL_YELLOW}End of unit test suite \"$unittest\"${COL_NULL}" |& tee -a $test_log
          num_unit_tests=$((num_unit_tests + 1))
        fi
      done

    done

    echo 
    echo -e "${COL_YELLOW}Testing complete for package \"$pkgname\". Ran $num_unit_tests unit test suites.${COL_NULL}"
  done
     
     echo
     echo "Test results are saved in $test_log"
     echo
fi

if $lint; then
  cd $BASEDIR

  if [[ ! -d ./styleguide ]]; then
    echo "Cloning styleguide into $BASEDIR so linting can be applied"
    git clone https://github.com/DUNE-DAQ/styleguide.git
  fi

  if [[ -z $package_to_lint ]]; then
    package_list=$( find build -mindepth 1 -maxdepth 1 -type d -not -name CMakeFiles )
  else
    package_list=$package_to_lint
  fi

  for pkgdir in $package_list; do
    pkgname=$( echo $pkgdir | sed -r 's!.*/(.*)!\1!' )
    ./styleguide/cpplint/dune-cpp-style-check.sh build sourcecode/$pkgname
  done
fi


