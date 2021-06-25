#!/bin/bash -e

function egress {
  EXIT_CODE=$?
  if [[ ${EXIT_CODE} -ne 0 ]]; then
    "ERROR [INC Setup]: INPC software was not setup properly."
  fi
}
trap egress EXIT

# parse input options ---------------------------------------------------------
OPTS=$(getopt -o vrq --long version:,own-r,quiet -n 'parse-options' -- "$@")
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

## default parameters
INC_VERSION="dev"
OWN_R="false"
QUIET="false"

while true; do
  case "$1" in
    -v | --version) INC_VERSION="$2" ; shift 2 ;;
    -r | --own-r) OWN_R="true" ; shift ;;
    -q | --quiet) QUIET="true" ; shift ;;
    -- ) shift ; break ;;
    * ) break ;;
  esac
done

# Set system variables ---------------------------------------------------------
HOSTNAME="$(uname -n)"
HOSTNAME=(${HOSTNAME//-/ })
HOSTNAME=${HOSTNAME[0],,}
KERNEL="$(uname -s)"
HARDWARE="$(uname -m)"

# locate init.json -------------------------------------------------------------
if [[ "${INC_VERSION}" == "dev" ]]; then
  INIT=/Shared/inc_scratch/dev_code/init.json
else
  INIT=/Shared/pinc/sharedopt/apps/inc/${KERNEL}/${HARDWARE}/${INC_VERSION}/init.json
fi
if [[ ! -f ${INIT} ]]; then
  echo "file not found: ${INIT}"
  exit 1
fi
if [[ "${QUIET}" == "false" ]]; then
  echo "Setting up Iowa Neuroimage Processing Core Software - Version ${INC_VERSION^^}"
fi
export DIR_INC=$(dirname ${INIT})
if [[ "${QUIET}" == "false" ]]; then echo -e "\tDIR_INC=${DIR_INC}"; fi

# use correct stack version on HPC ---------------------------------------------
if [[ "${HOSTNAME}" == "argon" ]]; then
  module load stack/2021.1
fi

# load JQ to read init info from JSON ------------------------------------------
if [[ ! -x "$(command -v jq)" ]]; then
  if [[ "${QUIET}" == "false" ]]; then echo -e "\tloading jq for JSON files"; fi
  if [[ "${HOSTNAME}" == "argon" ]]; then
    module load jq/1.6_gcc-9.3.0
  elif [[ "${HOSTNAME}" == *"psychiatry.uiowa.edu"* ]]; then
    PATH=${PATH}:/Shared/pinc/sharedopt/apps/jq/Linux/x86_64/1.6
  fi
  if [[ ! -x "$(command -v jq)" ]]; then
    echo "ERROR [INC setup]: Cannot read from init.json, jq could not be found or is not executable"
    exit 1
  fi
fi

# export directories -----------------------------------------------------------
if [[ "${QUIET}" == "false" ]]; then echo "EXPORTING VARIABLES:"; fi
VAR_NAME=($(jq -r '.export_vars | keys_unsorted' < ${INIT} | tr -d ' [],"'))
for (( i=0; i<${#VAR_NAME[@]}; i++ )); do
  VAR_VAL=($(jq -r ".export_vars.${VAR_NAME[${i}]}" < ${INIT} | tr -d ' [],"'))
  if [[ "${VAR_VAL}" == *'${DIR_INC}'* ]]; then
    TVAL=$(basename ${VAR_VAL})
    export ${VAR_NAME[${i}]}=${DIR_INC}/${TVAL}
  elif [[ "${VAR_VAL}" == *'${INC_DB}'* ]]; then
    TVAL=$(basename ${VAR_VAL})
    export ${VAR_NAME[${i}]}=${INC_DB}/${TVAL}
  elif [[ "${VAR_VAL}" == *'${INC_SCRATCH}'* ]]; then
    TVAL=$(basename ${VAR_VAL})
    export ${VAR_NAME[${i}]}=${INC_SCRATCH}/${TVAL}
  else
    export ${VAR_NAME[${i}]}=${VAR_VAL}
  fi
  if [[ "${QUIET}" == "false" ]]; then echo -e "\t${VAR_NAME[${i}]}=${VAR_VAL}"; fi
done

# set function aliases ---------------------------------------------------------
if [[ "${QUIET}" == "false" ]]; then echo "EXPORTING PATHS:"; fi
FCN_PATHS=($(jq -r '.export_paths' < ${INIT} | tr -d ' [],"'))
for (( i=0; i<${#FCN_PATHS[@]}; i++ )); do
  export PATH=${PATH}:${DIR_INC}/${FCN_PATHS[${i}]}
  if [[ "${QUIET}" == "false" ]]; then echo -e "\t${DIR_INC}/${FCN_PATHS[${i}]}"; fi
done

# run source files for software dependencies -----------------------------------
if [[ "${QUIET}" == "false" ]]; then echo "LOADING SOFTWARE DEPENDENCIES:"; fi
SW_LS=($(jq -r '.software | keys_unsorted' < ${INIT} | tr -d ' [],"'))
for (( i=0; i<${#SW_LS[@]}; i++ )); do
  unset SW_NAME SW_VERSION CMD_LS
  SW_NAME=${SW_LS[${i}]}
  WHICH_HOST=($(jq -r ".software.${SW_NAME}.hostname" < ${INIT} | tr -d ' [],"'))
  SW_VERSION=($(jq -r ".software.${SW_NAME}.version" < ${INIT} | tr -d ' [],"'))
  if [[ "${QUIET}" == "false" ]]; then echo -e "\t${SW_NAME}/${SW_VERSION}"; fi
  CMD_LS=($(jq -r ".software.${SW_NAME}.command | keys_unsorted" < ${INIT} | tr -d ' [],"'))
  if [[ "${WHICH_HOST}" == "${HOSTNAME}" ]] || [[ "${WHICH_HOST}" == "all" ]]; then
    for (( j=0; j<${#CMD_LS[@]}; j++ )); do
      CMD=$(jq -r ".software.${SW_NAME}.command.${CMD_LS[${j}]}" < ${INIT} | tr -d '[],"')
      if [[ "${CMD}" != "null" ]]; then
        eval ${CMD}
      fi
    done
  fi
done

# setup R ----------------------------------------------------------------------
if [[ "${OWN_R}" == "false" ]] & [[ "${HOSTNAME,,}" == "argon" ]]; then
  if [[ "${QUIET}" == "false" ]]; then echo "LOADING R MODULES:"; fi
  PKG_LS=($(jq -r '.r_modules | keys_unsorted' < ${INIT} | tr -d ' [],"'))
  for (( i=0; i<${#PKG_LS[@]}; i++ )); do
    unset PKG_NAME PKG_VERSION
    PKG_NAME=${PKG_LS[${i}]}
    PKG_VERSION=($(jq -r ".r_modules.${PKG_NAME}" < ${INIT} | tr -d ' [],"'))
    CMD="module load ${PKG_NAME//_/-}/${PKG_VERSION}"
    eval ${CMD}
  done
fi

if [[ "${QUIET}" == "false" ]]; then echo "CHECKING R PACKAGES:"; fi
Rscript ${INC_R}/r_setup.R

echo "INC CODE version ${INC_VERSION^^} has been setup."


