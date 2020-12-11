#------------------------------------------------------------------------------
HERE=$(cd $(dirname $(readlink -f ${BASH_SOURCE})) && pwd)

# Import find_work_area function
source ${HERE}/dbt-setup-tools.sh

DBT_AREA_ROOT=$(find_work_area)

BUILD_DIR="${DBT_AREA_ROOT}/build"
if [ ! -d "$BUILD_DIR" ]; then
    
    error "$( cat <<EOF 

There doesn't appear to be a "build" subdirectory in ${DBT_AREA_ROOT}.
Please run a copy of this script from the base directory of a development area installed with dbt-init.sh
Returning...
EOF
)"
    return 1

fi

if [[ -z $DBT_SETUP_BUILD_ENVIRONMENT_SCRIPT_SOURCED ]]; then
      type dbt-setup-build-environment > /dev/null
      retval="$?"

      if [[ $retval -eq 0 ]]; then
          echo "Lines between the ='s are the output of running dbt-setup-build-environment"
	  echo "======================================================================"
          dbt-setup-build-environment 
	  retval="$?"
	  echo "======================================================================"
	  if ! [[ $retval -eq 0 ]]; then
	      error "There was a problem running dbt-setup-build-environment. Exiting..." 
	      return $retval
	  fi
      else

	  error "$( cat<<EOF 

Error: this script tried to execute "dbt-setup-build-environment" but was unable 
to find it. Either the daq-buildtools environment hasn't yet been set up, or 
an assumption in the daq-buildtools framework is being broken somewhere. Returning...

EOF
)"
	  return 20
      fi    
else
    cat <<EOF
The build environment setup script already appears to have been sourced, so this 
script won't try to source it

EOF
fi


DAQ_APPS_PATHS=$(find $BUILD_DIR -maxdepth 2 -type d -not -name '*CMakeFiles*' -path '*/apps')
DAQ_LIB_PATHS=$(find $BUILD_DIR -maxdepth 2 -type d -not -name '*CMakeFiles*' -path '*/src')
DAQ_PLUGS_PATHS=$(find $BUILD_DIR -maxdepth 2 -type d -not -name '*CMakeFiles*' -path '/*plugins')
DAQ_TEST_APPS_PATHS=$(find $BUILD_DIR -maxdepth 3 -type d -not -name '*CMakeFiles*' -path '*/test/apps')
DAQ_TEST_PLUGS_PATHS=$(find $BUILD_DIR -maxdepth 3 -type d -not -name '*CMakeFiles*' -path '*/test/plugins')

add_many_paths PATH $DAQ_APPS_PATHS $DAQ_TEST_APPS_PATHS
add_many_paths LD_LIBRARY_PATH $DAQ_LIB_PATHS
add_many_paths CET_PLUGIN_PATH $DAQ_PLUGS_PATHS $DAQ_TEST_PLUGS_PATHS

unset DAQ_APPS_PATHS DAQ_LIB_PATHS DAQ_PLUGS_PATHS DAQ_TEST_APPS_PATHS DAQ_TEST_PLUGS_PATHS

echo -e "${COL_GREEN}This script has been sourced successfully${COL_NULL}"
echo
