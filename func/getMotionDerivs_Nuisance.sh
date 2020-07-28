#!/bin/bash

####################

ver=1.0.0
verDate=7/16/20

####################

# A script that will regress nuisance parameters from functional (task or rest) EPI data.
# Initially made for motion derivatives/quadratics but other stuff got added
#  1) Friston24 (motion parameters + quadratics & derivatives)
#  2) TBD but may include framewise displacement etc.
#
# by Lauren Hopkins (lauren-hopkins@uiowa.edu)

#########################################################################################################

scriptName="getMotionDerivs_Nuisance.sh"
nimg_scriptDir=/Shared/nopoulos/nimg_core
atlasDir=${nimg_scriptDir}/templates_human
userID=`whoami`

## NOTE: This is an old source script
## TBD: Remake more updated source script
source ${nimg_scriptDir}/sourcePack.sh

#Source versions of programs used:
VER_afni=${VER_afni}
VER_ants=${VER_ants}
VER_fsl=${VER_fsl}
VER_matlab=${VER_matlab}
source /Shared/pinc/sharedopt/apps/sourcefiles/anaconda3_source.sh 2019.10

# # Parse inputs -----------------------------------------------------------------
# OPTS=`getopt -o hl --long group:,prefix:,is_ses:,\
# ts-bold:,label-tissue:,value-csf:,value-wm:,\
# dir-save:,dir-scratch:,dir-code:,dir-pincsource:,\
# help,verbose,no-log -n 'parse-options' -- "$@"`
# if [ $? != 0 ]; then
#   echo "Failed parsing options" >&2
#   exit 1
# fi
# eval set -- "$OPTS"

# # actions on exit, e.g., cleaning scratch on error ----------------------------
# function egress {
#   if [[ -d ${DIR_SCRATCH} ]]; then
#     if [[ "$(ls -A ${DIR_SCRATCH})" ]]; then
#       rm -R ${DIR_SCRATCH}/*
#     fi
#     rmdir ${DIR_SCRATCH}
#   fi
# }
# trap egress EXIT

# Set default values for function ---------------------------------------------
DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
GROUP=
PREFIX=
TS_BOLD=
LABEL_TISSUE=
VALUE_CSF=1
VALUE_WM=3
DIR_SAVE=
DIR_SCRATCH=/Shared/inc_scratch/${userID}_scratch_${DATE_SUFFIX}
DIR_CODE=/Shared/inc_scratch/code
DIR_FUNC_CODE=${DIR_CODE}/func
DIR_ANAT_CODE=${DIR_CODE}/anat
DIR_PINCSOURCE=/Shared/pinc/sharedopt/apps/sourcefiles
HELP=false
NO_LOG=false
IS_SES=true

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --group) GROUP="$2" ; shift 2 ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --ts-bold) TS_BOLD="$2" ; shift 2 ;;
    --label-tissue) LABEL_TISSUE="$2" ; shift 2 ;;
    --value-csf) VALUE_CSF="$2" ; shift 2 ;;
    --value-wm) VALUE_WM="$2" ; shift 2 ;;
    --is_ses) IS_SES="$2" ; shift 2 ;;
    --dir-save) DIR_SAVE="$2" ; shift 2 ;;
    --dir-scratch) SCRATCH="$2" ; shift 2 ;;
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
  echo '  -l | --no-log            disable writing to output log'
  echo '  --group <value>          group permissions for project,'
  echo '                           e.g., Research-kosciklab'
  echo '  --prefix <value>         scan prefix,'
  echo '                           default: sub-123_ses-1234abcd'
  echo '  --ts-bold <value>        Full path to single, run timeseries'
  echo '  --label-tissue <value>   Full path to file containing tissue type labels'
  echo '  --value-csf <value>      numeric value indicating CSF in label file, default=1'
  echo '  --value-wm <value>       numeric value indicating WM in label file, default=3'
  echo '  --is_ses <boolean>       is there a session folder,'
  echo '                           default: true'
  echo '  --dir-save <value>       directory to save output, default varies by function'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo '  --dir-code <value>       directory where INC tools are stored,'
  echo '                           default: ${DIR_CODE}'
  echo '  --dir-pincsource <value> directory for PINC sourcefiles'
  echo '                           default: ${DIR_PINCSOURCE}'
  echo ''
  exit 0
fi

# Set up BIDs compliant variables and workspace --------------------------------
proc_start=$(date +%Y-%m-%dT%H:%M:%S%z)

