#!/usr/bin/bash

if [[ -z $DBT_SETUP_BUILD_ENVIRONMENT_SCRIPT_SOURCED ]]; then

echo "This script hasn't yet been sourced (successfully) in this shell; setting up the build environment"

export DBT_INSTALL_DIR=$(cd $(dirname ${BASH_SOURCE}) && pwd)/install

#############################################################
HERE=$(cd $(dirname $(readlink -f ${BASH_SOURCE})) && pwd)

# Import find_work_area function
source ${HERE}/setup_tools.sh

BASEDIR=$(find_work_area)
echo BASEDIR=${BASEDIR}
if [[ -z $BASEDIR ]]; then
    echo "Expected work aread directory $BASEDIR not found; exiting..." >&2
    return 1
fi

# Source the area settings
source ${BASEDIR}/.dunedaq_area
echo "Product directories ${dune_products_dirs}"
echo "Products ${dune_products[@]}"

prodDirArr=(${dune_products_dirs//:/})
for proddir in ${prodDirArr[@]}; do
    source ${proddir}/setup
done

setup_returns=""

for prod in "${dune_products[@]}"; do
    prodArr=(${prod})

    setup_cmd="setup ${prodArr[0]} ${prodArr[1]}"
    if [[ ${#prodArr[@]} -eq 3 ]]; then
        setup_cmd="${setup_cmd} -q ${prodArr[2]}"
    fi
    echo $setup_cmd
    ${setup_cmd}
    setup_returns=$setup_returns"$? "
done
#############################################################


if ! [[ "$setup_returns" =~ [1-9] ]]; then
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



