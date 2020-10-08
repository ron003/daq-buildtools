
WORK_AREA_FILE='.dunedaq_area'

function find_work_area() {
  SLASHES=${PWD//[^\/]/}

  SEARCH_PATH=${PWD}
  WAF_PATH=""
  for(( i=${#SLASHES}; i>0; i--)); do
    WAF_SEARCH_PATH="${SEARCH_PATH}/${WORK_AREA_FILE}"
    # echo "Looking for $WAF_SEARCH_PATH"
    if [ -f "${WAF_SEARCH_PATH}" ]; then
      WAF_PATH="${WAF_SEARCH_PATH}"
      break
    fi
    SEARCH_PATH=$(dirname ${SEARCH_PATH})
  done

  echo $(dirname ${WAF_PATH})
}