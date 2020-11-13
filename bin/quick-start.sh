#!/bin/env bash

empty_dir_check=true
edits_check=true

#####################################################################
# common constants - to be moved to a separate, common file
DBT_AREA_FILE='.dunedaq_area'
#####################################################################

starttime_d=$( date )
starttime_s=$( date +%s )

BASEDIR=$PWD
BUILDDIR=$BASEDIR/build
LOGDIR=$BASEDIR/log
SRCDIR=$BASEDIR/sourcecode

dbt_version="develop"
precloned_packages="daq-cmake:${dbt_version}"

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
    # [ $(git rev-parse HEAD) = $(git ls-remote $(git rev-parse --abbrev-ref @{u} | sed 's/\// /g') | cut -f1) ] && echo up to date || echo not up to date
    # git ls-remote $(git rev-parse --abbrev-ref @{u} | sed 's/\// /g') | cut -f1
    DBT_GIT="git -C ${DBT_ROOT}"

    # 1. Get the local repo git ref
    DBT_LOCAL_REF=$(${DBT_GIT} rev-parse HEAD)

    # 2. Get the name of the upstream branch (if any)
    DBT_UPSTR_BRANCH=$(${DBT_GIT} rev-parse --abbrev-ref @{u} | sed 's/\// /g' 2> /dev/null )
    if [ $? -ne 0 ]; then
        echo "Screw it"
    fi

    # 3. Get the remote ref for the upstream branch
    DBT_REMOTE_REF=$(${DBT_GIT} ls-remote ${DBT_UPSTR_BRANCH} | cut -f1)

    echo $DBT_LOCAL_REF
    echo $DBT_REMOTE_REF

    potential_edits=$( git -C ${DBT_ROOT} diff --exit-code ${BASH_SOURCE} )

    if [[ -n $potential_edits ]]; then

	cat<<EOF >&2                                                                                                             
Error: this script you're trying to run doesn't match with the version
of the script at the head of the corresponding branch in the daq-buildtool's
central repository. This may mean that this script makes obsolete 
assumptions, etc., which could compromise your working
environment. Please update the daq-buildtools version and create your 
area according to the instructions at https://github.com/DUNE-DAQ/app-framework/wiki/Compiling-and-running

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

superproject_cmakeliststxt=${DBT_ROOT}/configs/CMakeLists.txt
if [[ -e $superproject_cmakeliststxt ]]; then
    cp ${superproject_cmakeliststxt#$SRCDIR/} $SRCDIR
else
    echo "Error: expected file \"$superproject_cmakeliststxt\" doesn't appear to exist. Exiting..." >&2
    exit 60
fi

# Create the daq area signature file
cp ${DBT_ROOT}/configs/dunedaq_area.sh $BASEDIR/${DBT_AREA_FILE}


echo "Setting up the Python subsystem"
create_pyvenv.sh

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

