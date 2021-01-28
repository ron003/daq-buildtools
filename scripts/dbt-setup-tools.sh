#------------------------------------------------------------------------------
HERE=$(cd $(dirname $(readlink -f ${BASH_SOURCE})) && pwd)

#------------------------------------------------------------------------------
# Constants

# Colors
COL_RED="\e[31m"
COL_GREEN="\e[32m"
COL_YELLOW="\e[33m"
COL_BLUE="\e[34m"
COL_NULL="\e[0m"

source ${HERE}/dbt-setup-constants.sh

#------------------------------------------------------------------------------
# Print an error message and exit if the user did not run your script using
# `source yourscript.sh` (but rather `bash yourscript.sh` or similar)
# This command traces back up to the original user command, it does not
# consider 'inbetween' sourced or not-sourced scripts
function abort_if_not_sourced() {
  if [[ "$(basename ${BASH_SOURCE[-1]})" == "$(basename $0)" ]]; then
    >&2 echo -e "${COL_RED}Please run me by sourcing me${COL_NULL}"
    >&2 echo "source $0"
    exit 1
  fi
}
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
function setup_ups_product_areas() {
  
  if [ -z "${dune_products_dirs:-}" ]; then
    echo "UPS product directories variable (dune_products_dirs) undefined; no products areas will be set up" >&2
  fi

  for proddir in ${dune_products_dirs[@]}; do
      # these setup scripts are not controlled by us
      # they fail when setting 'safe mode' options like the ones being disabled just below
      # they are re-enabled after, if they were set
      prevbashoptions="$(set +o)"
      set +o errexit +o nounset +o pipefail
      source ${proddir}/setup
      if ! [[ $? -eq 0 ]]; then
	  echo "Warning: unable to set up products area \"${proddir}\"" >&2
      fi
      # re-enable options that we may have disabled
      eval "$prevbashoptions"
  done

}
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
function setup_ups_products() {

  # And another function here?
  setup_returns=""

  if [ -z "${dune_products}" ]; then
    >&2 echo "UPS products variable (dune_products_dirs) undefined";
  fi

  for prod in "${dune_products[@]}"; do
      prodArr=(${prod})

      setup_cmd="setup -B ${prodArr[0]//-/_} ${prodArr[1]}"
      if [[ ${#prodArr[@]} -eq 3 ]]; then
          setup_cmd="${setup_cmd} -q ${prodArr[2]}"
      fi
      echo $setup_cmd
      # these setup scripts are not controlled by us
      # they fail when setting 'safe mode' options like the ones being disabled just below
      # they are re-enabled after, if they were set
      prevbashoptions="$(set +o)"
      set +o errexit +o nounset +o pipefail
      # setup command will silently fail (return 0)
      # but setup also produces no output on success, we can check for this
      # but setup also fails when running in a subshell (yes)
      # any pipes make bash run your command in a subshell
      # hence the 'dumb' tmp file approach
      tmpfile=$(mktemp)
      ${setup_cmd} > $tmpfile 2>&1
      exitcode="$?"
      output="$(cat $tmpfile)"
      if [[ ! "$(cat $tmpfile)" == "" ]]; then
        >&2 echo "detected failure in setup output:"
        >&2 echo "$output"
        exitcode="1"
      fi
      rm -rf "$tmpfile"
      setup_returns=$setup_returns"$exitcode "
      # re-enable options that we may have disabled
      eval "$prevbashoptions"
  done
}
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
function find_work_area() {
  SLASHES=${PWD//[^\/]/}

  SEARCH_PATH=${PWD}
  WA_PATH=""
  for(( i=${#SLASHES}; i>0; i--)); do
    WA_SEARCH_PATH="${SEARCH_PATH}/${DBT_AREA_FILE}"
    # echo "Looking for $WA_SEARCH_PATH"
    if [ -f "${WA_SEARCH_PATH}" ]; then
      WA_PATH="${WA_SEARCH_PATH}"
      break
    fi
    SEARCH_PATH=$(dirname ${SEARCH_PATH})
  done

  if [[ -n "${WA_PATH:-}" ]]; then
    echo $(dirname ${WA_PATH})
  fi
}
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
function list_releases() {
    # How? RELEASE_BASEPATH subdirs matching some condition? i.e. dunedaq_area.sh file in it?
    FOUND_RELEASES=($(find ${RELEASE_BASEPATH} -maxdepth 2 -name ${UPS_PKGLIST} -printf '%h '))
    for rel in "${FOUND_RELEASES[@]}"; do
        echo " - $(basename ${rel})"
    done 
}
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
function add_path() {
  # Assert that we got enough arguments
  if [[ $# -ne 2 ]]; then
    echo "path add: needs 2 arguments"
    return 1
  fi
  PATH_NAME=$1
  PATH_VAL=${!1}
  PATH_ADD=$2

  # Add the new path only if it is not already there
  if [[ ":$PATH_VAL:" != *":$PATH_ADD:"* ]]; then
    # Note
    # ${PARAMETER:+WORD}
    #   This form expands to nothing if the parameter is unset or empty. If it
    #   is set, it does not expand to the parameter's value, but to some text
    #   you can specify
    # https://tldp.org/LDP/abs/html/parameter-substitution.html
    PATH_VAL="$PATH_ADD${PATH_VAL:+":$PATH_VAL"}"

    echo -e "${COL_BLUE}Added ${PATH_ADD} to ${PATH_NAME}${COL_NULL}"

    # use eval to reset the target
    eval "${PATH_NAME}=${PATH_VAL}"
  fi
}
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
function add_many_paths() {
  for d in "${@:2}"
  do
    add_path $1 $d
  done
}
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
function error_preface() {

  # most likely this file is sourced and used in another script
  # get path of parent script (i.e. not 'dbt-setup-tools.sh')
  for dbt_file in "${BASH_SOURCE[@]}"; do
    # ${BASH_SOURCE[0]} is always the name of this file
    if ! [[ "${BASH_SOURCE[0]}" =~ "$dbt_file" ]]; then
	    break
	  fi
  done

  dbt_file=$( basename $dbt_file )

  timenow="date \"+%D %T\""
  echo -n "ERROR: [`eval $timenow`] [${dbt_file}]:" >&2
}
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
function error() {

    error_preface
    echo -e " ${COL_RED} ${1} ${COL_NULL} " >&2

    # if this file was not sourced, exit
    if [[ "$(basename ${BASH_SOURCE[-1]})" == "$(basename $0)" ]]; then
        exit 100
    fi
}
#------------------------------------------------------------------------------

  
