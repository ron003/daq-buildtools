#!/bin/env bash

function print_usage() {
                cat << EOU
Usage
-----

To create a new DUNE DAQ development area:
      
    $( basename $0 ) <dunedaq-release>  -r/--release-path <path to release area>

To list the available DUNE DAQ releases:

    $( basename $0 ) --list

Arguments and options:

    dunedaq-release: is the name of the release the new work area will be based on (e.g. dunedaq-v2.0.0)
    -l/--list: show the list of available releases
    -r/--release-path: is the path to the release archive (RELEASE_BASEPATH var; default: /cvmfs/dune.opensciencegrid.org/dunedaq/DUNE/releases-tmp)

EOU
}


EMPTY_DIR_CHECK=true
EDITS_CHECK=true
RELEASE_BASEPATH="/cvmfs/dune.opensciencegrid.org/dunedaq/DUNE/releases-tmp"
BASEDIR=$PWD
SHOW_RELEASE_LIST=false

# Define usage function here

#####################################################################
# Load DBT common constants
source ${DBT_ROOT}/scripts/dbt-setup-tools.sh

# This is a horrible lash-up and should be replaced with a proper manifest file or equivalent.
# UPS_PKGLIST="${DBT_AREA_FILE:1}.sh"
UPS_PKGLIST="${DBT_AREA_FILE}.sh"
PY_PKGLIST="pyvenv_requirements.txt"
DAQ_BUILDORDER_PKGLIST="dbt-build-order.cmake"

# We use "$@" instead of $* to preserve argument-boundary information
options=$(getopt -o 'hlr:e' -l 'help,list,release-base-path:,disable-edit-check' -- "$@") || exit
eval "set -- $options"

while true; do
    case $1 in
        (-l|--list)
            # List available releases
            SHOW_RELEASE_LIST=true
            shift;;
        (-r|--release-path)
            RELEASE_BASEPATH=$2
            shift 2;;
        (-e|--disable-edit-check)
            EDITS_CHECK=false
            shift;;
        (-h|--help)
            print_usage
            exit 0;;
        (--)  shift; break;;
        (*)   exit 1;;           # error
    esac
done

ARGS=("$@")

if [[ "${SHOW_RELEASE_LIST}" == true ]]; then
    list_releases
    exit 0;
fi

test ${#ARGS[@]} -eq 1 || error "Wrong number of arguments. Try '$( basename $0 ) -h' for more information." 

RELEASE=${ARGS[0]}
RELEASE_PATH=$(realpath -m "${RELEASE_BASEPATH}/${RELEASE}")

test -d ${RELEASE_PATH} || error  "Release path '${RELEASE_PATH}' does not exist. Exiting..."

if [[ -n $DBT_SETUP_BUILD_ENVIRONMENT_SCRIPT_SOURCED ]]; then
    error "$( cat<<EOF

It appears you're trying to run this script from an environment
where another development area's been set up.  You'll want to run this
from a clean shell. Exiting...     

EOF
)"
fi

starttime_d=$( date )
starttime_s=$( date +%s )

BUILDDIR=$BASEDIR/build
LOGDIR=$BASEDIR/log
SRCDIR=$BASEDIR/sourcecode

export USER=${USER:-$(whoami)}
export HOSTNAME=${HOSTNAME:-$(hostname)}

if [[ -z $USER || -z $HOSTNAME ]]; then
    error "Problem getting one or both of the environment variables \$USER and \$HOSTNAME. Exiting..." 
fi

if $EMPTY_DIR_CHECK && [[ -n $( ls -a1 | grep -E -v "^\.\.?$" ) ]]; then

error "$( cat <<EOF

There appear to be files in $BASEDIR besides this script 
(run "ls -a1" to see this); this script should only be run in a clean
directory. Exiting...

EOF
)"

elif ! $EMPTY_DIR_CHECK ; then

    cat<<EOF >&2

WARNING: The check for whether any files besides this script exist in
its directory has been switched off. This may mean assumptions the
script makes are violated, resulting in undesired behavior.

