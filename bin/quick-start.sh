#!/bin/env bash

clean_dir_check=true
no_mods_check=true

# "set -e" means the script will exit if any commands return
# nonzero. If this setting is commented out for any reason, it would
# be an excellent idea to add explicit checks on these return values.

set -e
if [[ "$?" != "0" ]]; then
    echo "\"set -e\" is apparently not a command recognized by your shell; exiting..." >&2
    exit 1
fi

starttime=$( date )

startdir=$PWD

export USER=${USER:-$(whoami)}
export HOSTNAME=${HOSTNAME:-$(hostname)}

if $clean_dir_check && [[ -n $( ls -a1 | grep -E -v "^quick-mrb-start.*" | grep -E -v "^\.\.?$" ) ]]; then

    cat<<EOF >&2                                                                                     
                                                                                                     
There appear to be files in $startdir besides 
this script; this script should only be run in a clean directory. Exiting...

EOF
    exit 20
fi

qs_tmpdir=/tmp/${USER}_for_quick-start
mkdir -p $qs_tmpdir

returndir=$PWD
cd $qs_tmpdir
rm -f quick-start.sh
repoloc=https://raw.githubusercontent.com/jcfreeman2/daq-buildtools/develop/bin/quick-start.sh
curl -O $repoloc

potential_edits=$( diff $startdir/quick-start.sh $qs_tmpdir/quick-start.sh )

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

echo "Start time: $starttime"
echo "End time: "$(date)
echo "Script completed successfully"
exit 0

