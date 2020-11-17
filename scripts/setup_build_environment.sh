#------------------------------------------------------------------------------
HERE=$(cd $(dirname $(readlink -f ${BASH_SOURCE})) && pwd)

if [[ -n "${DBT_SETUP_BUILD_ENVIRONMENT_SCRIPT_SOURCED}" ]]; then
  echo "This script appears to have already been sourced successfully; returning..." >&2
  return 10
fi
echo "This script hasn't yet been sourced (successfully) in this shell; setting up the build environment"

# Import find_work_area function
source ${HERE}/setup_tools.sh
DBT_AREA_ROOT=$(find_work_area)

echo "DBT_AREA_ROOT=${DBT_AREA_ROOT}"
if [[ -z $DBT_AREA_ROOT ]]; then
    echo "Expected work area directory $DBT_AREA_ROOT not found; exiting..." >&2
    return 1
fi

# 1. Load the UPS area information from the local area file
source ${DBT_AREA_ROOT}/${DBT_AREA_FILE}
echo "Product directories ${dune_products_dirs[@]}"
echo "Products ${dune_products[@]}"

setup_ups_product_areas

# 2. Setup the python environment
setup python ${dune_python_version}
source ${DBT_AREA_ROOT}/${DBT_VENV}/bin/activate

if [[ "$VIRTUAL_ENV" == "" ]]
then
  echo "ERROR: [`eval $timenow`]: You are already in a virtual env. Please deactivate first."
  return 11
fi


setup_ups_products

export DBT_INSTALL_DIR=${DBT_AREA_ROOT}/install

if ! [[ "$setup_returns" =~ [1-9] ]]; then
  echo "All setup calls on the packages returned 0, indicative of success"
else
  echo "At least one of the required packages this script attempted to set up didn't set up correctly; returning..." >&2
  return 1
fi

#export PATH=.:${PATH}

export DBT_SETUP_BUILD_ENVIRONMENT_SCRIPT_SOURCED=1
echo "This script has been sourced successfully"
echo



