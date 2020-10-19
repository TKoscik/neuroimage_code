#!/bin/bash -e

#===============================================================================
# Function Description
# Authors: <<author names>>
# Date: <<date>>
#===============================================================================
PROC_START=$(date +%Y-%m-%dT%H:%M:%S%z)
FCN_NAME=($(basename "$0"))
DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
OPERATOR=$(whoami)
KEEP=false
NO_LOG=false

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
OPTS=`getopt -o hvkl --long prefix:,\
base-name:,csv-file:,space:,\
dir-save:,dir-scratch:,\
help,verbose,keep,no-log -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
PREFIX=
BASE_NAME=
CSV_FILE=
DIR_SAVE=
DIR_SCRATCH=/Shared/inc_scratch/${OPERATOR}_${DATE_SUFFIX}
DIR_CODE=/Shared/inc_scratch/code
DIR_TEMPLATE=/Shared/nopoulos/nimg_core/templates_human
HELP=false
VERBOSE=0

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -k | --keep) KEEP=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --base-name) BASE_NAME="$2" ; shift 2 ;;
    --csv-file) CSV_FILE="$2" ; shift 2 ;;
    --space) SPACE="$2" ; shift 2 ;;
    --dir-save) DIR_SAVE="$2" ; shift 2 ;;
    --dir-scratch) DIR_SCRATCH="$2" ; shift 2 ;;
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
  echo '  -v | --verbose           add verbose output to log file'
  echo '  -k | --keep              keep preliminary processing steps'
  echo '  -l | --no-log            disable writing to output log'
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
  echo ''
  NO_LOG=true
  exit 0
fi

#===============================================================================
# Start of Function
#===============================================================================

# Set up BIDs compliant variables and workspace --------------------------------
DIR_PROJECT=`${DIR_CODE}/bids/get_dir.sh -i ${INPUT_FILE}`
SUBJECT=`${DIR_CODE}/bids/get_field.sh -i ${INPUT_FILE} -f "sub"`
SESSION=`${DIR_CODE}/bids/get_field.sh -i ${INPUT_FILE} -f "ses"`
if [ -z "${PREFIX}" ]; then
  PREFIX=`${DIR_CODE}/bids/get_bidsbase.sh -s -i ${IMAGE}`
fi

if [ -z "${DIR_SAVE}" ]; then
  DIR_SAVE=${DIR_PROJECT}/derivatives/anat/prep/sub-${SUBJECT}/ses-${SESSION}
fi
mkdir -p ${DIR_SCRATCH}
mkdir -p ${DIR_SAVE}

[EXPERIMENT]

SESSION_DB_BASE=${CSV_FILE}
SESSION_DB_TEMP=%(SESSION_DB_BASE)s
SESSION_DB_LONG=%(SESSION_DB_BASE)s

 

EXPERIMENT_BASE=${BASE_NAME}
#EXPERIMENT_TEMP=NOFL_20170302_DM1_temp
#EXPERIMENT_LONG=NOFL_20170302_DM1_long


EXPERIMENT_TEMP_INPUT=%(EXPERIMENT_BASE)s
EXPERIMENT_LONG_INPUT=%(EXPERIMENT_TEMP)s


#WORKFLOW_COMPONENTS_LONG=['denoise','landmark','auxlmk','tissue_classify','segmentation','warp_atlas_to_subject','jointfusion_2012_neuro']
 

WORKFLOW_COMPONENTS_BASE=['denoise','landmark','auxlmk','tissue_classify','warp_atlas_to_subject','jointfusion_2015_wholebrain']
#WORKFLOW_COMPONENTS_BASE=['denoise']
#WORKFLOW_COMPONENTS_TEMP=[]
#WORKFLOW_COMPONENTS_LONG=['denoise','landmark','auxlmk','tissue_classify','warp_atlas_to_subject','jointfusion_2015_wholebrain']
 

+++BASE_OUTPUT_DIR=/Shared/nopoulos/structural/oz_MR/BAWEXPERIMENT_20180329
 

ATLAS_PATH=/Shared/pinc/sharedopt/ReferenceData/Atlas_20131115
JOINTFUSION_ATLAS_DB_BASE=/Shared/pinc/sharedopt/ReferenceData/20160523_HDAdultAtlas/baw20160523WholeBrainAtlasDenoisedList_fixed.csv
RELABEL2LOBES_FILENAME=/Shared/pinc/sharedopt/ReferenceData/20160523_HDAdultAtlas/Label2Lobes_Ver20160524.csv
LABELMAP_COLORLOOKUP_TABLE=/Shared/pinc/sharedopt/ReferenceData/20160523_HDAdultAtlas/BAWHDAdultAtlas_FreeSurferConventionColorLUT_20160524.txt
 

USE_REGISTRATION_MASKING=True
 

[NIPYPE]
GLOBAL_DATA_SINK_REWRITE=True
#GLOBAL_DATA_SINK_REWRITE=False
CRASHDUMP_DIR=/tmp

 

##@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
[RHEL7ARGON]
## The cluster queue to use for submitting "normal running" jobs.
#QUEUE= -q all.q
+++QUEUE= -q PINC,CCOM

 


## The cluster queue to use for submitting "long running" jobs.
#QUEUE_LONG= -q all.q
+++QUEUE_LONG= -q PINC,CCOM

 

## The QSTAT command for immediate update of values [ use 'qstat' if in doubt ]
QSTAT_IMMEDIATE=qstat
QSTAT_CACHED=qstat
## The QSTAT command for cached update of values ( to take load off of OGE server during heavy job usage ) [ use 'qstat' if in doubt ]
# QSTAT_IMMEDIATE_EXE=/Shared/johnsonhj/HDNI/20160219_AutoWorkupTest/scripts/qstat_immediate.sh
# QSTAT_CACHED_EXE=/Shared/johnsonhj/HDNI/20160219_AutoWorkupTest/scripts/qstat_cached.sh


## Necessary modules to load for jobs
MODULES=['intel/2017.1', 'ncurses/6.0',  'cmake/3.7.2', 'graphviz/2.40.1']

 

# Run on a cluster?
_GRAPHVIZ_BIN=/opt/apps/graphviz/2.40.1/bin/dot
VIRTUALENV_DIR=/Shared/pinc/sharedopt/apps/anaconda3/Linux/x86_64/4.3.0/bin
# NAMICExternalProjects build tree
_BUILD_DIR=/Shared/pinc/sharedopt/20170302/RHEL7/NEP-intel
_BRAINSTOOLS_BIN_DIR=%(_BUILD_DIR)s/bin
#_SIMPLEITK_PYTHON_LIB=%(_BUILD_DIR)s/lib
#_SIMPLEITK_PACKAGE_DIR=%(_BUILD_DIR)s/SimpleITK-build/Wrapping
#_NIPYPE_PACKAGE_DIR=
#%(_BUILD_DIR)s/NIPYPE
############## -- You should not need to modify below here. ###########
APPEND_PYTHONPATH=%(_BUILD_DIR)s/BRAINSTools/AutoWorkup:%(_BUILD_DIR)s/BRAINSTools/AutoWorkup/workflows
#%(_NIPYPE_PACKAGE_DIR)s:%(_SIMPLEITK_PYTHON_LIB)s:%(_SIMPLEITK_PACKAGE_DIR)s
APPEND_PATH=%(_BRAINSTOOLS_BIN_DIR)s:%(_GRAPHVIZ_BIN)s
#APPEND_PATH=%(_BRAINSTOOLS_BIN_DIR)s:%(_SIMPLEITK_PYTHON_LIB)s:%(_GRAPHVIZ_BIN)s
 
##@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
[RHEL7PINC]
## The cluster queue to use for submitting "normal running" jobs.
#QUEUE= -q all.q
QUEUE= -q x64
 

## The cluster queue to use for submitting "long running" jobs.
#QUEUE_LONG= -q all.q
QUEUE_LONG= -q x64


## The QSTAT command for immediate update of values [ use 'qstat' if in doubt ]
QSTAT_IMMEDIATE=qstat
QSTAT_CACHED=qstat
## The QSTAT command for cached update of values ( to take load off of OGE server during heavy job usage ) [ use 'qstat' if in doubt ]
# QSTAT_IMMEDIATE_EXE=/Shared/johnsonhj/HDNI/20160219_AutoWorkupTest/scripts/qstat_immediate.sh
# QSTAT_CACHED_EXE=/Shared/johnsonhj/HDNI/20160219_AutoWorkupTest/scripts/qstat_cached.sh
 

## Necessary modules to load for jobs
MODULES=[]
 

# Run on a cluster?
_GRAPHVIZ_BIN=/opt/apps/graphviz/2.40.1/bin/dot
VIRTUALENV_DIR=/Shared/pinc/sharedopt/apps/anaconda3/Linux/x86_64/4.3.0/bin
# NAMICExternalProjects build tree
_BUILD_DIR=/Shared/pinc/sharedopt/20170302/RHEL7/NEP-11
_BRAINSTOOLS_BIN_DIR=%(_BUILD_DIR)s/bin
#_SIMPLEITK_PYTHON_LIB=%(_BUILD_DIR)s/lib
#_SIMPLEITK_PACKAGE_DIR=%(_BUILD_DIR)s/SimpleITK-build/Wrapping
#_NIPYPE_PACKAGE_DIR=
#%(_BUILD_DIR)s/NIPYPE
############## -- You should not need to modify below here. ###########
APPEND_PYTHONPATH=%(_BUILD_DIR)s/BRAINSTools/AutoWorkup:%(_BUILD_DIR)s/BRAINSTools/AutoWorkup/workflows
#%(_NIPYPE_PACKAGE_DIR)s:%(_SIMPLEITK_PYTHON_LIB)s:%(_SIMPLEITK_PACKAGE_DIR)s
APPEND_PATH=%(_BRAINSTOOLS_BIN_DIR)s:%(_GRAPHVIZ_BIN)s
#APPEND_PATH=%(_BRAINSTOOLS_BIN_DIR)s:%(_SIMPLEITK_PYTHON_LIB)s:%(_GRAPHVIZ_BIN)s
 

##@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
[OSX]
## The cluster queue to use for submitting "normal running" jobs.
QUEUE=-q COE,UI,HJ,PINC
#QUEUE=-q ICTS,COE,UI
## The cluster queue to use for submitting "long running" jobs.
QUEUE_LONG= -q COE,UI,HJ,PINC
#QUEUE_LONG= -q ICTS,COE,UI
## The QSTAT command for immediate update of values [ use 'qstat' if in doubt ]
QSTAT_IMMEDIATE=qstat
QSTAT_CACHED=qstat
## The QSTAT command for cached update of values ( to take load off of OGE server during heavy job usage ) [ use 'qstat' if in doubt ]
# QSTAT_IMMEDIATE_EXE=/Shared/johnsonhj/HDNI/20160219_AutoWorkupTest/scripts/qstat_immediate.sh
# QSTAT_CACHED_EXE=/Shared/johnsonhj/HDNI/20160219_AutoWorkupTest/scripts/qstat_cached.sh
 

## Necessary modules to load for jobs
MODULES=[]
 
# Run on a cluster?
_GRAPHVIZ_BIN=/usr/local/
VIRTUALENV_DIR=/Shared/pinc/sharedopt/apps/anaconda3/Linux/x86_64/4.3.0/bin
 
# NAMICExternalProjects build tree
_BUILD_DIR=/scratch/johnsonhj/src/NEP-intel
_BRAINSTOOLS_BIN_DIR=%(_BUILD_DIR)s/bin
_SIMPLEITK_PYTHON_LIB=%(_BUILD_DIR)s/lib
_SIMPLEITK_PACKAGE_DIR=%(_BUILD_DIR)s/SimpleITK-build/Wrapping
_NIPYPE_PACKAGE_DIR=%(_BUILD_DIR)s/NIPYPE
############## -- You should not need to modify below here. ###########
APPEND_PYTHONPATH=%(_NIPYPE_PACKAGE_DIR)s:%(_SIMPLEITK_PYTHON_LIB)s:%(_SIMPLEITK_PACKAGE_DIR)s
APPEND_PATH=%(_BRAINSTOOLS_BIN_DIR)s:%(_SIMPLEITK_PYTHON_LIB)s:%(_GRAPHVIZ_BIN)s
 
 
[DEFAULT]
# The prefix to add to all image files in the $(SESSION_DB) to account for different file system mount points
MOUNT_PREFIX=
MODULES=


#===============================================================================
# End of Function
#===============================================================================

exit 0

