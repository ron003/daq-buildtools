#------------------------------------------------------------------------------
HERE=$(cd $(dirname $(readlink -f ${BASH_SOURCE})) && pwd)

export DBT_ROOT=${HERE}

# Import add_many_paths function
source ${DBT_ROOT}/scripts/setup_tools.sh

if ! [[ $? -eq 0 ]]; then
    echo "Error: there was a problem sourcing ${DBT_ROOT}/scripts/setup_tools.sh. Exiting..." >&2
    return 1
fi

add_many_paths PATH ${DBT_ROOT}/bin ${DBT_ROOT}/scripts
export PATH

for addedpath in ${DBT_ROOT}/bin ${DBT_ROOT}/scripts; do
    if [[ -z $( echo $PATH | tr ":" "\n" | grep $addedpath ) ]]; then
	echo "Error: there was a problem adding $addedpath to \$PATH. Exiting..." >&2
	return 2
    fi
done

alias setup_build_environment="source ${DBT_ROOT}/scripts/setup_build_environment.sh"
alias setup_runtime_environment="source ${DBT_ROOT}/scripts/setup_runtime_environment.sh"
alias setup_python_venv="source ${DBT_ROOT}/scripts/setup_python_venv.sh"
echo -e "${COL_GREEN}DBT setuptools loaded${COL_NULL}"


