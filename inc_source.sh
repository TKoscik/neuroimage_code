#!/bin/bash

# Set system variables ---------------------------------------------------------
HOSTNAME="$(uname -n)"
HOSTNAME=(${HOSTNAME//-/ })
HOSTNAME=${HOSTNAME[0],,}
KERNEL="$(unname -s)"
HARDWARE="$(uname -m)"

# set version number for INC code ----------------------------------------------
VERSION="$1"
if [[ -z ${VERSION} ]]; then
  VERSION="0.0.0.0"
fi
echo "Setting up Iowa Neuroimage Processing Core Software version ${VERSION}"

# locate init.json -------------------------------------------------------------
#DIR_INIT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
#INIT=/Shared/pinc/sharedopt/apps/inc/${KERNEL}/${HARDWARE}/${VERSION}/init.json
INIT=/Shared/inc_scratch/dev_code/init.json
if [[ -f ${INIT} ]]; then
  echo "file not found: ${INIT}"
  exit 1
fi

# load JQ to read init info from JSON ------------------------------------------
if [[ ! -x "$(command -v jq)" ]]; then
  if [[ "${HOSTNAME}" == "argon" ]]; then
    module load stack/2020.2 jq/1.6_gcc-8.4.0
  fi
  if [[ ! -x "$(command -v jq)" ]]; then
    echo "ERROR [INC setup]: Cannot read from init.json, jq could not be found or is not executable"
    exit 1
  fi
fi

# export directories -----------------------------------------------------------
echo "EXPORTING DIRECTORIES:"
PATH_VARS=($(jq -r '.export_paths | keys_unsorted' < ${INIT} | tr -d ' [],"'))
for (( i=0; i<${#PATHS[@]}; i++ )); do
  PATH_STR=($(jq -r ".export_paths.${PATH_VARS[${i}]}" < ${INIT} | tr -d ' [],"'))
  export ${PATH_VARS[${i}]}=${PATH_STR}
  echo -e "\t${PATH_VARS[${i}]}=${PATH_STR}"
done

# run source files for software dependencies -----------------------------------
echo "LOADING SOFTWARE DEPENDENCIES:"
SW_LS=($(jq -r '.software | keys_unsorted' < ${INIT} | tr -d ' [],"'))
for (( i=0; i<${#SW_LS[@]}; i++ )); do
  unset SW_NAME VERSION CMDS
  SW_NAME=${SW_LS[${i}]}
  WHICH_HOST=($(jq -r ".software.${SW_NAME}.hostname" < ${INIT} | tr -d ' [],"'))
  VERSION=($(jq -r ".software.${SW_NAME}.version" < ${INIT} | tr -d ' [],"'))
  CMDS=($(jq -r ".software.${SW_NAME}.command" < ${INIT} | tr -d ' [],"'))
  if [[ "${WHICH_HOST}" == "${HOSTNAME}" ]] |
     [[ "${WHICH_HOST}" == "all" ]]; then
    for (( j=0; j<${#CMDS[@]}; j++ )); do
      if [[ "${CMD}" != "null" ]]; then
        eval ${CMD[${j}]}
      fi
    done
  fi
  echo -e "\t${SW_NAME^^}/${VERSION}"
done

# setup R packages -------------------------------------------------------------
# run manually for now
#Rscript /Shared/pinc/sharedopt/apps/inc/${KERNEL}/${HARDWARE}/${INC_VERSION}/r_setup.R
echo "INC CODE version ${INC_VERSION} has been setup."
echo "If you haven't setup your R environment, please run:"
echo "Rscript /Shared/pinc/sharedopt/apps/inc/${KERNEL}/${HARDWARE}/${INC_VERSION}/r_setup.R"

