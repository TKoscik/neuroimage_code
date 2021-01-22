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
OPTS=$(getopt -o hvkl --long prefix:,\
other-inputs:,template:,space:,\
dir-save:,dir-scratch:,\
help,verbose,keep,no-log -n 'parse-options' -- "$@")
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
BG=/Shared/koscikt_scratch/toHOME/HCPYA_700um_T1w.nii.gz
BG_THRESH=0.02,0.98
BG_COLOR="#000000,#ffffff"

ROI=/Shared/koscikt_scratch/toHOME/HCPYA_700um_mask-brain.nii.gz
ROI_LEVELS=1
ROI_COLORS="#c800c8"
ROI_OUTLINE="false"
ROI_THICKNESS=1

OVERLAY=/Shared/koscikt_scratch/toHOME/overlay_masked.nii.gz
OVERLAY_THRESH=0.02,0.98
OVERLAY_COLOR="timbow"

# ------------------------------------------------------------------------------
# 3x5 montage layout, with 5 slices from each plane: 
# row 1: 5 slices in x-plane, row 2: 5 slices in y-plane, row 3: 5 slices in z-plane
# slices are selected according to the formula (TOTAL_SLICES - (CTR_OFFSET*TOTAL_SLICES))/(NSLICES+2)[2:(NSLICES-1)]
# if the CTR_OFFSET is too small or too large, slices out of range will reduce the number of slices included
IMG_LAYOUT="5:x;5:y;5:z"
CTR_OFFSET=0,0,0

# ------------------------------------------------------------------------------
# 3 plane layout:
# a single slice from each plane, offset by 10% from the center
#IMG_LAYOUT="1:x,1:y,1:z"
#CTR_OFFSET=0.1,0.1,0.1

# ------------------------------------------------------------------------------
# single plane montage layout, 5x5 axial: 
# if a plane appears in multiple rows slices will be calculated based on the total number of slices desired from that plane
#IMG_LAYOUT="5:z;5:z;5:z;5:z;5:z"
#CTR_OFFSET=0,0,0

LABEL_SLICE="true"
LABEL_LR="true"
LABEL_CBAR="true"

DIR_SAVE=
DIR_SCRATCH=/Shared/inc_scratch/${OPERATOR}_${DATE_SUFFIX}
HELP=false
VERBOSE=0

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -k | --keep) KEEP=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --other-inputs) OTHER_INPUTS="$2" ; shift 2 ;;
    --template) TEMPLATE="$2" ; shift 2 ;;
    --space) SPACE="$2" ; shift 2 ;;
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
  echo '  --other-inputs <value>   other inputs necessary for function'
  echo '  --template <value>       name of template to use (if necessary),'
  echo '                           e.g., HCPICBM'
  echo '  --space <value>          spacing of template to use, e.g., 1mm'
  echo '  --dir-save <value>       directory to save output, default varies by function'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo ''
  NO_LOG=true
  exit 0
fi

#===============================================================================
# Start of Function
#===============================================================================
# find number of slices in each plane ------------------------------------------
NX=0
NY=0
NZ=0
ROW_LAYOUT=(${IMG_LAYOUT//\;/ })
for (( i=0; i<${#ROW_LAYOUT[@]}; i++ )); do
  COL_LAYOUT=(${ROW_LAYOUT[${i}]//\,/ })
  for (( j=0; j<${#COL_LAYOUT[@]}; j++ )); do
     TEMP=(${COL_LAYOUT[${j}]//\:/ })
     if [[ "${TEMP[1]}" =~ "x" ]]; then NX=$((${NX}+${TEMP[0]})); fi
     if [[ "${TEMP[1]}" =~ "y" ]]; then NY=$((${NY}+${TEMP[0]})); fi
     if [[ "${TEMP[1]}" =~ "z" ]]; then NZ=$((${NZ}+${TEMP[0]})); fi
  done
done
DX=$((${NX}+2))
DX=$(echo "scale=4; 1/${DX}" | bc -l)
X=($(seq 0 ${DX} 1))
X=(${X[@]:1:${NX}})
DY=$((${NY}+2))
DY=$(echo "scale=4; 1/${DY}" | bc -l)
Y=($(seq 0 ${DY} 1))
Y=(${Y[@]:1:${NY}})
DZ=$((${NZ}+2))
DZ=$(echo "scale=4; 1/${DZ}" | bc -l)
Z=($(seq 0 ${DZ} 1))
Z=(${Z[@]:1:${NZ}})

# check if all images in same space

# get slices

fslmaths HCPYA_700um_T2w.nii.gz -thr 15000 -uthr 25000 overlay_masked.nii.gz
overlay 0 0 HCPYA_700um_T1w.nii.gz -a overlay_masked.nii.gz 15000 25000 overlay_render.nii.gz
slicer overlay_render.nii.gz -u -l /Shared/koscikt_scratch/toHOME/timbow.lut -x 0.505 mid_sag.png -y 0.5 mid_cor.png -z 0.5 mid_axi.png
mogrify -font NimbusSans-Regular -fill white -undercolor '#00000000' -pointsize 14 -gravity NorthWest -annotate +10+10 "x=125" mid_sag.png

mogrify -font NimbusSans-Regular -fill white -undercolor '#00000000' -pointsize 14 -gravity NorthWest -annotate +10+10 "y=345" mid_cor.png
mogrify -font NimbusSans-Regular -fill gray250 -undercolor '#00000000' -pointsize 14 -gravity SouthWest -annotate +10+10 "R" mid_cor.png

mogrify -font NimbusSans-Regular -fill white -undercolor '#00000000' -pointsize 14 -gravity NorthWest -annotate +10+10 "z=125" mid_axi.png
mogrify -font NimbusSans-Regular -fill gray50 -undercolor '#00000000' -pointsize 14 -gravity SouthWest -annotate +10+10 "R" mid_axi.png

pngappend mid_sag.png + 0 mid_cor.png + 0 mid_axi.png merged.png

#===============================================================================
# End of Function
#===============================================================================
exit 0


