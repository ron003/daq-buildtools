#!/bin/env bash

#------------------------------------------------------------------------------
HERE=$(cd $(dirname $(readlink -f ${BASH_SOURCE})) && pwd)

# Import find_work_area function
source ${HERE}/setup_tools.sh

DBT_AREA_ROOT=$(find_work_area)
if [[ -z ${DBT_AREA_ROOT} ]]; then
    log_error "Expected work area directory ${DBT_AREA_ROOT} not found; exiting..." 
    exit 2
fi
#------------------------------------------------------------------------------
timenow="date \"+%D %T\""

###
# Check if inside a virtualenv already
###
if [[ "$VIRTUAL_ENV" != "" ]]
then
  log_error "You are already in a virtual env. Please deactivate first. Exiting..."
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
	log_error "There was a problem sourcing ${DBT_AREA_ROOT}/${DBT_AREA_FILE}. Exiting..."
	exit 4
    fi

    setup_ups_product_areas

    setup python ${dune_python_version}
    if ! [[ $? -eq 0 ]]; then
	log_error "The \"setup python ${dune_python_version}\" call failed. Exiting..." 
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
	log_error "Problem creating virtual_env ${DBT_VENV}. Exiting..." 
	exit 6
    fi
fi

source ${DBT_AREA_ROOT}/${DBT_VENV}/bin/activate

if [[ "$VIRTUAL_ENV" == "" ]]
then
  log_error "Failed to load the virtual env. Exiting..." 
  exit 8
fi

python -m pip install -r ${DBT_ROOT}/configs/pyvenv_requirements.txt
if ! [[ $? -eq 0 ]]; then
    log_error "Installing required modules failed. Exiting..." 
    exit 9
fi

deactivate
if ! [[ $? -eq 0 ]]; then
    log_error "Call to \"deactivate\" returned nonzero. Exiting..." 
    exit 10
fi