DIR_PROJECT=`${DIR_CODE}/bids/get_dir.sh -i ${TS_BOLD}`
SUBJECT=`${DIR_CODE}/bids/get_field.sh -i ${TS_BOLD} -f "sub"`
SESSION=`${DIR_CODE}/bids/get_field.sh -i ${TS_BOLD} -f "ses"`
TASK=`${DIR_CODE}/bids/get_field.sh -i ${TS_BOLD} -f "task"`
RUN=`${DIR_CODE}/bids/get_field.sh -i ${TS_BOLD} -f "run"`
if [ -z "${PREFIX}" ]; then
  PREFIX=`${DIR_CODE}/bids/get_bidsbase -s -i ${IMAGE}`
fi

#Begin Logging
if [[ ! -d ${DIR_PROJECT}/log ]]; then
  mkdir -p ${DIR_PROJECT}/log
fi

# if [ -z "${DIR_SAVE}" ]; then
#   DIR_SAVE=${DIR_PROJECT}/derivatives/anat/prep/sub-${SUBJECT}/ses-${SESSION}
# fi
if [ -z "${SESSION}" ]; then
  subject_log=${DIR_PROJECT}/log/sub-${SUBJECT}.log
else
  subject_log=${DIR_PROJECT}/log/sub-${subject}_ses-${session}.log
fi
##################################### logging ###########################################################
echo '#--------------------------------------------------------------------------------' >> ${subject_log}
echo "getMotionDerivs_Nuisance.sh" >> ${subject_log}
echo "script:${DIR_FUNC_CODE}/${scriptName}" >> ${subject_log}
echo "software:AFNI,version:${VER_afni}" >> ${subject_log}
echo "software:ANTs,version:${VER_ants}" >> ${subject_log}
echo "software:FSL,version:${VER_fsl}" >> ${subject_log}
echo "software:matlab,version:${VER_matlab}" >> ${subject_log}
echo "owner: ${userID}" >> ${subject_log} >> ${subject_log}
date +"start:%Y-%m-%dT%H:%M:%S%z" >> ${subject_log} >> ${subject_log}
#########################################################################################################

#Data dependencies:
 #Important directories
 FUNC_DIR=${DIR_PROJECT}/derivatives/func
 ANAT_DIR=${DIR_PROJECT}/derivatives/anat
 FUNC_PREP_DIR=${FUNC_DIR}/prep
 #EPI data
  #Motion Parameter directory
  if [ "${IS_SES}" = true ]; then
    parDir=${FUNC_PREP_DIR}/sub-${subject}/ses-${session}
  else
    parDir=${FUNC_PREP_DIR}/sub-${subject}
  fi
 #EPI Mask directory
 maskDir=${FUNC_DIR}/mask
#Round up some information about the input EPI
epiBase=`basename $epi | awk -F"." '{print $1}'`
epiPath=`dirname $epi`
numVols=`$ANTSPATH/PrintHeader $epi 2 | awk -F"x" '{print $NF}'`
trVal=`$ANTSPATH/PrintHeader $epi 1 | awk -F"x" '{print $NF}'`
if [[ ${TR} == "" ]]; then
  TR=${trVal}
else
  TR=${TR}
fi

#Motion parameters (all mm) for input EPI
epiPar=${parDir}/${epiBase}_mcImg_mm.par

#Mask for EPI
epiMask=${maskDir}/${epiBase}_mask.nii.gz

#Make 4dfp style motion parameter and derivative regressors for timeseries (quadratic and derivatives)
#Take the backwards temporal derivative in column $i of input $2 and output it as $3
#Vectorized Matlab: d=[zeros(1,size(a,2));(a(2:end,:)-a(1:end-1,:))];
#Bash version of above algorithm
if [[ ! -d ${regressionDir}/friston24 ]]; then
  mkdir -p ${regressionDir}/friston24
fi

#Reformat input to be space delimited (will be merged with quadratics, derivatives)
cat ${epiPar} | sed s/"  "/" "/g > ${regressionDir}/friston24/${epiBase}_Friston24.par



#Loop through the 6 motion parameters (mm)
  i=1
  while [[ ${i} -le 6 ]] ; do
    deriveBackwards ${i} ${epiPar} ${regressionDir}/friston24
    let i=i+1
  done

  #Push together the original file and subsequent derivatives/quadratics into one file
  paste -d " " ${regressionDir}/friston24/${epiBase}_Friston24.par ${regressionDir}/friston24/_tmp3 ${regressionDir}/friston24/_tmp1 \
  ${regressionDir}/friston24/_tmp2 > ${regressionDir}/friston24/${epiBase}_Friston24.par_
  mv ${regressionDir}/friston24/${epiBase}_Friston24.par_ ${regressionDir}/friston24/${epiBase}_Friston24.par

  #Clean up the last of the temporary files
  rm ${regressionDir}/friston24/_tmp*

  #The last of the formatting (6 decimal places, nice columns)
  cat ${regressionDir}/friston24/${epiBase}_Friston24.par | awk '{for(i=1;i<=NF;i++)printf("%10.6f ",$i);printf("\n")}' \
  > ${regressionDir}/friston24/${epiBase}_Friston24.par_
  mv ${regressionDir}/friston24/${epiBase}_Friston24.par_ ${regressionDir}/friston24/${epiBase}_Friston24.par



