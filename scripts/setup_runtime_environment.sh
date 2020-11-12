#------------------------------------------------------------------------------
HERE=$(cd $(dirname $(readlink -f ${BASH_SOURCE})) && pwd)

# Import find_work_area function
source ${HERE}/setup_tools.sh

DBT_AREA_ROOT=$(find_work_area)

BUILD_DIR="${DBT_AREA_ROOT}/build"
if [ ! -d "$BUILD_DIR" ]; then
   echo "There doesn't appear to be a ./build subdirectory in this script's directory." >&2
   echo "Please run a copy of this script from the base directory of a development area installed with quick-start.sh" >&2
   echo "Returning..." >&2
   return 10

fi

if [[ -z $DBT_SETUP_BUILD_ENVIRONMENT_SCRIPT_SOURCED ]]; then
      if [[ -e $DBT_AREA_ROOT/setup_build_environment ]]; then
          echo "Lines between the ='s are the output of the sourcing of $DBT_AREA_ROOT/setup_build_environment"
	  echo "======================================================================"
          . $DBT_AREA_ROOT/setup_build_environment 
	  echo "======================================================================"
      else 
          echo "Error: the build environment setup script doesn't appear to have been sourced, " >&2
          echo "but this script can't find $DBT_AREA_ROOT/setup_build_environment. You can try " >&2
	  echo "finding it and sourcing it yourself before sourcing this script, but an assumption " >&2
	  echo "is being broken somewhere" >&2
	  return 20
      fi    
else
      echo "The build environment setup script already appears to have been sourced, so this " 
      echo "script won't try to source it"
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
