#!/bin/env bash

#------------------------------------------------------------------------------
HERE=$(cd $(dirname $(readlink -f ${BASH_SOURCE})) && pwd)

# Import find_work_area function
source ${HERE}/setup_tools.sh

DBT_AREA_ROOT=$(find_work_area)
if [[ -z ${DBT_AREA_ROOT} ]]; then
    echo "Expected work area directory ${DBT_AREA_ROOT} not found; exiting..." >&2
    return 1
fi
#------------------------------------------------------------------------------
timenow="date \"+%D %T\""

###
# Check if inside a virtualenv already
###
if [[ "$VIRTUAL_ENV" != "" ]]
then
  echo "ERROR: [`eval $timenow`]: You are already in a virtual env. Please deactivate first."
  return 11
fi

###
# Check if python from cvmfs has been set up.
# Add version check in the future.
###
if [ -z "$SETUP_PYTHON" ]; then    
    echo "INFO [`eval $timenow`]: Python UPS product is not set, setting it from cvmfs now."
    # Source the area settings to determine what area where to get python from
    source ${DBT_AREA_ROOT}/${DBT_AREA_FILE}

    setup_ups_product_areas

    setup python ${dune_python_version}
    if [[ $? != "0" ]]; then
        echo "ERROR [`eval $timenow`]: setup python failed, please check if you have sourced the \"setup_build_environment\" script and run this script again."
        return 10
    fi
else
    echo "INFO [`eval $timenow`]: Python UPS product $PYTHON_VERSION has been set up."
fi

###
# Check existance/create the default virtual_env
###
if [ -f "${DBT_AREA_ROOT}/${DBT_VENV}/pyvenv.cfg" ]; then
    echo "INFO [`eval $timenow`]: virtual_env ${DBT_VENV} already exists. "
    cat "${DBT_AREA_ROOT}/${DBT_VENV}/pyvenv.cfg"
else
    echo "INFO [`eval $timenow`]: creating virtual_env ${DBT_VENV}. "
    python -m venv ${DBT_VENV} ${DBT_AREA_ROOT}/${DBT_VENV}
fi

source ${DBT_AREA_ROOT}/${DBT_VENV}/bin/activate

if [[ "$VIRTUAL_ENV" == "" ]]
then
  echo "ERROR: [`eval $timenow`]: You are already in a virtual env. Please deactivate first."
  return 11
fi

python -m pip install -r ${DBT_ROOT}/configs/pyvenv_requirements.txt
if [[ $? != "0" ]]; then
    echo "ERROR [`eval $timenow`]: Installing required modules failed."
    return 12
fi

###
# special handling of the moo module since PyPI has a module with same name.
##
if python -c "import moo" &> /dev/null; then
    echo "INFO [`eval $timenow`]: moo is installed."
    pip list|grep moo
else
    echo "INFO [`eval $timenow`]: moo is not installed. Install it now."
    pip install git+git://github.com/brettviren/moo.git
    if [[ $? != "0" ]]; then
        echo "ERROR [`eval $timenow`]: Installing moo failed."
        return 13
    fi
fi

deactivate

