#!/bin/bash

####################

ver=1.0.0
verDate=8/24/20

####################

# A script that will create a variety of different regressors from functional (task or rest) EPI data.  
# Which regressors get created depends on user choice
# Initially made for motion derivatives/quadratics but other stuff got added
#  1) Friston24 (motion parameters + quadratics & derivatives)
#  2) Framewise displacement
#  3) TBD but may include spike regressors & more
#
# by Lauren Hopkins (lauren-hopkins@uiowa.edu)

#########################################################################################################

scriptName="calculate_regressors.sh"
userID=`whoami`

#Source versions of programs used:
VER_afni=${VER_afni}
VER_ants=${VER_ants}
VER_fsl=${VER_fsl}
VER_matlab=${VER_matlab}
source /Shared/pinc/sharedopt/apps/sourcefiles/anaconda3_source.sh 2019.10

# Parse inputs -----------------------------------------------------------------
OPTS=`getopt -o hl --long prefix:,is_ses:,moco_file:,\
ts-bold:,dir-save:,dir-scratch:,dir-code:,\
help,verbose,no-log -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# actions on exit, e.g., cleaning scratch on error ----------------------------
function egress {
  if [[ -d ${DIR_SCRATCH} ]]; then
    if [[ "$(ls -A ${DIR_SCRATCH})" ]]; then
      rm -R ${DIR_SCRATCH}/*
    fi
    rmdir ${DIR_SCRATCH}
  fi
  if [[ -d ${parDir}/friston24 ]]; then
    if [[ "$(ls -A ${parDir}/friston24)" ]]; then
      rm -R ${parDir}/friston24/*
    fi
    rmdir ${parDir}/friston24
  fi
}
trap egress EXIT

# Set default values for function ---------------------------------------------
DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
PREFIX=
TS_BOLD=
DIR_SAVE=
DIR_SCRATCH=/Shared/inc_scratch/${userID}_scratch_${DATE_SUFFIX}
DIR_CODE=/Shared/inc_scratch/code
DIR_FUNC_CODE=${DIR_CODE}/func
DIR_ANAT_CODE=${DIR_CODE}/anat
HELP=false
NO_LOG=false
IS_SES=true

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --ts-bold) TS_BOLD="$2" ; shift 2 ;;
    --is_ses) IS_SES="$2" ; shift 2 ;;
    --moco_file) MOCO_FILE="$2" ; shift 2 ;;
    --dir-save) DIR_SAVE="$2" ; shift 2 ;;
    --dir-scratch) SCRATCH="$2" ; shift 2 ;;
    --dir-code) DIR_CODE="$2" ; shift 2 ;;
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
  echo '------------------------------------------------------------------------'
  echo "Usage: ${FUNC_NAME}"
  echo '  -h | --help              display command help'
  echo '  -l | --no-log            disable writing to output log'
  echo '  --group <value>          group permissions for project,'
  echo '                           e.g., Research-kosciklab'
  echo '  --prefix <value>         scan prefix,'
  echo '                           default: sub-123_ses-1234abcd'
  echo '  --ts-bold <value>        Full path to single, run timeseries'
  echo '  --is_ses <boolean>       is there a session folder,'
  echo '                           default: true'
  echo '  --moco_file <value>      Full path to moco+6 or moco+12 file'
  echo '                           default: moco+6 file in regressor directory'
  echo '  --dir-save <value>       directory to save output, default varies by function'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo '  --dir-code <value>       directory where INC tools are stored,'
  echo '                           default: ${DIR_CODE}'
  echo ''
  NO_LOG=true
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

###==================================the actual derivation function==================================###
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
      #Don't delete temp files like Tim asked - save all separately so people can use whatever they want in Tproject
      #rm ${outDir}/tmp1 ${outDir}/tmp2 ${outDir}/tmp3
      mv ${outDir}/tmp1 ${parDir}/backwards_derivative.par; mv ${outDir}/tmp2 ${parDir}/backwards_derivative_quadratic.par; mv ${outDir}/tmp3 ${parDir}/quadratic.par
    fi
}
#================================================================================================================

###==================================the actual framewise displacement function==================================###
#Calculate cumulative FD from TR to TR, if above 0.25mm, create a regression file (0 for all other TRs, 1 for TR above limit)
  #Will have one file TR that is above limit
  #sqrt((trN-(trN-1))^2)
spikeRegressionSetup()
{
  input=$1
  outBase=$2
  outDir=$3

  #Determine number of TRs total
  Length=`cat ${input} | wc -l`

  #Loop through the TRs
  i=2
  while [[ $i -le $Length ]];
    do

    #Set index for previous TR
    let j=i-1

    #Calculate cumulative motion for current TR, preceeding TR
    iSum=`cat $input | head -n+${i} | tail -n-1 | awk '{ for(y=1; y<=NF;y++) z+=$y; print z; z=0 }'`
    jSum=`cat $input | head -n+${j} | tail -n-1 | awk '{ for(y=1; y<=NF;y++) z+=$y; print z; z=0 }'`

    #Calculate rms of cumulative motion between TRs
    rmsVal=`echo ${iSum} ${jSum} | awk '{print sqrt(($1-$2)^2)}'`

    #If rms is >= 0.25, create a spike regression list (1 for current TR, 0 for all others)
    if (( $(echo "${rmsVal} >= 0.25" | bc -l) )); then
      let l=i+1

      #Empty TRs before spike TR
      pre=1
      while [[ ${pre} -lt ${i} ]];
        do
        echo "0" >> $outDir/${outBase}_spike_${i}.1D
        let pre=pre+1       
      done

      #Spike TR
      echo "1" >> $outDir/${outBase}_spike_${i}.1D

      #Empty TRs after spike TR
      post=${l}
      while [[ ${post} -le ${Length} ]];
        do
        echo "0" >> $outDir/${outBase}_spike_${i}.1D
        let post=post+1
      done

    fi

    let i=i+1
  done

  #Combine all spikes into one file
  paste -d " " `ls -1tv $outDir/${outBase}_spike_*.1D` > $outDir/${outBase}_spikes.1D
  rm $outDir/${outBase}_spike_*.1D
}
#================================================================================================================

    ####################
    #  derivSetup      #
    ####################
#Data dependencies:
 #Important directories
 FUNC_DIR=${DIR_PROJECT}/derivatives/func
 ANAT_DIR=${DIR_PROJECT}/derivatives/anat
 FUNC_PREP_DIR=${FUNC_DIR}/prep
 REGRESSION_TOP=${FUNC_DIR}/regressors
 #EPI data
  #Motion Parameter directory
  if [ "${IS_SES}" = true ]; then
    parDir=${REGRESSION_TOP}/sub-${SUBJECT}/ses-${SESSION}
  else 
    parDir=${REGRESSION_TOP}/sub-${SUBJECT}
  fi
  
 #EPI Mask directory
 maskDir=${FUNC_DIR}/mask
#Round up some information about the input EPI
epiBase=`basename ${TS_BOLD} | awk -F"." '{print $1}'`
epiPath=`dirname ${TS_BOLD}`
numVols=`$ANTSPATH/PrintHeader ${TS_BOLD} 2 | awk -F"x" '{print $NF}'`
trVal=`$ANTSPATH/PrintHeader ${TS_BOLD} 1 | awk -F"x" '{print $NF}'`
if [[ ${TR} == "" ]]; then
  TR=${trVal}
else
  TR=${TR}
fi

# If no moco file is passed default to moco+6 in the subject's regressor directory
 if [ -z "${MOCO_FILE}" ]; then
    MOCO_FILE=${parDir}/${PREFIX}_moco+6.1D
 fi

#Motion parameters (all mm) for input EPI
epiPar=${MOCO_FILE}

#Mask for EPI
epiMask=${maskDir}/${epiBase}_mask.nii.gz

#Make 4dfp style motion parameter and derivative regressors for timeseries (quadratic and derivatives)
#Take the backwards temporal derivative in column $i of input $2 and output it as $3
#Vectorized Matlab: d=[zeros(1,size(a,2));(a(2:end,:)-a(1:end-1,:))];
#Bash version of above algorithm
if [[ ! -d ${parDir}/friston24 ]]; then
  mkdir -p ${parDir}/friston24
fi

#Reformat input to be space delimited (will be merged with quadratics, derivatives)
cat ${epiPar} | sed 's/,/ /g' > ${parDir}/friston24/${epiBase}_Friston24.par

#Loop through the 6 or 12 motion parameters (mm)
num_params=`awk -F '[\t,]' '{print  NF}' ${MOCO_FILE} | head -n 1`
  i=1
  while [[ ${i} -le ${num_params} ]] ; do
    deriveBackwards ${i} ${epiPar} ${parDir}/friston24
    let i=i+1
  done

  #Push together the original file and subsequent derivatives/quadratics into one file
  paste -d " " ${parDir}/friston24/${epiBase}_Friston24.par ${parDir}/friston24/_tmp3 ${parDir}/friston24/_tmp1 \
  ${parDir}/friston24/_tmp2 > ${parDir}/friston24/${epiBase}_Friston24.par_
  mv ${parDir}/friston24/${epiBase}_Friston24.par_ ${parDir}/friston24/${epiBase}_Friston24.par

  #Clean up the last of the temporary files
  rm ${parDir}/friston24/_tmp*

  #The last of the formatting (6 decimal places, nice columns)
  cat ${parDir}/friston24/${epiBase}_Friston24.par | awk '{for(i=1;i<=NF;i++)printf("%10.6f ",$i);printf("\n")}' \
  > ${parDir}/friston24/${epiBase}_Friston24.par_
  mv ${parDir}/friston24/${epiBase}_Friston24.par_ ${parDir}/${epiBase}__moco+derivs+quadratic.par

  ##=============================Edit for big data=============================##
  # In the next script - nuisance_regression - it needs to ge passed a comma-separated list of regressors for 3dTproject
  # So I'm just gonna make that here since all the regressors have been calculated by this point
  #paste -d ',' ${parDir}/${epiBase}__moco+derivs+quadratic.par ${parDir}/${PREFIX}_global-anatomy.1D ${parDir}/${PREFIX}_compcorr-anatomy.1D \
  #${parDir}/${PREFIX}_compcorr-temporal.1D > ${parDir}/${PREFIX}_all_regressors.par
  #regressor_array=${parDir}/${epiBase}__moco+derivs+quadratic.par,${parDir}/${PREFIX}_global-anatomy.1D,${parDir}/${PREFIX}_compcorr-anatomy.1D,${parDir}/${PREFIX}_compcorr-temporal.1D

    ####################
    #  spikeSetup      #
    ####################

 # if [[ ${doSpikeRegression} -eq 1 ]]; then

    if [[ ! -d ${parDir}/spikes ]]; then
      mkdir -p ${parDir}/spikes
    fi

    tr "," " " < ${parDir}/$epiPar > ${parDir}/epiPar_space_tmp.1D
    epiPar_space=`less -S ${parDir}/epiPar_space_tmp.1D`
    #Create movement regression spikes (rms motion TR difference > 0.25)
    spikeRegressionSetup ${epiPar_space} ${epiBase} ${parDir}/spikes

 # fi

#End logging
chgrp -R ${group} ${parDir} > /dev/null 2>&1
chmod -R g+rw ${parDir} > /dev/null 2>&1

# Write log entry on conclusion ------------------------------------------------
if [[ "${NO_LOG}" == "false" ]]; then
  LOG_FILE=${DIR_PROJECT}/log/${PREFIX}.log
  date +"task:$0,start:"${proc_start}",end:%Y-%m-%dT%H:%M:%S%z" >> ${LOG_FILE}
fi

exit 0
