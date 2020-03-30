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

# Parse inputs -----------------------------------------------------------------
OPTS=`getopt -o hvlb --long group:,prefix:,\
baw-label:,redo,\
dir-save:,dir-scratch:,dir-nimgcore:,dir-pincsource:,\
help,verbose,no-log -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
GROUP=
PREFIX=
BAW_LABEL=
REDO=false
DIR_SAVE=
DIR_SCRATCH=/Shared/inc_scratch/scratch_${DATE_SUFFIX}
DIR_NIMGCORE=/Shared/nopoulos/nimg_core
DIR_PINCSOURCE=/Shared/pinc/sharedopt/apps/sourcefiles
HELP=false
VERBOSE=0
NO_LOG=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    -b | --baw-label) BAW_LABEL="$2" ; shift 2 ;;
    -r | --redo) REDO=true ; shift ;;
    --group) GROUP="$2" ; shift 2 ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --dir-save) DIR_SAVE="$2" ; shift 2 ;;
    --dir-scratch) DIR_SCRATCH="$2" ; shift 2 ;;
    --dir-nimgcore) DIR_NIMGCORE="$2" ; shift 2 ;;
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
  echo '  -r | --redo              True/False flag to remap a dataset, if false,'
  echo '                           remapping will be done only if the remapped'
  echo '                           output does not exist (DEFAULT), if true,'
  echo '                           will be redone '
  echo '  --group <value>          group permissions for project,'
  echo '                           e.g., Research-kosciklab'
  echo '  --prefix <value>         scan prefix,'
  echo '                           default: sub-123_ses-1234abcd'
  echo '  --dir-save <value>       directory to save output, default varies by function'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo '  --dir-nimgcore <value>   top level directory where INC tools,'
  echo '                           templates, etc. are stored,'
  echo '                           default: ${DIR_NIMGCORE}'
  echo '  --dir-pincsource <value> directory for PINC sourcefiles'
  echo '                           default: ${DIR_PINCSOURCE}'
  echo ''
fi

# Set up BIDs compliant variables and workspace --------------------------------
proc_start=$(date +%Y-%m-%dT%H:%M:%S%z)

DIR_PROJECT=`${DIR_NIMGCORE}/code/bids/get_dir.sh -i ${BAW_LABEL}`
SUBJECT=`${DIR_NIMGCORE}/code/bids/get_field.sh -i ${BAW_LABEL} -f "sub"`
SESSION=`${DIR_NIMGCORE}/code/bids/get_field.sh -i ${BAW_LABEL} -f "ses"`
if [ -z "${PREFIX}" ]; then
  PREFIX=sub-${SUBJECT}_ses-${SESSION}
fi

if [ -z "${DIR_SAVE}" ]; then
  DIR_SAVE=${DIR_PROJECT}/derivatives/anat/label/baw+remap
fi
mkdir -p ${DIR_SCRATCH}
mkdir -p ${DIR_SAVE}

#===============================================================================
# Start of Function
#===============================================================================
# Make ICV label set -----------------------------------------------------------
label_name="icv"
labels=("4,5,15,24,31,43,44,63,85,98,128,999,15000,15001"\
 "7,8,10,11,12,13,16,17,18,26,28,46,47,49,50,51,52,53,54,58,60,251,252,253,254,255,1000,1002,1005,1006,1007,1008,1009,1010,1011,1012,1013,1014,1015,1016,1017,1018,1019,1020,1021,1022,1024,1025,1026,1027,1028,1029,1030,1031,1032,1033,1034,1035,1116,1129,2000,2002,2005,2006,2007,2008,2009,2010,2011,2012,2013,2014,2015,2016,2017,2018,2019,2020,2021,2022,2024,2025,2026,2027,2028,2029,2030,2031,2032,2033,2034,2035,2116,2129,3001,3002,3003,3005,3006,3007,3008,3009,3010,3011,3012,3013,3014,3015,3016,3017,3018,3019,3020,3021,3022,3023,3024,3025,3026,3027,3028,3029,3030,3031,3032,3033,3034,3035,4001,4002,4003,4005,4006,4007,4008,4009,4010,4011,4012,4013,4014,4015,4016,4017,4018,4019,4020,4021,4022,4023,4024,4025,4026,4027,4028,4029,4030,4031,4032,4033,4034,4035,5001,5002,15071,15072,15073,15140,15141,15142,15143,15144,15145,15150,15151,15156,15157,15160,15161,15162,15163,15164,15165,15172,15173,15174,15175,15178,15179,15184,15185,15190,15191,15192,15193,15194,15195,15200,15201")
if [[ "${REDO}" == "true" ]] || [[ ! -f ${DIR_SAVE}/${PREFIX}_baw+${label_name}.nii.gz ]]; then
  OUTPUT=${DIR_SCRATCH}/${PREFIX}_baw+${label_name}.nii.gz
  fslmaths ${BAW_LABEL} -mul 0 ${OUTPUT}
  for (( j=0; j<${#labels[@]}; j++ )); do
    lut_values=(${labels[${j}]//,/ })
    label_value=$(( ${j} + 1 ))
    for (( i=0; i<${#lut_values[@]}; i ++ )); do
      fslmaths ${BAW_LABEL} -thr ${lut_values[${i}]} -uthr ${lut_values[${i}]} -bin -mul ${label_value} ${DIR_SCRATCH}/roi_temp.nii.gz
      fslmaths ${OUTPUT} -add ${DIR_SCRATCH}/roi_temp.nii.gz ${OUTPUT}
     rm ${DIR_SCRATCH}/roi_temp.nii.gz
    done
  done
  mv ${OUTPUT} ${DIR_SAVE}/
fi

# Make CRB label set -----------------------------------------------------------
label_name="crb"
labels=("10,11,12,13,17,18,26,28,49,50,51,52,53,54,58,60,251,252,253,254,255,1000,1002,1005,1006,1007,1008,1009,1010,1011,1012,1013,1014,1015,1016,1017,1018,1019,1020,1021,1022,1024,1025,1026,1027,1028,1029,1030,1031,1032,1033,1034,1035,1116,1129,2000,2002,2005,2006,2007,2008,2009,2010,2011,2012,2013,2014,2015,2016,2017,2018,2019,2020,2021,2022,2024,2025,2026,2027,2028,2029,2030,2031,2032,2033,2034,2035,2116,2129,3001,3002,3003,3005,3006,3007,3008,3009,3010,3011,3012,3013,3014,3015,3016,3017,3018,3019,3020,3021,3022,3023,3024,3025,3026,3027,3028,3029,3030,3031,3032,3033,3034,3035,4001,4002,4003,4005,4006,4007,4008,4009,4010,4011,4012,4013,4014,4015,4016,4017,4018,4019,4020,4021,4022,4023,4024,4025,4026,4027,4028,4029,4030,4031,4032,4033,4034,4035,5001,5002,15140,15141,15142,15143,15144,15145,15150,15151,15156,15157,15160,15161,15162,15163,15164,15165,15172,15173,15174,15175,15178,15179,15184,15185,15190,15191,15192,15193,15194,15195,15200,15201"/
 "7,8,46,47,15071,15072,15073")
if [[ "${REDO}" == "true" ]] || [[ ! -f ${DIR_SAVE}/${PREFIX}_baw+${label_name}.nii.gz ]]; then
  OUTPUT=${DIR_SCRATCH}/${PREFIX}_baw+${label_name}.nii.gz
  fslmaths ${BAW_LABEL} -mul 0 ${OUTPUT}
  for (( j=0; j<${#labels[@]}; j++ )); do
    lut_values=(${labels[${j}]//,/ })
    label_value=$(( ${j} + 1 ))
    for (( i=0; i<${#lut_values[@]}; i ++ )); do
      fslmaths ${BAW_LABEL} -thr ${lut_values[${i}]} -uthr ${lut_values[${i}]} -bin -mul ${label_value} ${DIR_SCRATCH}/roi_temp.nii.gz
      fslmaths ${OUTPUT} -add ${DIR_SCRATCH}/roi_temp.nii.gz ${OUTPUT}
     rm ${DIR_SCRATCH}/roi_temp.nii.gz
    done
  done
  mv ${OUTPUT} ${DIR_SAVE}/
fi

# Make LOBES label set -----------------------------------------------------------
label_name="lobes"
labels=("1000,1002,1012,1014,1017,1018,1019,1020,1024,1026,1027,1028,1032,1035,1129,2000,2002,2012,2014,2017,2018,2019,2020,2024,2026,2027,2028,2032,2035,2129,3002,3003,3012,3014,3017,3018,3019,3020,3023,3024,3026,3027,3028,3032,3035,4002,4003,4012,4014,4017,4018,4019,4020,4023,4024,4026,4027,4028,4032,4035,15140,15141,15142,15143,15150,15151,15162,15163,15164,15165,15178,15179,15190,15191,15192,15193"\
"17,18,53,54,1006,1007,1009,1015,1016,1030,1033,1034,2006,2007,2009,2015,2016,2030,2033,2034,3001,3006,3007,3009,3015,3016,3030,3033,3034,4001,4006,4007,4009,4015,4016,4030,4033,4034,15172,15173,15184,15185,15200,15201"\
 "1008,1010,1022,1025,1029,1031,2008,2010,2022,2025,2029,2031,3008,3010,3022,3025,3029,3031,4008,4010,4022,4025,4029,4031,15174,15175,15194,15195"\
 "1005,1011,1013,1021,1116,2005,2011,2013,2021,2116,3005,3011,3013,3021,4005,4011,4013,4021,15144,15145,15156,15157,15160,15161")
if [[ "${REDO}" == "true" ]] || [[ ! -f ${DIR_SAVE}/${PREFIX}_baw+${label_name}.nii.gz ]]; then
  OUTPUT=${DIR_SCRATCH}/${PREFIX}_baw+${label_name}.nii.gz
  fslmaths ${BAW_LABEL} -mul 0 ${OUTPUT}
  for (( j=0; j<${#labels[@]}; j++ )); do
    lut_values=(${labels[${j}]//,/ })
    label_value=$(( ${j} + 1 ))
    for (( i=0; i<${#lut_values[@]}; i ++ )); do
      fslmaths ${BAW_LABEL} -thr ${lut_values[${i}]} -uthr ${lut_values[${i}]} -bin -mul ${label_value} ${DIR_SCRATCH}/roi_temp.nii.gz
      fslmaths ${OUTPUT} -add ${DIR_SCRATCH}/roi_temp.nii.gz ${OUTPUT}
     rm ${DIR_SCRATCH}/roi_temp.nii.gz
    done
  done
  mv ${OUTPUT} ${DIR_SAVE}/
fi

# Make BASAL GANGLIA label set -----------------------------------------------------------
label_name="basalGanglia"
labels=("11,50" "12,51" "13,52" "26,58")
if [[ "${REDO}" == "true" ]] || [[ ! -f ${DIR_SAVE}/${PREFIX}_baw+${label_name}.nii.gz ]]; then
  OUTPUT=${DIR_SCRATCH}/${PREFIX}_baw+${label_name}.nii.gz
  fslmaths ${BAW_LABEL} -mul 0 ${OUTPUT}
  for (( j=0; j<${#labels[@]}; j++ )); do
    lut_values=(${labels[${j}]//,/ })
    label_value=$(( ${j} + 1 ))
    for (( i=0; i<${#lut_values[@]}; i ++ )); do
      fslmaths ${BAW_LABEL} -thr ${lut_values[${i}]} -uthr ${lut_values[${i}]} -bin -mul ${label_value} ${DIR_SCRATCH}/roi_temp.nii.gz
      fslmaths ${OUTPUT} -add ${DIR_SCRATCH}/roi_temp.nii.gz ${OUTPUT}
     rm ${DIR_SCRATCH}/roi_temp.nii.gz
    done
  done
  mv ${OUTPUT} ${DIR_SAVE}/
fi

# Make SUBCORTICAL label set -----------------------------------------------------------
label_name="subcortical"
labels=("10,49" "28,60" "17,53" "18,54")
if [[ "${REDO}" == "true" ]] || [[ ! -f ${DIR_SAVE}/${PREFIX}_baw+${label_name}.nii.gz ]]; then
  OUTPUT=${DIR_SCRATCH}/${PREFIX}_baw+${label_name}.nii.gz
  fslmaths ${BAW_LABEL} -mul 0 ${OUTPUT}
  for (( j=0; j<${#labels[@]}; j++ )); do
    lut_values=(${labels[${j}]//,/ })
    label_value=$(( ${j} + 1 ))
    for (( i=0; i<${#lut_values[@]}; i ++ )); do
      fslmaths ${BAW_LABEL} -thr ${lut_values[${i}]} -uthr ${lut_values[${i}]} -bin -mul ${label_value} ${DIR_SCRATCH}/roi_temp.nii.gz
      fslmaths ${OUTPUT} -add ${DIR_SCRATCH}/roi_temp.nii.gz ${OUTPUT}
     rm ${DIR_SCRATCH}/roi_temp.nii.gz
    done
  done
  mv ${OUTPUT} ${DIR_SAVE}/
fi

# Make MIDLINE label set -----------------------------------------------------------
label_name="midline"
labels=("251,252,253,254,255" "15071,15072,15073" "16")
if [[ "${REDO}" == "true" ]] || [[ ! -f ${DIR_SAVE}/${PREFIX}_baw+${label_name}.nii.gz ]]; then
  OUTPUT=${DIR_SCRATCH}/${PREFIX}_baw+${label_name}.nii.gz
  fslmaths ${BAW_LABEL} -mul 0 ${OUTPUT}
  for (( j=0; j<${#labels[@]}; j++ )); do
    lut_values=(${labels[${j}]//,/ })
    label_value=$(( ${j} + 1 ))
    for (( i=0; i<${#lut_values[@]}; i ++ )); do
      fslmaths ${BAW_LABEL} -thr ${lut_values[${i}]} -uthr ${lut_values[${i}]} -bin -mul ${label_value} ${DIR_SCRATCH}/roi_temp.nii.gz
      fslmaths ${OUTPUT} -add ${DIR_SCRATCH}/roi_temp.nii.gz ${OUTPUT}
     rm ${DIR_SCRATCH}/roi_temp.nii.gz
    done
  done
  mv ${OUTPUT} ${DIR_SAVE}/
fi

# Make cerebralCortex label set -----------------------------------------------------------
label_name="cerebralCortex"
labels=("3001,4001" "1002,2002,3002,4002" "3003,4003" "1005,2005,3005,4005"\
 "1006,2006,3006,4006" "15162,15163" "1032,2032,3032,4032" "1007,2007,3007,4007"\
 "15160,15161" "1008,2008,3008,4008" "1009,2009,3009,4009" "1035,2035,3035,4035"\
 "1010,2010,3010,4010" "1011,2011,3011,4011" "1012,2012,3012,4012" "1013,2013,3013,4013"\
 "15140,15141" "1014,2014,3014,4014" "15150,15151" "15142,15143" "15144,15145"\
 "1015,2015,3015,4015" "15156,15157" "15164,15165" "1017,2017,3017,4017"\
 "1016,2016,3016,4016" "15174,15175" "1018,2018,3018,4018" "1019,2019,3019,4019"\
 "1020,2020,3020,4020" "1021,2021,3021,4021" "15184,15185" "1022,2022,3022,4022"\
 "3023,4023" "15172,15173" "15178,15179" "1024,2024,3024,4024" "1025,2025,3025,4025"\
 "1026,2026,3026,4026" "1027,2027,3027,4027" "15190,15191" "15194,15195" "15200,15201"\
 "1129,2129" "1028,2028,3028,4028" "1116,2116" "1029,2029,3029,4029" "1030,2030,3030,4030"\
 "15192,15193" "1031,2031,3031,4031" "1033,2033,3033,4033" "1034,2034,3034,4034"\
 "1000,2000" "5001,5002")
if [[ "${REDO}" == "true" ]] || [[ ! -f ${DIR_SAVE}/${PREFIX}_baw+${label_name}.nii.gz ]]; then
  OUTPUT=${DIR_SCRATCH}/${PREFIX}_baw+${label_name}.nii.gz
  fslmaths ${BAW_LABEL} -mul 0 ${OUTPUT}
  for (( j=0; j<${#labels[@]}; j++ )); do
    lut_values=(${labels[${j}]//,/ })
    label_value=$(( ${j} + 1 ))
    for (( i=0; i<${#lut_values[@]}; i ++ )); do
      fslmaths ${BAW_LABEL} -thr ${lut_values[${i}]} -uthr ${lut_values[${i}]} -bin -mul ${label_value} ${DIR_SCRATCH}/roi_temp.nii.gz
      fslmaths ${OUTPUT} -add ${DIR_SCRATCH}/roi_temp.nii.gz ${OUTPUT}
     rm ${DIR_SCRATCH}/roi_temp.nii.gz
    done
  done
  mv ${OUTPUT} ${DIR_SAVE}/
fi

# Make nonbrain label set -----------------------------------------------------------
label_name="nonbrain"
labels=("4" "43" "5" "44" "15" "24" "31" "63" "85" "98" "128" "15000" "15001")
if [[ "${REDO}" == "true" ]] || [[ ! -f ${DIR_SAVE}/${PREFIX}_baw+${label_name}.nii.gz ]]; then
  OUTPUT=${DIR_SCRATCH}/${PREFIX}_baw+${label_name}.nii.gz
  fslmaths ${BAW_LABEL} -mul 0 ${OUTPUT}
  for (( j=0; j<${#labels[@]}; j++ )); do
    lut_values=(${labels[${j}]//,/ })
    label_value=$(( ${j} + 1 ))
    for (( i=0; i<${#lut_values[@]}; i ++ )); do
      fslmaths ${BAW_LABEL} -thr ${lut_values[${i}]} -uthr ${lut_values[${i}]} -bin -mul ${label_value} ${DIR_SCRATCH}/roi_temp.nii.gz
      fslmaths ${OUTPUT} -add ${DIR_SCRATCH}/roi_temp.nii.gz ${OUTPUT}
     rm ${DIR_SCRATCH}/roi_temp.nii.gz
    done
  done
  mv ${OUTPUT} ${DIR_SAVE}/
fi

# Make HEMI label set -----------------------------------------------------------
label_name="hemi"
labels=("4,5,7,8,10,11,12,13,17,18,26,28,31,1000,1002,1005,1006,1007,1008,1009,1010,1011,1012,1013,1014,1015,1016,1017,1018,1019,1020,1021,1022,1024,1025,1026,1027,1028,1029,1030,1031,1032,1033,1034,1035,1116,1129,3001,3002,3003,3005,3006,3007,3008,3009,3010,3011,3012,3013,3014,3015,3016,3017,3018,3019,3020,3021,3022,3023,3024,3025,3026,3027,3028,3029,3030,3031,3032,3033,3034,3035,5001,15141,15143,15145,15151,15157,15161,15163,15165,15173,15175,15179,15185,15191,15193,15195,15201"\
 "43,44,46,47,49,50,51,52,53,54,58,60,63,2000,2002,2005,2006,2007,2008,2009,2010,2011,2012,2013,2014,2015,2016,2017,2018,2019,2020,2021,2022,2024,2025,2026,2027,2028,2029,2030,2031,2032,2033,2034,2035,2116,2129,4001,4002,4003,4005,4006,4007,4008,4009,4010,4011,4012,4013,4014,4015,4016,4017,4018,4019,4020,4021,4022,4023,4024,4025,4026,4027,4028,4029,4030,4031,4032,4033,4034,4035,5002,15140,15142,15144,15150,15156,15160,15162,15164,15172,15174,15178,15184,15190,15192,15194,15200")
if [[ "${REDO}" == "true" ]] || [[ ! -f ${DIR_SAVE}/${PREFIX}_baw+${label_name}.nii.gz ]]; then
  OUTPUT=${DIR_SCRATCH}/${PREFIX}_baw+${label_name}.nii.gz
  fslmaths ${BAW_LABEL} -mul 0 ${OUTPUT}
  for (( j=0; j<${#labels[@]}; j++ )); do
    lut_values=(${labels[${j}]//,/ })
    label_value=$(( ${j} + 1 ))
    for (( i=0; i<${#lut_values[@]}; i ++ )); do
      fslmaths ${BAW_LABEL} -thr ${lut_values[${i}]} -uthr ${lut_values[${i}]} -bin -mul ${label_value} ${DIR_SCRATCH}/roi_temp.nii.gz
      fslmaths ${OUTPUT} -add ${DIR_SCRATCH}/roi_temp.nii.gz ${OUTPUT}
     rm ${DIR_SCRATCH}/roi_temp.nii.gz
    done
  done
  mv ${OUTPUT} ${DIR_SAVE}/
fi

# Make TISSUE label set -----------------------------------------------------------
label_name="tissue"
labels=("8,10,11,12,13,17,18,26,47,49,50,51,52,53,54,58,1000,1002,1005,1006,1007,1008,1009,1010,1011,1012,1013,1014,1015,1016,1017,1018,1019,1020,1021,1022,1024,1025,1026,1027,1028,1029,1030,1031,1032,1033,1034,1035,1116,1129,2000,2002,2005,2006,2007,2008,2009,2010,2011,2012,2013,2014,2015,2016,2017,2018,2019,2020,2021,2022,2024,2025,2026,2027,2028,2029,2030,2031,2032,2033,2034,2035,2116,2129,15071,15072,15073,15140,15141,15142,15143,15144,15145,15150,15151,15156,15157,15160,15161,15162,15163,15164,15165,15172,15173,15174,15175,15178,15179,15184,15185,15190,15191,15192,15193,15194,15195,15200,15201"\
 "7,28,46,60,251,252,253,254,255,3001,3002,3003,3005,3006,3007,3008,3009,3010,3011,3012,3013,3014,3015,3016,3017,3018,3019,3020,3021,3022,3023,3024,3025,3026,3027,3028,3029,3030,3031,3032,3033,3034,3035,4001,4002,4003,4005,4006,4007,4008,4009,4010,4011,4012,4013,4014,4015,4016,4017,4018,4019,4020,4021,4022,4023,4024,4025,4026,4027,4028,4029,4030,4031,4032,4033,4034,4035,5001,5002")
if [[ "${REDO}" == "true" ]] || [[ ! -f ${DIR_SAVE}/${PREFIX}_baw+${label_name}.nii.gz ]]; then
  OUTPUT=${DIR_SCRATCH}/${PREFIX}_baw+${label_name}.nii.gz
  fslmaths ${BAW_LABEL} -mul 0 ${OUTPUT}
  for (( j=0; j<${#labels[@]}; j++ )); do
    lut_values=(${labels[${j}]//,/ })
    label_value=$(( ${j} + 1 ))
    for (( i=0; i<${#lut_values[@]}; i ++ )); do
      fslmaths ${BAW_LABEL} -thr ${lut_values[${i}]} -uthr ${lut_values[${i}]} -bin -mul ${label_value} ${DIR_SCRATCH}/roi_temp.nii.gz
      fslmaths ${OUTPUT} -add ${DIR_SCRATCH}/roi_temp.nii.gz ${OUTPUT}
     rm ${DIR_SCRATCH}/roi_temp.nii.gz
    done
  done
  mv ${OUTPUT} ${DIR_SAVE}/
fi
#===============================================================================
# End of Function
#===============================================================================

# Clean workspace --------------------------------------------------------------
# edit directory for appropriate modality prep folder
rm ${DIR_SCRATCH}/*
rmdir ${DIR_SCRATCH}

# Write log entry on conclusion ------------------------------------------------
if [[ "${NO_LOG}" == "false" ]]; then
  LOG_FILE=${DIR_PROJECT}/log/${PREFIX}.log
  date +"task:$0,start:"${proc_start}",end:%Y-%m-%dT%H:%M:%S%z" >> ${LOG_FILE}
fi

