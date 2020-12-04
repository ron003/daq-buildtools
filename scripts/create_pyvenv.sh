#!/bin/env bash

#------------------------------------------------------------------------------
HERE=$(cd $(dirname $(readlink -f ${BASH_SOURCE})) && pwd)

# Import find_work_area function
source ${HERE}/setup_tools.sh

DBT_AREA_ROOT=$(find_work_area)
if [[ -z ${DBT_AREA_ROOT} ]]; then
    echo "Expected work area directory ${DBT_AREA_ROOT} not found; exiting..." >&2
    exit 2
fi
#------------------------------------------------------------------------------
timenow="date \"+%D %T\""

###
# Check if inside a virtualenv already
###
if [[ "$VIRTUAL_ENV" != "" ]]
then
  echo "ERROR: [`eval $timenow`]: You are already in a virtual env. Please deactivate first. Exiting..."
  exit 3
fi

###
# Check if python from cvmfs has been set up.
# Add version check in the future.
###
if [ -z "$SETUP_PYTHON" ]; then    
    echo "INFO [`eval $timenow`]: Python UPS product is not set, setting it from cvmfs now."
    # Source the area settings to determine what area where to get python from
    source ${DBT_AREA_ROOT}/${DBT_AREA_FILE}
    
    if ! [[ $? -eq 0 ]]; then
	echo "Error: there was a problem sourcing ${DBT_AREA_ROOT}/${DBT_AREA_FILE}. Exiting..." >&2
	exit 4
    fi

    setup_ups_product_areas

    setup python ${dune_python_version}
    if ! [[ $? -eq 0 ]]; then
        echo "ERROR [`eval $timenow`]: the \"setup python ${dune_python_version}\" call failed. Exiting..." >&2
        exit 5
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
    python -m venv ${DBT_AREA_ROOT}/${DBT_VENV}

    if ! [[ $? -eq 0 ]]; then
	echo "Error: problem creating virtual_env ${DBT_VENV}. Exiting..." >&2
	exit 6
    fi
fi

source ${DBT_AREA_ROOT}/${DBT_VENV}/bin/activate

if ! [[ $? -eq 0 ]]; then
    echo "Error: there was a problem calling \"source ${DBT_AREA_ROOT}/${DBT_VENV}/bin/activate\". Exiting..." >&2
    exit 7
fi


if [[ "$VIRTUAL_ENV" == "" ]]
then
  echo "ERROR: [`eval $timenow`]: Failed to load the virtual env. Exiting..." >&2
  exit 8
fi

python -m pip install -r ${DBT_ROOT}/configs/pyvenv_requirements.txt
if ! [[ $? -eq 0 ]]; then
    echo "ERROR [`eval $timenow`]: Installing required modules failed. Exiting..." >&2
    exit 9
fi

deactivate
if ! [[ $? -eq 0 ]]; then
    echo "Error: call to \"deactivate\" returned nonzero. Exiting..." >&2
    exit 10
fi

exit 0
