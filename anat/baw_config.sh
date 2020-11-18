#!/bin/bash -e

#===============================================================================
# Write a Configuration File for BAW
# Authors: Josh Cochran
# Date: 10/19/2020
#===============================================================================
PROC_START=$(date +%Y-%m-%dT%H:%M:%S%z)
FCN_NAME=($(basename "$0"))
DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
OPERATOR=$(whoami)
KEEP=false
NO_LOG=false
umask 007

# actions on exit, write to logs, clean scratch
function egress {
  EXIT_CODE=$?
  if [[ "${KEEP}" == "false" ]]; then
    if [[ -n ${DIR_SCRATCH} ]]; then
      if [[ -d ${DIR_SCRATCH} ]]; then
        if [[ "$(ls -A ${DIR_SCRATCH})" ]]; then
          rm -R ${DIR_SCRATCH}
        else
          rmdir ${DIR_SCRATCH}
        fi
      fi
    fi
  fi
  LOG_STRING=$(date +"${OPERATOR}\t${FCN_NAME}\t${PROC_START}\t%Y-%m-%dT%H:%M:%S%z\t${EXIT_CODE}")
  if [[ "${NO_LOG}" == "false" ]]; then
    FCN_LOG=/Shared/inc_scratch/log/benchmark_${FCN_NAME}.log
    if [[ ! -f ${FCN_LOG} ]]; then
      echo -e 'operator\tfunction\tstart\tend\texit_status' > ${FCN_LOG}
    fi
    echo -e ${LOG_STRING} >> ${FCN_LOG}
    if [[ -v ${DIR_PROJECT} ]]; then
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
OPTS=`getopt -o h --long \
project-name:,csv-file:,queue:,\
dir-save:,\
help -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
PROJECT_NAME=
CSV_FILE=
DIR_SAVE=
QUEUE=
DIR_CODE=/Shared/inc_scratch/code
DIR_TEMPLATE=/Shared/nopoulos/nimg_core/templates_human
HELP=false


while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    --project-name) PROJECT_NAME="$2" ; shift 2 ;;
    --csv-file) CSV_FILE="$2" ; shift 2 ;;
    --queue) QUEUE="$2" ; shift 2 ;;
    --dir-save) DIR_SAVE="$2" ; shift 2 ;;
    -- ) shift ; break ;;
    * ) break ;;
  esac
done
### NOTE: DIR_CODE, DIR_PINCSOURCE may be deprecated and possibly replaced
#         by DIR_INC for version 0.0.0.0. Specifying the directory may
#         not be necessary, once things are sourced

# Usage Help -------------------------------------------------------------------
if [[ "${HELP}" == "true" ]]; then
  FCN_NAME=($(basename "$0"))
  echo ''
  echo '------------------------------------------------------------------------'
  echo "Iowa Neuroimage Processing Core: ${FCN_NAME}"
  echo '------------------------------------------------------------------------'
  echo "Usage: ${FCN_NAME}"
  echo '  -h | --help              display command help'
  echo '  --project-name <value>   project name'
  echo '  --csv-file <value>       csv file, full path'
  echo '  --queue <value>          ARGON queues to submit to'
  echo '  --dir-save <value>       directory to save output, default varies by function'
  echo '  --dir-inc <value>        directory where INC tools are stored,'
  echo '                           default: ${DIR_INC}'
  echo ''
  NO_LOG=true
  exit 0
fi

#===============================================================================
# Start of Function
#===============================================================================

# Set up BIDs compliant variables and workspace --------------------------------
DIR_PROJECT=$(${DIR_INC}/bids/get_dir.sh -i ${CSV_FILE})

CONFIG=${DIR_PROJECT}/code/${PROJECT_NAME}.config

echo '[EXPERIMENT]' >> ${CONFIG}
echo '' >> ${CONFIG}
echo 'SESSION_DB_BASE='${CSV_FILE} >> ${CONFIG}
echo 'SESSION_DB_TEMP=%(SESSION_DB_BASE)s' >> ${CONFIG}
echo 'SESSION_DB_LONG=%(SESSION_DB_BASE)s' >> ${CONFIG}
echo '' >> ${CONFIG}
echo '' >> ${CONFIG}
echo '' >> ${CONFIG}
echo 'EXPERIMENT_BASE='${PROJECT_NAME} >> ${CONFIG}
echo '#EXPERIMENT_TEMP=NOFL_20170302_DM1_temp' >> ${CONFIG}
echo '#EXPERIMENT_LONG=NOFL_20170302_DM1_long' >> ${CONFIG}
echo '' >> ${CONFIG}
echo '' >> ${CONFIG}
echo 'EXPERIMENT_TEMP_INPUT=%(EXPERIMENT_BASE)s' >> ${CONFIG}
echo 'EXPERIMENT_LONG_INPUT=%(EXPERIMENT_TEMP)s' >> ${CONFIG}
echo '' >> ${CONFIG}
echo '' >> ${CONFIG}
echo '#WORKFLOW_COMPONENTS_LONG=['\'denoise\'','\'landmark\'','\'auxlmk\'','\'tissue_classify\'','\'segmentation\'','\'warp_atlas_to_subject\'','\'jointfusion_2012_neuro\'']' >> ${CONFIG}
echo '' >> ${CONFIG}
echo '' >> ${CONFIG}
echo 'WORKFLOW_COMPONENTS_BASE=['\'denoise\'','\'landmark\'','\'auxlmk\'','\'tissue_classify\'','\'warp_atlas_to_subject\'','\'jointfusion_2015_wholebrain\'']' >> ${CONFIG}
echo '#WORKFLOW_COMPONENTS_BASE=['\'denoise\'']' >> ${CONFIG}
echo '#WORKFLOW_COMPONENTS_TEMP=[]' >> ${CONFIG}
echo '#WORKFLOW_COMPONENTS_LONG=['\'denoise\'','\'landmark\'','\'auxlmk\'','\'tissue_classify\'','\'warp_atlas_to_subject\'','\'jointfusion_2015_wholebrain\'']' >> ${CONFIG}
echo '' >> ${CONFIG}
echo '' >> ${CONFIG}
echo 'BASE_OUTPUT_DIR='${DIR_SAVE} >> ${CONFIG}
echo '' >> ${CONFIG}
echo '' >> ${CONFIG}
echo 'ATLAS_PATH=/Shared/pinc/sharedopt/ReferenceData/Atlas_20131115' >> ${CONFIG}
echo 'JOINTFUSION_ATLAS_DB_BASE=/Shared/pinc/sharedopt/ReferenceData/20160523_HDAdultAtlas/baw20160523WholeBrainAtlasDenoisedList_fixed.csv' >> ${CONFIG}
echo 'RELABEL2LOBES_FILENAME=/Shared/pinc/sharedopt/ReferenceData/20160523_HDAdultAtlas/Label2Lobes_Ver20160524.csv' >> ${CONFIG}
echo 'LABELMAP_COLORLOOKUP_TABLE=/Shared/pinc/sharedopt/ReferenceData/20160523_HDAdultAtlas/BAWHDAdultAtlas_FreeSurferConventionColorLUT_20160524.txt' >> ${CONFIG}
echo '' >> ${CONFIG}
echo '' >> ${CONFIG}
echo 'USE_REGISTRATION_MASKING=True' >> ${CONFIG}
echo '' >> ${CONFIG}
echo '' >> ${CONFIG}
echo '[NIPYPE]' >> ${CONFIG}
echo 'GLOBAL_DATA_SINK_REWRITE=True' >> ${CONFIG}
echo '#GLOBAL_DATA_SINK_REWRITE=False' >> ${CONFIG}
echo 'CRASHDUMP_DIR=/tmp' >> ${CONFIG}
echo '' >> ${CONFIG}
echo '' >> ${CONFIG}
echo '' >> ${CONFIG}
echo '##@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@' >> ${CONFIG}
echo '[RHEL7ARGON]' >> ${CONFIG}
echo '## The cluster queue to use for submitting "normal running" jobs.' >> ${CONFIG}
echo '#QUEUE= -q all.q' >> ${CONFIG}
echo 'QUEUE= -q '${QUEUE} >> ${CONFIG}
echo '' >> ${CONFIG}
echo '' >> ${CONFIG}
echo '' >> ${CONFIG}
echo '' >> ${CONFIG}
echo '## The cluster queue to use for submitting "long running" jobs.' >> ${CONFIG}
echo '#QUEUE_LONG= -q all.q' >> ${CONFIG}
echo 'QUEUE_LONG= -q '${QUEUE} >> ${CONFIG}
echo '' >> ${CONFIG}
echo '' >> ${CONFIG}
echo '' >> ${CONFIG}
echo '## The QSTAT command for immediate update of values [ use '\'qstat\'' if in doubt ]' >> ${CONFIG}
echo 'QSTAT_IMMEDIATE=qstat' >> ${CONFIG}
echo 'QSTAT_CACHED=qstat' >> ${CONFIG}
echo '## The QSTAT command for cached update of values ( to take load off of OGE server during heavy job usage ) [ use '\'qstat\'' if in doubt ]' >> ${CONFIG}
echo '# QSTAT_IMMEDIATE_EXE=/Shared/johnsonhj/HDNI/20160219_AutoWorkupTest/scripts/qstat_immediate.sh' >> ${CONFIG}
echo '# QSTAT_CACHED_EXE=/Shared/johnsonhj/HDNI/20160219_AutoWorkupTest/scripts/qstat_cached.sh' >> ${CONFIG}
echo '' >> ${CONFIG}
echo '' >> ${CONFIG}
echo '## Necessary modules to load for jobs' >> ${CONFIG}
echo 'MODULES=['\'intel/2017.1\'', '\'ncurses/6.0\'',  '\'cmake/3.7.2\'', '\'graphviz/2.40.1\'']' >> ${CONFIG}
echo '' >> ${CONFIG}
echo '' >> ${CONFIG}
echo '' >> ${CONFIG}
echo '# Run on a cluster?' >> ${CONFIG}
echo '_GRAPHVIZ_BIN=/opt/apps/graphviz/2.40.1/bin/dot' >> ${CONFIG}
echo 'VIRTUALENV_DIR=/Shared/pinc/sharedopt/apps/anaconda3/Linux/x86_64/4.3.0/bin' >> ${CONFIG}
echo '# NAMICExternalProjects build tree' >> ${CONFIG}
echo '_BUILD_DIR=/Shared/pinc/sharedopt/20170302/RHEL7/NEP-intel' >> ${CONFIG}
echo '_BRAINSTOOLS_BIN_DIR=%(_BUILD_DIR)s/bin' >> ${CONFIG}
echo '#_SIMPLEITK_PYTHON_LIB=%(_BUILD_DIR)s/lib' >> ${CONFIG}
echo '#_SIMPLEITK_PACKAGE_DIR=%(_BUILD_DIR)s/SimpleITK-build/Wrapping' >> ${CONFIG}
echo '#_NIPYPE_PACKAGE_DIR=' >> ${CONFIG}
echo '#%(_BUILD_DIR)s/NIPYPE' >> ${CONFIG}
echo '############## -- You should not need to modify below here. ###########' >> ${CONFIG}
echo 'APPEND_PYTHONPATH=%(_BUILD_DIR)s/BRAINSTools/AutoWorkup:%(_BUILD_DIR)s/BRAINSTools/AutoWorkup/workflows' >> ${CONFIG}
echo '#%(_NIPYPE_PACKAGE_DIR)s:%(_SIMPLEITK_PYTHON_LIB)s:%(_SIMPLEITK_PACKAGE_DIR)s' >> ${CONFIG}
echo 'APPEND_PATH=%(_BRAINSTOOLS_BIN_DIR)s:%(_GRAPHVIZ_BIN)s' >> ${CONFIG}
echo '#APPEND_PATH=%(_BRAINSTOOLS_BIN_DIR)s:%(_SIMPLEITK_PYTHON_LIB)s:%(_GRAPHVIZ_BIN)s' >> ${CONFIG}
echo '' >> ${CONFIG}
echo '##@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@' >> ${CONFIG}
echo '[RHEL7PINC]' >> ${CONFIG}
echo '## The cluster queue to use for submitting "normal running" jobs.' >> ${CONFIG}
echo '#QUEUE= -q all.q' >> ${CONFIG}
echo 'QUEUE= -q x64' >> ${CONFIG}
echo '' >> ${CONFIG}
echo '' >> ${CONFIG}
echo '## The cluster queue to use for submitting "long running" jobs.' >> ${CONFIG}
echo '#QUEUE_LONG= -q all.q' >> ${CONFIG}
echo 'QUEUE_LONG= -q x64' >> ${CONFIG}
echo '' >> ${CONFIG}
echo '' >> ${CONFIG}
echo '## The QSTAT command for immediate update of values [ use 'qstat' if in doubt ]' >> ${CONFIG}
echo 'QSTAT_IMMEDIATE=qstat' >> ${CONFIG}
echo 'QSTAT_CACHED=qstat' >> ${CONFIG}
echo '## The QSTAT command for cached update of values ( to take load off of OGE server during heavy job usage ) [ use 'qstat' if in doubt ]' >> ${CONFIG}
echo '# QSTAT_IMMEDIATE_EXE=/Shared/johnsonhj/HDNI/20160219_AutoWorkupTest/scripts/qstat_immediate.sh' >> ${CONFIG}
echo '# QSTAT_CACHED_EXE=/Shared/johnsonhj/HDNI/20160219_AutoWorkupTest/scripts/qstat_cached.sh' >> ${CONFIG}
echo '' >> ${CONFIG}
echo '' >> ${CONFIG}
echo '## Necessary modules to load for jobs' >> ${CONFIG}
echo 'MODULES=[]' >> ${CONFIG}
echo '' >> ${CONFIG}
echo '' >> ${CONFIG}
echo '# Run on a cluster?' >> ${CONFIG}
echo '_GRAPHVIZ_BIN=/opt/apps/graphviz/2.40.1/bin/dot' >> ${CONFIG}
echo 'VIRTUALENV_DIR=/Shared/pinc/sharedopt/apps/anaconda3/Linux/x86_64/4.3.0/bin' >> ${CONFIG}
echo '# NAMICExternalProjects build tree' >> ${CONFIG}
echo '_BUILD_DIR=/Shared/pinc/sharedopt/20170302/RHEL7/NEP-11' >> ${CONFIG}
echo '_BRAINSTOOLS_BIN_DIR=%(_BUILD_DIR)s/bin' >> ${CONFIG}
echo '#_SIMPLEITK_PYTHON_LIB=%(_BUILD_DIR)s/lib' >> ${CONFIG}
echo '#_SIMPLEITK_PACKAGE_DIR=%(_BUILD_DIR)s/SimpleITK-build/Wrapping' >> ${CONFIG}
echo '#_NIPYPE_PACKAGE_DIR=' >> ${CONFIG}
echo '#%(_BUILD_DIR)s/NIPYPE' >> ${CONFIG}
echo '############## -- You should not need to modify below here. ###########' >> ${CONFIG}
echo 'APPEND_PYTHONPATH=%(_BUILD_DIR)s/BRAINSTools/AutoWorkup:%(_BUILD_DIR)s/BRAINSTools/AutoWorkup/workflows' >> ${CONFIG}
echo '#%(_NIPYPE_PACKAGE_DIR)s:%(_SIMPLEITK_PYTHON_LIB)s:%(_SIMPLEITK_PACKAGE_DIR)s' >> ${CONFIG}
echo 'APPEND_PATH=%(_BRAINSTOOLS_BIN_DIR)s:%(_GRAPHVIZ_BIN)s' >> ${CONFIG}
echo '#APPEND_PATH=%(_BRAINSTOOLS_BIN_DIR)s:%(_SIMPLEITK_PYTHON_LIB)s:%(_GRAPHVIZ_BIN)s' >> ${CONFIG}
echo '' >> ${CONFIG}
echo '' >> ${CONFIG}
echo '##@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@' >> ${CONFIG}
echo '[OSX]' >> ${CONFIG}
echo '## The cluster queue to use for submitting "normal running" jobs.' >> ${CONFIG}
echo 'QUEUE=-q COE,UI,HJ,PINC' >> ${CONFIG}
echo '#QUEUE=-q ICTS,COE,UI' >> ${CONFIG}
echo '## The cluster queue to use for submitting "long running" jobs.' >> ${CONFIG}
echo 'QUEUE_LONG= -q COE,UI,HJ,PINC' >> ${CONFIG}
echo '#QUEUE_LONG= -q ICTS,COE,UI' >> ${CONFIG}
echo '## The QSTAT command for immediate update of values [ use '\'qstat\'' if in doubt ]' >> ${CONFIG}
echo 'QSTAT_IMMEDIATE=qstat' >> ${CONFIG}
echo 'QSTAT_CACHED=qstat' >> ${CONFIG}
echo '## The QSTAT command for cached update of values ( to take load off of OGE server during heavy job usage ) [ use '\'qstat\'' if in doubt ]' >> ${CONFIG}
echo '# QSTAT_IMMEDIATE_EXE=/Shared/johnsonhj/HDNI/20160219_AutoWorkupTest/scripts/qstat_immediate.sh' >> ${CONFIG}
echo '# QSTAT_CACHED_EXE=/Shared/johnsonhj/HDNI/20160219_AutoWorkupTest/scripts/qstat_cached.sh' >> ${CONFIG}
echo '' >> ${CONFIG}
echo '' >> ${CONFIG}
echo '## Necessary modules to load for jobs' >> ${CONFIG}
echo 'MODULES=[]' >> ${CONFIG}
echo '' >> ${CONFIG}
echo '# Run on a cluster?' >> ${CONFIG}
echo '_GRAPHVIZ_BIN=/usr/local/' >> ${CONFIG}
echo 'VIRTUALENV_DIR=/Shared/pinc/sharedopt/apps/anaconda3/Linux/x86_64/4.3.0/bin' >> ${CONFIG}
echo '' >> ${CONFIG}
echo '# NAMICExternalProjects build tree' >> ${CONFIG}
echo '_BUILD_DIR=/scratch/johnsonhj/src/NEP-intel' >> ${CONFIG}
echo '_BRAINSTOOLS_BIN_DIR=%(_BUILD_DIR)s/bin' >> ${CONFIG}
echo '_SIMPLEITK_PYTHON_LIB=%(_BUILD_DIR)s/lib' >> ${CONFIG}
echo '_SIMPLEITK_PACKAGE_DIR=%(_BUILD_DIR)s/SimpleITK-build/Wrapping' >> ${CONFIG}
echo '_NIPYPE_PACKAGE_DIR=%(_BUILD_DIR)s/NIPYPE' >> ${CONFIG}
echo '############## -- You should not need to modify below here. ###########' >> ${CONFIG}
echo 'APPEND_PYTHONPATH=%(_NIPYPE_PACKAGE_DIR)s:%(_SIMPLEITK_PYTHON_LIB)s:%(_SIMPLEITK_PACKAGE_DIR)s' >> ${CONFIG}
echo 'APPEND_PATH=%(_BRAINSTOOLS_BIN_DIR)s:%(_SIMPLEITK_PYTHON_LIB)s:%(_GRAPHVIZ_BIN)s' >> ${CONFIG}
echo '' >> ${CONFIG}
echo '' >> ${CONFIG}
echo '[DEFAULT]' >> ${CONFIG}
echo '# The prefix to add to all image files in the $(SESSION_DB) to account for different file system mount points' >> ${CONFIG}
echo 'MOUNT_PREFIX=' >> ${CONFIG}
echo 'MODULES=' >> ${CONFIG}
echo '' >> ${CONFIG}

#===============================================================================
# End of Function
#===============================================================================

exit 0

