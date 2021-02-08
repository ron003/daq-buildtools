#!/usr/bin/env bash # for the fish shell fans
set -o pipefail
set -o nounset
set +o errexit # we expect this file to be `source`d, prevent exiting user shell

#------------------------------------------------------------------------------
HERE=$(cd $(dirname $(readlink -f ${BASH_SOURCE})) && pwd)

export DBT_ROOT=${HERE}
# docker does not set these, UPS relies on them
export USER=${USER:-$(whoami)}
export HOSTNAME=${HOSTNAME:-$(hostname)}

# Import add_many_paths function
source ${DBT_ROOT}/scripts/dbt-setup-tools.sh
abort_if_not_sourced

add_many_paths PATH ${DBT_ROOT}/bin ${DBT_ROOT}/scripts
export PATH

alias dbt-setup-build-environment="source ${DBT_ROOT}/scripts/dbt-setup-build-environment.sh"
alias dbt-setup-runtime-environment="source ${DBT_ROOT}/scripts/dbt-setup-runtime-environment.sh"
echo -e "${COL_GREEN}DBT setuptools loaded${COL_NULL}"


