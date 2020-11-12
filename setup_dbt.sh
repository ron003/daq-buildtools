HERE=$(cd $(dirname $(readlink -f ${BASH_SOURCE})) && pwd)

export DBT_ROOT=${HERE}

# Import add_many_paths function
source ${HERE}/scripts/setup_tools.sh

add_many_paths PATH ${HERE}/bin ${HERE}/scripts

alias setup_build_environment="source ${DBT_ROOT}/scripts/setup_build_environment.sh"
alias setup_runtime_environment="source ${DBT_ROOT}/scripts/setup_runtime_environment.sh"
alias setup_python_venv="source ${DBT_ROOT}/scripts/setup_python_venv.sh"
echo -e "${COL_GREEN}DBT setuptools loaded${COL_NULL}"

export PATH

