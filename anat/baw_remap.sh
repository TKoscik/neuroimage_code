#!/bin/bash -e

#===============================================================================
# This function remaps the output brain labels from BRAINSAutoworkup and makes 
# a set of new labels that include the original labels and summaries of
# hierarchically larger regions. The output is in a format where the
# summarize_3d function can summarize the variables and apply subregion masks
# e.g., hemisphere and tissue class, as needed.
# Authors: Timothy R. Koscik, PhD
# Date: 2020-03-19
#===============================================================================
PROC_START=$(date +%Y-%m-%dT%H:%M:%S%z)
FCN_NAME=(`basename "$0"`)
DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
OPERATOR=$(whoami)
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
  if [[ "${DEBUG}" == "false" ]]; then
    if [[ -d ${DIR_SCRATCH} ]]; then
      if [[ "$(ls -A ${DIR_SCRATCH})" ]]; then
        rm -R ${DIR_SCRATCH}/*
      fi
      rmdir ${DIR_SCRATCH}
    fi
  fi
}
trap egress EXIT

# Parse inputs -----------------------------------------------------------------
OPTS=`getopt -o hvlbw --long group:,prefix:,\
baw-label:,which-label:,\
dir-save:,dir-scratch:,dir-code:,dir-pincsource:,\
help,verbose,no-log -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
GROUP=
PREFIX=
BAW_LABEL=
WHICH_LABEL=renum
DIR_SAVE=
DIR_SCRATCH=/Shared/inc_scratch/${OPERATOR}_${DATE_SUFFIX}
DIR_CODE=/Shared/inc_scratch/code
DIR_PINCSOURCE=/Shared/pinc/sharedopt/apps/sourcefiles
HELP=false
VERBOSE=0

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    -b | --baw-label) BAW_LABEL="$2" ; shift 2 ;;
    -w | --which-label) BAW_LABEL="$2" ; shift 2 ;;
    --group) GROUP="$2" ; shift 2 ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --dir-save) DIR_SAVE="$2" ; shift 2 ;;
    --dir-scratch) DIR_SCRATCH="$2" ; shift 2 ;;
    --dir-code) DIR_CODE="$2" ; shift 2 ;;
    --dir-pincsource) DIR_PINCSOURCE="$2" ; shift 2 ;;
    -- ) shift ; break ;;
    * ) break ;;
  esac
done

# Usage Help -------------------------------------------------------------------
if [[ "${HELP}" == "true" ]]; then
  FUNC_NAME=(`basename "$0"`)
  echo ''
  echo '------------------------------------------------------------------------'
  echo "Iowa Neuroimage Processing Core: ${FUNC_NAME}"
  echo 'Author: <<author names>>'
  echo 'Date:   <<date of authorship>>'
  echo '------------------------------------------------------------------------'
  echo "Usage: ${FUNC_NAME}"
  echo '  -h | --help              display command help'
  echo '  -v | --verbose           add verbose output to log file'
  echo '  -l | --no-log            disable writing to output log'
  echo '  -b | --baw-label         full file path to Brainstools/BRAINSAutoworkup'
  echo '                           labels (dust cleaned version, renamed to fit'
  echo '                           in BIDS IA format and to work with our'
  echo '                           summarize_3d function)'
  echo '  =w | --which-label       which remapping to do, e.g., renumbering for'
  echo '                           generating label sumamries'
  echo '  --group <value>          group permissions for project,'
  echo '                           e.g., Research-kosciklab'
  echo '  --prefix <value>         scan prefix,'
  echo '                           default: sub-123_ses-1234abcd'
  echo '  --dir-save <value>       directory to save output, default varies by function'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo '  --dir-code <value>       directory where INC tools are stored,'
  echo '                           default: ${DIR_CODE}'
  echo '  --dir-pincsource <value> directory for PINC sourcefiles'
  echo '                           default: ${DIR_PINCSOURCE}'
  echo ''
  NO_LOG=true
  exit 0
fi

# Set up BIDs compliant variables and workspace --------------------------------
echo 1
DIR_PROJECT=`${DIR_CODE}/bids/get_dir.sh -i ${BAW_LABEL}`
SUBJECT=`${DIR_CODE}/bids/get_field.sh -i ${BAW_LABEL} -f "sub"`
SESSION=`${DIR_CODE}/bids/get_field.sh -i ${BAW_LABEL} -f "ses"`
if [ -z "${PREFIX}" ]; then
  PREFIX=sub-${SUBJECT}_ses-${SESSION}
fi

echo 2
mkdir -p ${DIR_SCRATCH}
echo 3
#===============================================================================
# Start of Function
#===============================================================================
if [[ "${WHICH_LABEL,,}" == "icv" ]]; then
  WHICH_COL=1
elif  [[ "${WHICH_LABEL,,}" == "lobes" ]]; then
  WHICH_COL=2
elif  [[ "${WHICH_LABEL,,}" == "basalGanglia" ]]; then
  WHICH_COL=3
elif  [[ "${WHICH_LABEL,,}" == "subcortical" ]]; then
  WHICH_COL=4
elif  [[ "${WHICH_LABEL,,}" == "midline" ]]; then
  WHICH_COL=5
elif  [[ "${WHICH_LABEL,,}" == "cerebralCortex" ]]; then
  WHICH_COL=6
elif  [[ "${WHICH_LABEL,,}" == "nonbrain" ]]; then
  WHICH_COL=7
elif  [[ "${WHICH_LABEL,,}" == "hemi" ]]; then
  WHICH_COL=8
elif  [[ "${WHICH_LABEL,,}" == "tissue" ]]; then
  WHICH_COL=9
elif  [[ "${WHICH_LABEL,,}" == "renum" ]]; then
  WHICH_COL=10
else
  echo "Invalid label set, options include:"
  echo "   icv, crb, lobes, basalGanglia, subcortical, midline, cerebralCortex, nonbrain, hemi, tissue, renum"
  exit 1
fi

if [ -z "${DIR_SAVE}" ]; then
  DIR_SAVE=${DIR_PROJECT}/derivatives/anat/label/baw+${WHICH_LABEL}
fi
mkdir -p ${DIR_SAVE}

# load lookup table
LUT_TSV=${DIR_CODE}/lut/lut-baw+remap.tsv
while IFS=$'\t\r' read -r -a temp; do
  VALUE_ORIG+=(${temp[0]})
  VALUE_NEW+=(${temp[${WHICH_COL}]})
done < ${LUT_TSV}
N=${#VALUE_BAW[@]}

# initialize empty files
fslmaths ${BAW_LABEL} -mul 0 ${DIR_SCRATCH}/${PREFIX}_label-baw+${WHICH_LABEL}.nii.gz

for (( i=1; i<${N}; i++ )); do
  fslmaths ${BAW_LABEL} -thr ${VALUE_ORIG[${i}]} -uthr ${VALUE_ORIG[${i}]} -bin ${DIR_SCRATCH}/roi_temp.nii.gz
  if [[ "${VALUE_NEW[${i}]}" != "0" ]]; then
    fslmaths ${DIR_SCRATCH}/roi_temp.nii.gz \
      -mul ${VALUE_NEW[${i}]} \
      -add ${DIR_SCRATCH}/${PREFIX}_label-baw+icv.nii.gz \
      ${DIR_SCRATCH}/${PREFIX}_label-baw+${WHICH_LABEL}.nii.gz
  fi
  rm ${DIR_SCRATCH}/roi_temp.nii.gz
done

mv ${DIR_SCRATCH}/${PREFIX}_label-baw+${WHICH_LABEL}.nii.gz ${DIR_SAVE}/

#===============================================================================
# End of Function
#===============================================================================
exit 0

