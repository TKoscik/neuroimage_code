#!/bin/bash -e

#===============================================================================
# Function Description
# Authors: <<author names>>
# Date: <<date>>
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
OPTS=`getopt -o hvl --long group:,prefix:,\
dir-dwi:,xfms:,ref-image:,\
dir-code:,dir-pincsource:,\
help,verbose,no-log -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
GROUP=
PREFIX=
DIR_DWI=
XFMS=
REF_IMAGE=
DIR_CODE=/Shared/inc_scratch/code
DIR_TEMPLATE=/Shared/nopoulos/nimg_core/templates_human
DIR_PINCSOURCE=/Shared/pinc/sharedopt/apps/sourcefiles
HELP=false
VERBOSE=0

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --group) GROUP="$2" ; shift 2 ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --dir-dwi) DIR_DWI="$2" ; shift 2 ;;
    --xfms) XFMS="$2" ; shift 2 ;;
    --ref-image) REF_IMAGE="$2" ; shift 2 ;;
    --dir-code) DIR_CODE="$2" ; shift 2 ;;
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
  echo '  --other-inputs <value>   other inputs necessary for function'
  echo '  --template <value>       name of template to use (if necessary),'
  echo '                           e.g., HCPICBM'
  echo '  --space <value>          spacing of template to use, e.g., 1mm'
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
anyfile=`ls ${DIR_DWI}sub-*.nii.gz`
SUBJECT=`${DIR_CODE}/bids/get_field.sh -i ${anyfile[0]} -f "sub"`
SESSION=`${DIR_CODE}/bids/get_field.sh -i ${anyfile[0]} -f "ses"`
if [ -z "${PREFIX}" ]; then
  PREFIX=sub-${SUBJECT}_ses-${SESSION}
fi

#===============================================================================
# Start of Function
#===============================================================================
XFM_LIST=(${XFMS//,/ })
N_XFM=${#XFM[@]}
SPACE=`${DIR_CODE}/bids/get_field.sh -i ${XFM_LIST[0]} -f to`

xfm_fcn="antsApplyTransforms -d 3 -e 3"
xfm_fcn="${xfm_fcn} -i ${DIR_DWI}/${PREFIX}_dwi+corrected.nii.gz"
xfm_fcn="${xfm_fcn} -o ${DIR_DWI}/${PREFIX}_reg-${SPACE}_dwi.nii.gz"
for (( i=0; i<${N_XFM}; i++ )); do
  xfm_fcn="${xfm_fcn} -t ${XFM_LIST[${i}]}"
done
xfm_fcn="${xfm_fcn} -r ${REF_IMAGE}"
eval ${xfm_fcn}

#===============================================================================
# End of Function
#===============================================================================
# Exit function ---------------------------------------------------------------
exit 0