EOF

    sleep 5

fi


if $EDITS_CHECK ; then

    echo "Comparing local daq-buildtools code with code in the central repository..."

    cd ${DBT_ROOT}

    # 1. Get the local repo git ref
    local_ref=$(git rev-parse HEAD)
    code_desc=""

    # 2. Is it a tag?
    the_tag=$(git describe --tags --exact-match HEAD 2> /dev/null )
    if [[ $? -eq 0 ]]; then
        echo "Looking for updates of ${the_tag}"
        # 2.1. Yes, let's get the remote ref
        remote_ref=$(git ls-remote --tags $(git remote) tags ${the_tag} | cut -f1 )
	code_desc="${the_tag} tag "
    else
        # 2.2. No, it's a branch.
        # Get the name of the upstream branch (if any)
        upstr_branch=$(git rev-parse --abbrev-ref @{u} 2> /dev/null )
        if [[ $? -eq 0 ]]; then
            echo "Looking for updates of branch ${upstr_branch}"
            # 3. Get the remote ref for the upstream branch
            remote_ref=$(git ls-remote ${upstr_branch/\// } 2> /dev/null | cut -f1)
        else
            remote_ref="<undefined>"
        fi
	code_desc="${upstr_branch/origin\//} branch "
    fi

    if [[ "$remote_ref" != "<undefined>" && "$local_ref" != "$remote_ref" && -n $( git diff $local_ref $remote_ref ) ]]; then

      meaningful_head_differences=true


    cat<<EOF >&2                                                                                                             
Error: The local ${code_desc}daq-buildtools you're trying to use
(${DBT_ROOT}) contains code which doesn't match up with the
corresponding ${code_desc}in the daq-buildtool's central repository.

Local hash: $local_ref
Remote hash: $remote_ref

EOF

    fi

    local_edits=$( git diff --exit-code ${BASH_SOURCE} )

    if [[ -n $local_edits ]]; then

	error_preface
	echo >&2
	cat<<EOF >&2                                                                                                             
The version of daq-buildtools you're trying to run contains local edits.

EOF

    fi

if [[ -n $local_edits || -n $meaningful_head_differences ]]; then

    cat<<EOF >&2                                                                                                             
This may mean that this script makes obsolete assumptions, etc., which 
could compromise your working environment. 

Please ensure that there's no difference in the ${code_desc}git diff
between your local repo and the central repo, and then run this script
again.

EOF

    exit 40

    fi

    cd $BASEDIR

else 

cat<<EOF >&2

WARNING: The feature whereby this script checks itself to see if it's
different than its version at the head of the central repo's develop
branch has been switched off. User assumes the risk that the script
may make out-of-date assumptions.

EOF

sleep 5

fi # if $EDITS_CHECK

mkdir -p $BUILDDIR
mkdir -p $LOGDIR
mkdir -p $SRCDIR

cd $SRCDIR

superproject_cmakeliststxt=${DBT_ROOT}/configs/CMakeLists.txt
cp ${superproject_cmakeliststxt#$SRCDIR/} $SRCDIR
test $? -eq 0 || error "There was a problem copying \"$superproject_cmakeliststxt\" to $SRCDIR. Exiting..."

cp ${RELEASE_PATH}/${DAQ_BUILDORDER_PKGLIST} $SRCDIR
test $? -eq 0 || error "There was a problem copying \"$superproject_buildorder\" to $SRCDIR. Exiting..."

# Create the daq area signature file
cp ${RELEASE_PATH}/${UPS_PKGLIST} $BASEDIR/${DBT_AREA_FILE}
test $? -eq 0 || error "There was a problem copying over the daq area signature file. Exiting..." 


echo "Setting up the Python subsystem"
bash dbt-create-pyvenv.sh ${RELEASE_PATH}/${PY_PKGLIST}

test $? -eq 0 || error "Call to create_pyvenv.sh returned nonzero. Exiting..."

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

