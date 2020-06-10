#!/bin/bash -e

#===============================================================================
# Creates basic fibertracking for dwi images using DSIStudio
# See here for more informatino on DSIStudio command line prompts that can used
#http://dsi-studio.labsolver.org/Manual/command-line-for-dsi-studio
# Authors: Josh Cochran
# Date: 6/10/2020
#===============================================================================
PROC_START=$(date +%Y-%m-%dT%H:%M:%S%z)
FCN_NAME=(`basename "$0"`)
DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
OPERATOR=$(whoami)
DEBUG=false
NO_LOG=false

# actions on exit, write to logs, clean scratch
function egress {
  EXIT_CODE=$?
  if [[ "${DEBUG}" == "false" ]]; then
    if [[ -d ${DIR_SCRATCH} ]]; then
      if [[ "$(ls -A ${DIR_SCRATCH})" ]]; then
        rm -R ${DIR_SCRATCH}/*
      fi
      rmdir ${DIR_SCRATCH}
    fi
  fi
  LOG_STRING=`date +"${OPERATOR}\t${FCN_NAME}\t${PROC_START}\t%Y-%m-%dT%H:%M:%S%z\t${EXIT_CODE}"`
  if [[ "${NO_LOG}" == "false" ]]; then
    FCN_LOG=/Shared/inc_scratch/log/benchmark_${FCN_NAME}.log
    if [[ ! -f ${FCN_LOG} ]]; then
      echo -e 'operator\tfunction\tstart\tend\texit_status' > ${FCN_LOG}
    fi
    echo -e ${LOG_STRING} >> ${FCN_LOG}
    if [[ -v DIR_PROJECT ]]; then
      PROJECT_LOG=${DIR_PROJECT}/log/${PREFIX}.log
      if [[ ! -f ${PROJECT_LOG} ]]; then
        echo -e 'operator\tfunction\tstart\tend\texit_status' > ${PROJECT_LOG}
      fi
      echo -e ${LOG_STRING} >> ${PROJECT_LOG}
    fi
  fi
}
trap egress EXIT

# Parse inputs -----------------------------------------------------------------
OPTS=`getopt -o hdcvkl --long group:,prefix:,\
bvec:,bval:,dwi-file:,brain-mask:,dsi-studio:,\
dir-save:,dir-scratch:,dir-code:,dir-template:,dir-pincsource:,\
help,debug,dry-run,verbose,keep,no-log -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
GROUP=
PREFIX=
BVEC=
BVAL=
DWI_FILE=
BRAIN_MASK=
DSI_STUDIO=/Shared/pinc/sharedopt/apps/DSI_Studio/Linux/x86_64/20200122/dsi_studio
DIR_SAVE=
DIR_SCRATCH=/Shared/inc_scratch/${OPERATOR}_${DATE_SUFFIX}
DIR_CODE=/Shared/inc_scratch/code
DIR_TEMPLATE=/Shared/nopoulos/nimg_core/templates_human
DIR_PINCSOURCE=/Shared/pinc/sharedopt/apps/sourcefiles
HELP=false
DRY_RUN=false
VERBOSE=0
KEEP=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -d | --debug) DEBUG=true ; shift ;;
    -c | --dry-run) DRY-RUN=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -k | --keep) KEEP=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --group) GROUP="$2" ; shift 2 ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --bvec) BVEC="$2" ; shift 2 ;;
    --bval) BVAL="$2" ; shift 2 ;;
    --dwi-file) DWI_FILE="$2" ; shift 2 ;;
    --brain-mask) BRAIN_MASK="$2" ; shift 2 ;;
    --dsi-studio) DSI_STUDIO="$2" ; shift 2 ;;
    --dir-save) DIR_SAVE="$2" ; shift 2 ;;
    --dir-scratch) DIR_SCRATCH="$2" ; shift 2 ;;
    --dir-code) DIR_CODE="$2" ; shift 2 ;;
    --dir-template) DIR_TEMPLATE="$2" ; shift 2 ;;
    --dir-pincsource) DIR_PINCSOURCE="$2" ; shift 2 ;;
    -- ) shift ; break ;;
    * ) break ;;
  esac
done

# Usage Help -------------------------------------------------------------------
if [[ "${HELP}" == "true" ]]; then
  echo ''
  echo '------------------------------------------------------------------------'
  echo "Iowa Neuroimage Processing Core: ${FCN_NAME}"
  echo '------------------------------------------------------------------------'
  echo "Usage: ${FCN_NAME}"
  echo '  -h | --help              display command help'
  echo '  -d | --debug             keep scratch folder for debugging'
  echo '  -c | --dry-run           test run of function'
  echo '  -v | --verbose           add verbose output to log file'
  echo '  -k | --keep              keep preliminary processing steps'
  echo '  -l | --no-log            disable writing to output log'
  echo '  --group <value>          group permissions for project,'
  echo '                           e.g., Research-kosciklab'
  echo '  --prefix <value>         scan prefix,'
  echo '                           default: sub-123_ses-1234abcd'
  echo '  --bvec <value>           bvec file'
  echo '  --bval <value>           bval file'
  echo '  --dwi-file <value>       corrected dwi file'
  echo '  --brain-mask <value>     brain mask for dwi image'
  echo '  --dsi-studio <value>     DSIStudio path, preset to version 20200122'
  echo '  --dir-save <value>       directory to save output, default varies by function'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo '  --dir-code <value>       directory where INC tools are stored,'
  echo '                           default: ${DIR_CODE}'
  echo '  --dir-template <value>   directory where INC templates are stored,'
  echo '                           default: ${DIR_TEMPLATE}'
  echo '  --dir-pincsource <value> directory for PINC sourcefiles'
  echo '                           default: ${DIR_PINCSOURCE}'
  echo ''
  NO_LOG=true
  exit 0
fi

# Set up BIDs compliant variables and workspace --------------------------------
DIR_PROJECT=`${DIR_CODE}/bids/get_dir.sh -i ${DWI_FILE}`
SUBJECT=`${DIR_CODE}/bids/get_field.sh -i ${DWI_FILE} -f "sub"`
SESSION=`${DIR_CODE}/bids/get_field.sh -i ${DWI_FILE} -f "ses"`
if [ -z "${PREFIX}" ]; then
  PREFIX=`${DIR_CODE}/bids/get_bidsbase.sh -s -i ${IMAGE}`
fi

if [ -z "${DIR_SAVE}" ]; then
  DIR_SAVE=${DIR_PROJECT}/derivatives/dwi/tractography/sub-${SUBJECT}/ses-${SESSION}
fi
mkdir -p ${DIR_SCRATCH}
mkdir -p ${DIR_SAVE}

#===============================================================================
# Start of Function
#===============================================================================

#Create the src file
${DSI_STUDIO} --action=src \
--source=${DWI_FILE} \
--bvec=${BVEC} \
--bval=${BVAL} \
--output=${DIR_SCRATCH}/${PREFIX}.src.gz

#QC src file
${DSI_STUDIO} --action=qc \
--source=${DIR_SCRATCH}

#Image reconstruction
${DSI_STUDIO} --action=rec \
--source=${DIR_SCRATCH}/${PREFIX}.src.gz \
--method=1 \
--mask=${BRAIN_MASK}

FIB_FILE=(`ls ${DIR_SCRATCH}/${PREFIX}*fib.gz`)

#ALL INFO ON COMMAND PROMPTS FOR TRACKING CAN BE FOUND HERE
#http://dsi-studio.labsolver.org/Manual/command-line-for-dsi-studio

#Fiber tracking
${DSI_STUDIO} --action=trk \
--source=${FIB_FILE} \
--connectivity=HCP-MMP \
--output=${DIR_SCRATCH}/${PREFIX}_track.trk.gz

#Move files to save directory
mv ${FIB_FILE} ${DIR_SAVE}/${PREFIX}.fib.gz
mkdir -p ${DIR_PROJECT}/qc/src_reports
mv ${DIR_SCRATCH}/src_report.txt ${DIR_PROJECT}/qc/src_reports/${PREFIX}_src_report.txt
mv ${DIR_SCRATCH}/${PREFIX}_track* ${DIR_SAVE}
mv ${DIR_SCRATCH}/*mapping.gz ${DIR_SAVE}


#===============================================================================
# End of Function
#===============================================================================

# Clean workspace --------------------------------------------------------------
# edit directory for appropriate modality prep folder
if [[ "${KEEP}" == "true" ]]; then
  mkdir -p ${DIR_PROJECT}/derivatives/anat/prep/sub-${SUBJECT}/ses-${SESSION}
  mv ${DIR_SCRATCH}/* ${DIR_PROJECT}/derivatives/dwi/prep/sub-${SUBJECT}/ses-${SESSION}/
fi

# Exit function ---------------------------------------------------------------
exit 0

