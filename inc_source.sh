#!/bin/bash

# Set system variables ---------------------------------------------------------
HOSTNAME="$(uname -n)"
HOSTNAME=(${HOSTNAME//-/ })
HOSTNAME=${HOSTNAME[0],,}
KERNEL="$(unname -s)"
HARDWARE="$(uname -m)"

# set version number for INC code ----------------------------------------------
INC_VERSION="$1"
if [[ -z ${INPUT_VERSION} ]]; then
  INC_VERSION="0.0.0.0"
fi

# load json reader if on argon -------------------------------------------------
if [[ "${HOSTNAME}" == "argon" ]]; then
  module load stack/2020.2 jq/1.6_gcc-8.4.0
fi

# locate init.json -------------------------------------------------------------
INIT=/Shared/pinc/sharedopt/apps/inc/${KERNEL}/${HARDWARE}/${INC_VERSION}/init.json
if [[ -f ${INIT} ]]; then
  echo "file not found: ${INIT}"
  exit 1
fi

# export directories -----------------------------------------------------------
PATHS=$(jq -c '.export_paths' ${INIT})
PATHS=${PATHS:1:-1}
PATHS=(${PATHS//,/ })
for (( i=0; i<${#PATHS[@]}; i++ )); do
  TEMP=${PATHS[${i}]}
  TEMP=${TEMP//\"}
  TEMP=(${TEMP//:/ })
  export ${TEMP[0]}=${TEMP[1]}
done

# load Argon modules -----------------------------------------------------------
if [[ "${HOSTNAME}" == "argon" ]]; then
  MODS=$(jq -c '.argon_modules' ${INIT})
  MODS=${MODS:1:-1}
  MODS=${MODS//\"}
  MODS=${MODS//://}
  MODS=${MODS//,/ }
  module load ${MODS}
fi

# run source files for software dependencies -----------------------------------
SRC=$(jq -c '.software_dependencies' ${INIT})
SRC=${SRC:1:-1}
SRC=(${SRC//,/ })
for (( i=0; i<${#SRC[@]}; i++ )); do
  TEMP=${SRC[${i}]}
  TEMP=${TEMP//\"}
  TEMP=(${TEMP//:/ })
  source /Shared/pinc/sharedopt/apps/sourcefiles/${TEMP[0]}_source.sh ${TEMP[1]}
done

# set up aliases ---------------------------------------------------------------
## *** not sure if this will work?
if [[ "${HOSTNAME}" != "argon" ]]; then
  AKA=$(jq -c '.aliases' ${INIT})
  AKA=${AKA:1:-1}
  AKA(${AKA//, })
  for (( i=0; i<${#AKA[@]}; i++ )); do
    TEMP=${AKA[${i}]}
    TEMP=${TEMP//\"}
    TEMP=(${TEMP//:/ })
    alias ${TEMP[0]}=${TEMP[1]}
  done
fi

# setup R packages -------------------------------------------------------------
# run manually for now
#Rscript /Shared/pinc/sharedopt/apps/inc/${KERNEL}/${HARDWARE}/${INC_VERSION}/r_setup.R



