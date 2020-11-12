#!/bin/env bash

empty_dir_check=true
edits_check=false

#####################################################################
# common constants - to be moved to a separate, common file
DBT_AREA_FILE='.dunedaq_area'
#####################################################################

starttime_d=$( date )
starttime_s=$( date +%s )

basedir=$PWD
builddir=$basedir/build
logdir=$basedir/log
srcdir=$basedir/sourcecode

precloned_packages="daq-cmake:develop"

export USER=${USER:-$(whoami)}
export HOSTNAME=${HOSTNAME:-$(hostname)}

if [[ -z $USER || -z $HOSTNAME ]]; then
    echo "Problem getting one or both of the environment variables \$USER and \$HOSTNAME; exiting..." >&2
    exit 10
fi

if $empty_dir_check && [[ -n $( ls -a1 | grep -E -v "^\.\.?$" ) ]]; then

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

    potential_edits=$( git -C ${DBT_ROOT} diff --exit-code ${BASH_SOURCE} )

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

superproject_cmakeliststxt=${DBT_ROOT}/configs/CMakeLists.txt
if [[ -e $superproject_cmakeliststxt ]]; then
    cp ${superproject_cmakeliststxt#$srcdir/} $srcdir
else
    echo "Error: expected file \"$superproject_cmakeliststxt\" doesn't appear to exist. Exiting..." >&2
    exit 60
fi

# Create the daq area signature file
cp ${DBT_ROOT}/configs/dunedaq_area.sh $basedir/${DBT_AREA_FILE}


echo "Setting up Python subsystem"
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

