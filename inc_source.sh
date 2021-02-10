#!/bin/bash -e

function egress {
  EXIT_CODE=$?
  if [[ ${EXIT_CODE} -ne 0 ]]; then
    "ERROR [INC Setup]: INPC software was not setup properly."
  fi
}
trap egress EXIT

# Set system variables ---------------------------------------------------------
HOSTNAME="$(uname -n)"
HOSTNAME=(${HOSTNAME//-/ })
HOSTNAME=${HOSTNAME[0],,}
KERNEL="$(uname -s)"
HARDWARE="$(uname -m)"

# set version number for INC code ----------------------------------------------
INC_VERSION="$1"
if [[ -z ${INC_VERSION} ]]; then
  INC_VERSION="dev"
fi

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
echo "Setting up Iowa Neuroimage Processing Core Software - Version ${INC_VERSION^^}"
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
echo "EXPORTING VARIABLES:"
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
  echo -e "\t${VAR_NAME[${i}]}=${VAR_VAL}"
done

# set function aliases ---------------------------------------------------------
echo "EXPORTING PATHS:"
FCN_PATHS=($(jq -r '.export_paths' < ${INIT} | tr -d ' [],"'))
for (( i=0; i<${#FCN_PATHS[@]}; i++ )); do
  export PATH=${PATH}:${DIR_INC}/${FCN_PATHS[${i}]}
  echo -e "\t${DIR_INC}/${FCN_PATHS[${i}]}"
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
echo "INC CODE version ${INC_VERSION^^} has been setup."
echo "If you haven't setup your R environment, please run:"
echo "Rscript ${DIR_INC}/R/r_setup.R"

