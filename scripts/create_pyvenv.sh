#!/bin/env bash

###
# Default virtual env name
###
VENV_NAME="dbt_venv"

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
    setup python
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
if [ -f "$DBT_AREA_ROOT/$VENV_NAME/pyvenv.cfg" ]; then
    echo "INFO [`eval $timenow`]: virtual_env $VENV_NAME already exists. "
    cat "$DBT_AREA_ROOT/$VENV_NAME/pyvenv.cfg"
else
    echo "INFO [`eval $timenow`]: creating virtual_env $VENV_NAME. "
    python -m venv $VENV_NAME
fi

python -m pip install -r .pyvenv_requirements.txt
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

