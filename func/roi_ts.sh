#!/bin/bash -e

OPTS=`getopt -ovk --long researcher:,project:,group:,subject:,session:,prefix:,ts-bold:,template:,space:,label:,dir-nimgcore:,dir-pincsource:,keep,help,verbose -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

DATE_SUFFIX=$(date +%Y%m%dT%H%M%S)
RESEARCHER=
PROJECT=
GROUP=
SUBJECT=
SESSION=
PREFIX=
TS_BOLD=
TEMPLATE=
SPACE=
LABEL=
DIR_NIMGCORE=/Shared/nopoulos/nimg_core
DIR_PINCSOURCE=/Shared/pinc/sharedopt/apps/sourcefiles
KEEP=false
VERBOSE=0
HELP=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -k | --keep) KEEP=true ; shift ;;
    --researcher) RESEARCHER="$2" ; shift 2 ;;
    --project) PROJECT="$2" ; shift 2 ;;
    --group) GROUP="$2" ; shift 2 ;;
    --subject) SUBJECT="$2" ; shift 2 ;;
    --session) SESSION="$2" ; shift 2 ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --ts-bold) TS_BOLD="$2" ; shift 2 ;;
    --template) TEMPLATE="$2" ; shift 2 ;;
    --space) SPACE="$2" ; shift 2 ;;
    --label) LABEL="$2" ; shift 2 ;;
    --dir-nimgcore) DIR_NIMGCORE="$2" ; shift 2 ;;
    --dir-pincsource) DIR_PINCSOURCE="$2" ; shift 2 ;;
    -- ) shift ; break ;;
    * ) break ;;
  esac
done

# Usage Help ------------------------------------------------------------------

#==============================================================================
# gather ROI timeseries
#==============================================================================
DIR_TS=${RESEARCHER}/${PROJECT}/derivatives/func/ts_${TEMPLATE}_${SPACE}_${LABEL}
mkdir -p ${DIR_TS}
fslmeants \
  -i ${TS_BOLD} \
  -o ${DIR_TS}/${PREFIX}_ts-${TEMPLATE}+${SPACE}+${LABEL}.csv \
  --label=${DIR_NIMGCORE}/templates_human/${TEMPLATE}/${SPACE}/${TEMPLATE}_${SPACE}_label-${LABEL}.nii.gz
sed -i s/"  "/","/g ${DIR_TS}/${PREFIX}_ts-${TEMPLATE}+${SPACE}+${LABEL}.csv
sed -i s/",$"//g ${DIR_TS}/${PREFIX}_ts-${TEMPLATE}+${SPACE}+${LABEL}.csv

