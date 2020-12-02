#!/bin/env bash

empty_dir_check=true
edits_check=true

source $DBT_ROOT/scripts/setup_constants.sh

starttime_d=$( date )
starttime_s=$( date +%s )

BASEDIR=$PWD
BUILDDIR=$BASEDIR/build
LOGDIR=$BASEDIR/log
SRCDIR=$BASEDIR/sourcecode

export USER=${USER:-$(whoami)}
export HOSTNAME=${HOSTNAME:-$(hostname)}

if [[ -z $USER || -z $HOSTNAME ]]; then
    echo "Problem getting one or both of the environment variables \$USER and \$HOSTNAME; exiting..." >&2
    exit 10
fi

if $empty_dir_check && [[ -n $( ls -a1 | grep -E -v "^\.\.?$" ) ]]; then

    cat<<EOF >&2                                                                               

There appear to be files in $BASEDIR besides this script (run "ls -a1"
to see this); this script should only be run in a clean
directory. Exiting...

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

    cd ${DBT_ROOT}

    # 1. Get the local repo git ref
    local_ref=$(git rev-parse HEAD)

    # 2. Is it a tag?
    the_tag=$(git describe --tags --exact-match HEAD 2> /dev/null )
    if [[ $? -eq 0 ]]; then
        echo "Looking for updates of ${the_tag}"
        # 2.1. Yes, let's get the remote ref
        remote_ref=$(git ls-remote --tags $(git remote) tags ${the_tag} | cut -f1 )
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
    fi

    if [[ "$remote_ref" != "<undefined>" && "$local_ref" != "$remote_ref" && -n $( git diff $local_ref $remote_ref ) ]]; then

      meaningful_head_differences=true

    cat<<EOF >&2                                                                                                             
ERROR: The version of daq-buildtools you're trying to run doesn't match with 
       the version at the head of the corresponding branch in the daq-buildtool's
       central repository.

       Local hash: $local_ref
       Remote hash: $remote_ref

EOF

    fi

    local_edits=$( git diff --exit-code ${BASH_SOURCE} )

    if [[ -n $local_edits ]]; then

	cat<<EOF >&2                                                                                                             
ERROR: the version of daq-buildtools you're trying to run contains local edits.

EOF

    fi

if [[ -n $local_edits || -n $meaningful_head_differences ]]; then
    cat<<EOF >&2                                                                                                             
This may mean that this script makes obsolete assumptions, etc., which 
could compromise your working environment. 

Please update the daq-buildtools version and create your area according to 
the instructions at 

https://github.com/DUNE-DAQ/appfwk/wiki/Compiling-and-running

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

fi # if $edits_check

mkdir -p $BUILDDIR
mkdir -p $LOGDIR
mkdir -p $SRCDIR

cd $SRCDIR

superproject_cmakeliststxt=${DBT_ROOT}/configs/CMakeLists.txt
if [[ -e $superproject_cmakeliststxt ]]; then
    cp ${superproject_cmakeliststxt#$SRCDIR/} $SRCDIR
else
    echo "Error: expected file \"$superproject_cmakeliststxt\" doesn't appear to exist. Exiting..." >&2
    exit 60
fi

# Create the daq area signature file
cp ${DBT_ROOT}/configs/dunedaq_area.sh $BASEDIR/${DBT_AREA_FILE}

if ! [[ $? -eq 0 ]]; then
    echo "There was a problem copying over the daq area signature file; exiting..." >&2
    exit 61
fi

echo "Setting up the Python subsystem"
create_pyvenv.sh

if ! [[ $? -eq 0 ]]; then
    echo "Error: call to create_pyvenv.sh returned nonzero. Exiting..." >&2
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

