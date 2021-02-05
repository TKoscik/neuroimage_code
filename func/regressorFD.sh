#!/bin/bash -x


#===============================================================================
# Functional Timeseries - Spike Regression via Framewise Displacement Measures
#-------------------------------------------------------------------------------
# by Lauren Hopkins (lauren-hopkins@uiowa.edu)

PROC_START=$(date +%Y-%m-%dT%H:%M:%S%z)
FCN_NAME=($(basename "$0"))
DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
OPERATOR=$(whoami)
KERNEL="$(unname -s)"
HARDWARE="$(uname -m)"
HPC_Q=${QUEUE}
HPC_SLOTS=${NSLOTS}
KEEP=false
NO_LOG=false
umask 007

# actions on exit, write to logs, clean scratch
function egress {
  EXIT_CODE=$?
  PROC_STOP=$(date +%Y-%m-%dT%H:%M:%S%z)
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
  if [[ "${NO_LOG}" == "false" ]]; then
    ${DIR_INC}/log/logBenchmark.sh --operator ${OPERATOR} \
    --hardware ${HARDWARE} --kernel ${KERNEL} --hpc-q ${HPC_Q} --hpc-slots ${HPC_SLOTS} \
    --fcn-name ${FCN_NAME} --proc-start ${PROC_START} --proc-stop ${PROC_STOP} --exit-code ${EXIT_CODE}
    ${DIR_INC}/log/logProject.sh --operator ${OPERATOR} \
    --dir-project ${DIR_PROJECT} --pid ${PID} --sid ${SID} \
    --hardware ${HARDWARE} --kernel ${KERNEL} --hpc-q ${HPC_Q} --hpc-slots ${HPC_SLOTS} \
    --fcn-name ${FCN_NAME} --proc-start ${PROC_START} --proc-stop ${PROC_STOP} --exit-code ${EXIT_CODE}
    ${DIR_INC}/log/logSession.sh --operator ${OPERATOR} \
    --dir-project ${DIR_PROJECT} --pid ${PID} --sid ${SID} \
    --hardware ${HARDWARE} --kernel ${KERNEL} --hpc-q ${HPC_Q} --hpc-slots ${HPC_SLOTS} \
    --fcn-name ${FCN_NAME} --proc-start ${PROC_START} --proc-stop ${PROC_STOP} --exit-code ${EXIT_CODE}
  fi
}
trap egress EXIT

# Parse inputs -----------------------------------------------------------------
OPTS=$(getopt -o hvkl --long prefix:,\
ts-bold:,dir-save:,dir-scratch:,\
keep,help,verbose,no-log -n 'parse-options' -- "$@")
if [[ $? != 0 ]]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
PREFIX=
TS_BOLD=
DIR_SAVE=
DIR_SCRATCH=${DIR_TMP}/${OPERATOR}_${DATE_SUFFIX}
HELP=false
VERBOSE=1
KEEP=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -k | --keep) KEEP=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --ts-bold) TS_BOLD="$2" ; shift 2 ;;
    --dir-save) DIR_SAVE="$2" ; shift 2 ;;
    --dir-scratch) DIR_SCRATCH="$2" ; shift 2 ;;
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
  echo '  -v | --verbose           add verbose output to log file'
  echo '  -k | --keep              keep preliminary processing steps'
  echo '  -l | --no-log            disable writing to output log'
  echo '  --prefix <value>         scan prefix,'
  echo '                           default: sub-123_ses-1234abcd'
  echo '  --ts-bold <value>        Full path to single, run timeseries'
  echo '  --dir-save <value>       directory to save output, default varies by function'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo ''
  NO_LOG=true
  exit 0
fi

#==============================================================================
# Start of Function
#==============================================================================

# Set up BIDs compliant variables and workspace --------------------------------
DIR_PROJECT=$(${DIR_CODE}/bids/get_dir.sh -i ${TS_BOLD})
PID=$(${DIR_CODE}/bids/get_field.sh -i ${TS_BOLD} -f sub)
SID=$(${DIR_CODE}/bids/get_field.sh -i ${TS_BOLD} -f ses)
if [[ ! -f "${TS_BOLD}" ]]; then
  echo "The BOLD file does not exist. Exiting."
  exit 1