#Calculate quadradics and derivatives of an input set of regressors (e.g. mcImg.par) -- Take from HCP pipeline and altered
deriveBackwards()
{
  i=$1
  in=$2
  outDir=$3

  #Var becomes a string of values from column $i in $in. Single space separated
  Var=`cat ${in} | sed s/"  "/" "/g | cut -d " " -f ${i}`
  Length=`echo ${Var} | wc -w`
  #TCS becomes an array of the values from column $i in $in (derived from $Var)
  TCS=($Var)

  #Cycle through our array of values from column $i
  j=0
  while [[ ${j} -lt ${Length} ]] ; do
    if [[ ${j} -eq 0 ]] ; then #First volume
      #Backward derivative of first volume is set to 0
      Answer=`echo "0"`
      AnswerSquared=`echo "0"`

      #Format numeric value (convert scientific notation to decimal) jth row of ith column in $in
      Forward=`echo ${TCS[$j]} | awk -F"E" 'BEGIN{OFMT="%10.10f"} {print $1 * (10 ^ $2)}'`

      #Quadratic of original parameter
      ForwardSquared=`echo "scale=10; ${Forward} * ${Forward}" | bc -l`
    else #Compute the backward derivative of non-first volumes
      #Format numeric value (convert scientific notation to decimal) jth row of ith column in $in
      Forward=`echo ${TCS[$j]} | awk -F"E" 'BEGIN{OFMT="%10.10f"} {print $1 * (10 ^ $2)}'`

      #Similarly format numeric value for previous row (j-1)
      Back=`echo ${TCS[$(($j-1))]} | awk -F"E" 'BEGIN{OFMT="%10.10f"} {print $1 * (10 ^ $2)}'`

      #Quadratic of original parameter
      ForwardSquared=`echo "scale=10; ${Forward} * ${Forward}" | bc -l`

      #Compute backward derivative as current minus previous
      Answer=`echo "scale=10; ${Forward} - ${Back}" | bc -l`

      #Quadratic of derivative
      AnswerSquared=`echo "scale=10; ${Answer} * ${Answer}" | bc -l`
    fi
    #0 prefix the resulting number(s)
    ForwardSquared=`echo ${ForwardSquared} | sed s/"^\."/"0."/g | sed s/"^-\."/"-0."/g`
    Answer=`echo ${Answer} | sed s/"^\."/"0."/g | sed s/"^-\."/"-0."/g`
    AnswerSquared=`echo ${AnswerSquared} | sed s/"^\."/"0."/g | sed s/"^-\."/"-0."/g`

    echo `printf "%10.6f" ${Answer}` >> ${outDir}/tmp1
    echo `printf "%10.6f" ${AnswerSquared}` >> ${outDir}/tmp2
    echo `printf "%10.6f" ${ForwardSquared}` >> ${outDir}/tmp3

    j=$(($j + 1))
  done

    #Need to push all 3 columns of each calculation (R^2, R`, (R`)^2) together as each iteration of "${i}" (column) creates three new tmp files
    if [ ${i} -eq 1 ] ; then
      mv ${outDir}/tmp1 ${outDir}/_tmp1
      mv ${outDir}/tmp2 ${outDir}/_tmp2
      mv ${outDir}/tmp3 ${outDir}/_tmp3
    else
      paste -d " " ${outDir}/_tmp1 ${outDir}/tmp1  > ${outDir}/_tmp1b
      mv ${outDir}/_tmp1b ${outDir}/_tmp1
      paste -d " " ${outDir}/_tmp2 ${outDir}/tmp2  > ${outDir}/_tmp2b
      mv ${outDir}/_tmp2b ${outDir}/_tmp2
      paste -d " " ${outDir}/_tmp3 ${outDir}/tmp3  > ${outDir}/_tmp3b
      mv ${outDir}/_tmp3b ${outDir}/_tmp3
      #Clean up temporary files
      rm ${outDir}/tmp1 ${outDir}/tmp2 ${outDir}/tmp3
    fi
}


#End logging
chgrp -R ${group} ${regressionDir} > /dev/null 2>&1
chmod -R g+rw ${regressionDir} > /dev/null 2>&1
chgrp -R ${group} ${residualDir} > /dev/null 2>&1
chmod -R g+rw ${residualDir} > /dev/null 2>&1
chgrp ${group} ${subject_log} > /dev/null 2>&1
chmod g+rw ${subject_log} > /dev/null 2>&1
date +"end:%Y-%m-%dT%H:%M:%S%z" >> ${subject_log}
echo "#--------------------------------------------------------------------------------" >> ${subject_log}
echo "" >> ${subject_log}
