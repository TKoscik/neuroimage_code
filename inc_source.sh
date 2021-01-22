#!/bin/bash

# Set system variables ---------------------------------------------------------
HOSTNAME="$(uname -n)"
HOSTNAME=(${HOSTNAME//-/ })
HOSTNAME=${HOSTNAME[0],,}
KERNEL="$(unname -s)"
HARDWARE="$(uname -m)"

# set version number for INC code ----------------------------------------------
INC_VERSION="$1"
if [[ -z ${INC_VERSION} ]]; then
  INC_VERSION="0.0.0.0"
fi
echo "Setting up Iowa Neuroimage Processing Core Software version ${INC_VERSION}"

# locate init.json -------------------------------------------------------------
#DIR_INIT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
INIT=/Shared/pinc/sharedopt/apps/inc/${KERNEL}/${HARDWARE}/${INC_VERSION}/init.json
if [[ -f ${INIT} ]]; then
  echo "file not found: ${INIT}"
  exit 1
fi

# load Argon modules -----------------------------------------------------------
if [[ "${HOSTNAME}" == "argon" ]]; then
  echo "LOADING MODULES:"
  MODS=($(jq -r '.argon_modules | keys_unsorted' < ${INIT} | tr -d ' [],"'))
  for (( i=0; i<${#MODS[@]}; i++ )); do
    VERSION=($(jq -r ".argon_modules.${MODS[${i}]}" < ${INIT} | tr -d ' [],"'))
    module load ${MODS[${i}]}/${VERSION}
    echo -e "\t ${MODS[${i}]}/${VERSION}"
  done 
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
SRC=($(jq -r '.software_dependencies | keys_unsorted' < ${INIT} | tr -d ' [],"'))
for (( i=0; i<${#SRC[@]}; i++ )); do
  VERSION=($(jq -r ".software_dependencies.${SRC[${i}]}" < ${INIT} | tr -d ' [],"'))
  source ${DIR_PINC}/sourcefiles/${SRC[${i}]}_source.sh ${VERSION}
  echo -e "\t${SRC[${i}]^^}/${VERSION}"
done

# set up aliases ---------------------------------------------------------------
## *** not sure if this will work?
if [[ "${HOSTNAME}" != "argon" ]]; then
  echo "SETTING ALIASES:"
  AKA=($(jq -r '.software_aliases | keys' < ${INIT} | tr -d ' [],"'))
  for (( i=0; i<${#AKA[@]}; i++ )); do
    unset VARS VALS
    VARS=($(jq -r ".software_aliases.${AKA[${i}]} | keys_unsorted" < ${INIT} | tr -d ' [],"'))
    for (( j=0; j<${#VARS[@]}; j++ )); do
      VALS+=($(jq -r ".software_aliases.${AKA[${i}]}.${VARS[${j}]}" < ${INIT} | tr -d ' [],"'))
    done
    AKA_STR=($(IFS=/ ; echo "${VALS[*]}"))
    alias ${AKA[${i}]}=${AKA_STR}
    echo -e "\t${AKA[${i}]}=${AKA_STR}"
  done
fi

# setup R packages -------------------------------------------------------------
# run manually for now
#Rscript /Shared/pinc/sharedopt/apps/inc/${KERNEL}/${HARDWARE}/${INC_VERSION}/r_setup.R
echo "INC CODE version ${INC_VERSION} has been setup."
echo "If you haven't setup your R environment, please run:"
echo "Rscript /Shared/pinc/sharedopt/apps/inc/${KERNEL}/${HARDWARE}/${INC_VERSION}/r_setup.R"