fi
if [ -z "${PREFIX}" ]; then
  PREFIX=$(${DIR_CODE}/bids/get_bidsbase.sh -s -i ${TS_BOLD})
fi
if [ -z "${DIR_SAVE}" ]; then
  DIR_SAVE=${DIR_PROJECT}/derivatives/inc/func
fi
mkdir -p ${DIR_SCRATCH}
mkdir -p ${DIR_SAVE}

#Data dependencies:
#Important directories
FUNC_DIR=${DIR_PROJECT}/derivatives/inc/func
ANAT_DIR=${DIR_PROJECT}/derivatives/inc/anat
REGRESSION_TOP=${FUNC_DIR}/regressors
maskDir=${FUNC_DIR}/mask

# Set some helper variables depending on whether session is specified
DIR_SUBSES=sub-${PID}
SUBSES=sub-${PID}
if [[ -n "${SID}" ]]; then
  DIR_SUBSES=${DIR_SUBSES}/ses-${SID}
  SUBSES=sub-${SUBSES}_ses-${SID}
fi

#EPI data
#Motion Parameter directory
parDir=${REGRESSION_TOP}/sub-${PID}
if [[ -n "${SID}" ]]; then
  parDir=${parDir}/ses-${SID}
fi

if [[ ! -f "${TS_BOLD}" ]]; then
  echo "No BOLD file found, cannot run framewise displacement."
  exit 1
fi


#Round up some information about the input EPI
epiBase=$(basename ${TS_BOLD} | awk -F"." '{print $1}')
epiPath=$(dirname ${TS_BOLD})
numVols=$($ANTSPATH/PrintHeader ${TS_BOLD} 2 | awk -F"x" '{print $NF}')

#Motion parameters (all mm) for input EPI
epiPar=${parDir}/${PREFIX}_moco+6.1D

if [[ -f "${epiPar}" ]]; then
  echo "PARAM FILE IS ${epiPar}"
else
  echo "No moco parameter file for ${TS_BOLD} found."
  echo "Run moco+reg.sh before running this script."
  exit 1
fi

###################### FD Regression function ###################### 
#Calculate cumulative FD from TR to TR, if above 0.25mm, create a regression file (0 for all other TRs, 1 for TR above limit)
  #Will have one file TR that is above limit
  #sqrt((trN-(trN-1))^2)
spikeRegressionSetup()
{
  input=$1
  outBase=$2
  outDir=$3

  #Determine number of TRs total
  Length=$(cat ${input} | wc -l)

  #Loop through the TRs
  i=2
  while [[ $i -le $Length ]];
    do

    #Set index for previous TR
    let j=i-1

    #Calculate cumulative motion for current TR, preceeding TR
    iSum=$(cat $input | head -n+${i} | tail -n-1 | awk '{ for(y=1; y<=NF;y++) z+=$y; print z; z=0 }')
    jSum=$(cat $input | head -n+${j} | tail -n-1 | awk '{ for(y=1; y<=NF;y++) z+=$y; print z; z=0 }')

    #Calculate rms of cumulative motion between TRs
    rmsVal=$(echo ${iSum} ${jSum} | awk '{print sqrt(($1-$2)^2)}')

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
  paste -d " " $(ls -1tv $outDir/${outBase}_spike_*.1D) > $outDir/${outBase}_spikes.1D
  rm $outDir/${outBase}_spike_*.1D
}
###################### FD Regression function ends ###################### 



  
numVols=$($ANTSPATH/PrintHeader ${TS_BOLD} 2 | awk -F"x" '{print $NF}')
trVal=$($ANTSPATH/PrintHeader ${TS_BOLD} 1 | awk -F"x" '{print $NF}')

#Reformat motion param file from comma-delim to space-delim otherwise fx won't add
tr "," " " < $epiPar > ${parDir}/friston24/epiPar_space_tmp.1D
#epiPar_space=`less -S ${parDir}/friston24/epiPar_space_tmp.1D`
epiPar_space=${parDir}/friston24/epiPar_space_tmp.1D

if [[ ! -d ${regressionDir}/spikes ]]; then
    mkdir ${regressionDir}/spikes
fi

#Create movement regression spikes (rms motion TR difference > 0.25)
#function call for fx above
spikeRegressionSetup ${epiPar_space} ${epiBase} ${regressionDir}/spikes


exit 0