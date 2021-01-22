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
INIT=/Shared/pinc/sharedopt/apps/inc/${KERNEL}/${HARDWARE}/${VERSION}/init.json
if [[ -f ${INIT} ]]; then
  echo "file not found: ${INIT}"
  exit 1
fi

# load Argon modules -----------------------------------------------------------
if [[ "${HOSTNAME}" == "argon" ]]; then
  echo "LOADING MODULES:"
  MODS=($(jq -r '.argon_modules | keys_unsorted' < ${INIT} | tr -d ' [],"'))
  for (( i=0; i<${#MODS[@]}; i++ )); do
    VRS=($(jq -r ".argon_modules.${MODS[${i}]}" < ${INIT} | tr -d ' [],"'))
    module load ${MODS[${i}]}/${VRS}
    echo -e "\t ${MODS[${i}]}/${VRS}"
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
  VRS=($(jq -r ".software_dependencies.${SRC[${i}]}.version" < ${INIT} | tr -d ' [],"'))
  source ${DIR_PINC}/sourcefiles/${SRC[${i}]}_source.sh ${VRS}
  CMD=($(jq -r ".software_dependencies.${SRC[${i}]}.commands" < ${INIT} | tr -d ' [],"'))
  for (( j=0; j<${#CMD[@]}; j++ )); do
    if [[ "${CMD}" != "null" ]]; then
      eval ${CMD[${j}]}
    fi
  done
  echo -e "\t${SRC[${i}]^^}/${VRS}"
done

# set up aliases ---------------------------------------------------------------
echo "SETTING SHORTCUTS:"
AKA=($(jq -r '.software_aliases | keys' < ${INIT} | tr -d ' [],"'))
for (( i=0; i<${#AKA[@]}; i++ )); do
  unset VARS VALS
  VARS=($(jq -r ".software_aliases.${AKA[${i}]} | keys_unsorted" < ${INIT} | tr -d ' [],"'))
  for (( j=0; j<${#VARS[@]}; j++ )); do
    VALS+=($(jq -r ".software_aliases.${AKA[${i}]}.${VARS[${j}]}" < ${INIT} | tr -d ' [],"'))
  done
  AKA_STR=($(IFS=/ ; echo "${VALS[*]}"))
  eval "${AKA[${i}]}=${AKA_STR}"
  echo -e "\t${AKA[${i}]}=${AKA_STR}"
done

# setup R packages -------------------------------------------------------------
# run manually for now
#Rscript /Shared/pinc/sharedopt/apps/inc/${KERNEL}/${HARDWARE}/${INC_VERSION}/r_setup.R
echo "INC CODE version ${INC_VERSION} has been setup."
echo "If you haven't setup your R environment, please run:"
echo "Rscript /Shared/pinc/sharedopt/apps/inc/${KERNEL}/${HARDWARE}/${INC_VERSION}/r_setup.R"

