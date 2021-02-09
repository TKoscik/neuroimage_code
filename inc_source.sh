#!/bin/bash

# Set system variables ---------------------------------------------------------
HOSTNAME="$(uname -n)"
HOSTNAME=(${HOSTNAME//-/ })
HOSTNAME=${HOSTNAME[0],,}
KERNEL="$(uname -s)"
HARDWARE="$(uname -m)"

# set version number for INC code ----------------------------------------------
VERSION="$1"
if [[ -z ${VERSION} ]]; then
  VERSION="dev"
fi

# locate init.json -------------------------------------------------------------
if [[ "${VERSION}" == "dev" ]]; then
  INIT=/Shared/inc_scratch/dev_code/init.json
else
  INIT=/Shared/pinc/sharedopt/apps/inc/${KERNEL}/${HARDWARE}/${VERSION}/init.json
fi
if [[ ! -f ${INIT} ]]; then
  echo "file not found: ${INIT}"
  exit 1
fi
echo "Setting up Iowa Neuroimage Processing Core Software - Version ${VERSION^^}"
export DIR_INC=$(dirname ${INIT})

# load JQ to read init info from JSON ------------------------------------------
if [[ ! -x "$(command -v jq)" ]]; then
  if [[ "${HOSTNAME}" == "argon" ]]; then
    echo -e "\tloading JSON modules"
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
for (( i=0; i<${#PATH_VARS[@]}; i++ )); do
  PATH_STR=($(jq -r ".export_paths.${PATH_VARS[${i}]}" < ${INIT} | tr -d ' [],"'))
  export ${PATH_VARS[${i}]}=${PATH_STR}
  echo -e "\t${PATH_VARS[${i}]}=${PATH_STR}"
done

# set function aliases ---------------------------------------------------------
echo "SETTING FUNCTION ALIASES"
FCN_PATHS=($(jq -r '.function_alias' < ${INIT} | tr -d ' [],"'))
for (( i=0; i<${#FCN_PATHS[@]}; i++ )); do
  echo -e "\t${FCN_PATHS[${i}]}"
  FCN_LS=($(ls ${DIR_INC}/${FCN_PATHS[${i}]}/*))
  for (( j=0; j<${#FCN_LS[@]}; j++ )); do
    FCN_FILE=$(basename ${FCN_LS[${j}]})
    FCN_NAME=${FCN_FILE%%.*}
    FCN_EXT=${FCN_FILE##*.}
    if [[ "${FCN_EXT,,}" == "sh" ]]; then
      alias "${FCN_NAME}=${FCN_LS[${j}]}"
    else
      alias "${FCN_FILE}=${FCN_LS[${j}]}"
    fi
  done
done

# run source files for software dependencies -----------------------------------
echo "LOADING SOFTWARE DEPENDENCIES:"
SW_LS=($(jq -r '.software | keys_unsorted' < ${INIT} | tr -d ' [],"'))
for (( i=0; i<${#SW_LS[@]}; i++ )); do
  unset SW_NAME SW_VERSION CMD_LS
  SW_NAME=${SW_LS[${i}]}
  WHICH_HOST=($(jq -r ".software.${SW_NAME}.hostname" < ${INIT} | tr -d ' [],"'))
  SW_VERSION=($(jq -r ".software.${SW_NAME}.version" < ${INIT} | tr -d ' [],"'))
  CMD_LS=($(jq -r ".software.${SW_NAME}.command | keys_unsorted" < ${INIT} | tr -d ' [],"'))
  if [[ "${WHICH_HOST}" == "${HOSTNAME}" ]] || [[ "${WHICH_HOST}" == "all" ]]; then
    for (( j=0; j<${#CMD_LS[@]}; j++ )); do
      CMD=$(jq -r ".software.${SW_NAME}.command.${CMD_LS[${j}]}" < ${INIT} | tr -d '[],"')
      if [[ "${CMD}" != "null" ]]; then
        eval ${CMD}
      fi
    done
  fi
  echo -e "\t${SW_NAME^^}/${SW_VERSION}"
done

# setup R packages -------------------------------------------------------------
# run manually for now
#Rscript ${DIR_INC}/r_setup.R
echo "INC CODE version ${VERSION^^} has been setup."
echo "If you haven't setup your R environment, please run:"
echo "Rscript ${DIR_INC}/r_setup.R"

