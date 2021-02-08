#!/bin/bash -e
#===============================================================================
# Make PNG images of brains, suitable for publication.
# -flexible overlay, color, and layout options
# Authors: Timothy R. Koscik, PhD
# Date: 2021-02-04
#===============================================================================
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
    if [[ -n "${DIR_PROJECT}" ]]; then
      ${DIR_INC}/log/logProject.sh --operator ${OPERATOR} \
      --dir-project ${DIR_PROJECT} --pid ${PID} --sid ${SID} \
      --hardware ${HARDWARE} --kernel ${KERNEL} --hpc-q ${HPC_Q} --hpc-slots ${HPC_SLOTS} \
      --fcn-name ${FCN_NAME} --proc-start ${PROC_START} --proc-stop ${PROC_STOP} --exit-code ${EXIT_CODE}
      if [[ -n "${SID}" ]]; then
        ${DIR_INC}/log/logSession.sh --operator ${OPERATOR} \
        --dir-project ${DIR_PROJECT} --pid ${PID} --sid ${SID} \
        --hardware ${HARDWARE} --kernel ${KERNEL} --hpc-q ${HPC_Q} --hpc-slots ${HPC_SLOTS} \
        --fcn-name ${FCN_NAME} --proc-start ${PROC_START} --proc-stop ${PROC_STOP} --exit-code ${EXIT_CODE}
      fi
    fi
    if [[ "${FCN_NAME}" == *"QC"* ]]; then
      ${DIR_INC}/log/logQC.sh --operator ${OPERATOR} \
      --dir-project ${DIR_PROJECT} --pid ${PID} --sid ${SID} --scan-date ${SCAN_DATE} \
      --fcn-name ${FCN_NAME} --proc-start ${PROC_START} --proc-stop ${PROC_STOP} --exit-code ${EXIT_CODE} \
      --notes ${NOTES}
    fi
  fi
}
trap egress EXIT

# Parse inputs -----------------------------------------------------------------
OPTS=$(getopt -o hvl --long \
bg-nii:,bg-mask:,bg-thresh:,bg-color:,bg-direction:,bg-vol:,bg-cbar,\
fg-nii:,fg-mask:,fg-thresh:,fg-color:,fg-direction:,fg-vol:,fg-cbar,\
roi-nii:,roi-levels:,roi-color:,roi-direction:,roi-vol:,roi-cbar,\
image-layout:,ctr-offset:,bg-lim,no-slice-label,label-voxel,no-lr-label,\
color-panel:,color-text:,font-name:,font-size:,max-pixels:,edge-fuzz\
dir-save:,file-name:,keep-slice,keep-cbar,\
dir-scratch:,help,verbose,no-log -n 'parse-options' -- "$@")
if [[ $? != 0 ]]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
BG=
BG_MASK=
BG_THRESH=0,100
BG_COLOR="#010101,#FFFFFF"
BG_ORDER="normal"
BG_CBAR="false"
BG_VOL=1

FG=
FG_MASK=
FG_THRESH=0,100
FG_COLOR="timbow"
FG_ORDER="normal"
FG_CBAR="true"
FG_VOL=1

ROI=
ROI_LEVEL=
ROI_COLOR="#FF69B4"
ROI_ORDER="random"
ROI_CBAR="false"
ROI_VOL=1

LAYOUT=1:x,1:y,1:z
OFFSET=1,0,0
LIMITS=
# LIMITS=("BG", "BG_MASK", "FG", "FG;#", "FG_MASK", "FG_MASK;#", "ROI", "ROI;#", "10,100;13,130;45,150", "NA,NA;NA,NA;10:100")
LABEL_NO_SLICE="false"
LABEL_USE_VOX="false"
LABEL_NO_LR="false"
COLOR_PANEL="#000000"
COLOR_TEXT="#FFFFFF"
FONT_NAME=NimbusSans-Regular
FONT_SIZE=14
MAX_PIXELS=500
EDGE_FUZZ=5

FILE_NAME=
DIR_SAVE=
KEEP_SLICE="false"
KEEP_CBAR="false"
DIR_SCRATCH=${DIR_TMP}/${OPERATOR}_${DATE_SUFFIX}

while true; do
  case "$1" in
    -h | --help) HELP="true" ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -l | --no-log) NO_LOG="true" ; shift ;;
    --bg-nii) BG="$2" ; shift 2 ;;
    --bg-mask) BG_MASK="$2" ; shift 2 ;;
    --bg-thresh) BG_THRESH="$2" ; shift 2 ;;
    --bg-color) BG_COLOR="$2" ; shift 2 ;;
    --bg-order) BG_ORDER="$2" ; shift 2 ;;
    --bg-vol) BG_VOL="$2" ; shift 2 ;;
    --bg-cbar) BG_CBAR="true" ; shift ;;
    --fg-nii) FG="$2" ; shift 2 ;;
    --fg-mask) FG_MASK="$2" ; shift 2 ;;
    --fg-thresh) FG_THRESH="$2" ; shift 2 ;;
    --fg-color) FG_COLOR="$2" ; shift 2 ;;
    --fg-order) FG_ORDER="$2" ; shift 2 ;;
    --fg-vol) FG_VOL="$2" ; shift 2 ;;
    --fg-cbar) FG_CBAR="true" ; shift ;;
    --roi-nii) ROI="$2" ; shift 2 ;;
    --roi-level) ROI_LEVEL="$2" ; shift 2 ;;
    --roi-color) ROI_COLOR="$2" ; shift 2 ;;
    --roi-order) ROI_ORDER="$2" ; shift 2 ;;
    --roi-vol) ROI_VOL="$2" ; shift 2 ;;
    --roi-cbar) ROI_CBAR="true" ; shift 2 ;;
    --layout) LAYOUT="$2" ; shift 2 ;;
    --offset) OFFSET="$2" ; shift 2 ;;
    --limits) LIMITS="$2" ; shift 2 ;;
    --label-noslice) LABEL_NO_SLICE="true" ; shift ;;
    --label-mm) LABEL_USE_VOX="true" ; shift ;;
    --label-lr) LABEL_NO_LR="true" ; shift ;;
    --color-panel) COLOR_PANEL="$2" ; shift 2 ;;
    --color-text) COLOR_TEXT="$2" ; shift 2 ;;
    --font-name) FONT_NAME="$2" ; shift 2 ;;
    --font-size) FONT_SIZE="$2" ; shift 2 ;;
    --max-pixels) MAX_PIXELS="$2" ; shift 2 ;;
    --edge-fuzz) EDGE_FUZZ="$2" ; shift 2 ;;
    --file-name) FILE_NAME="$2" ; shift 2 ;;
    --dir-save) DIR_SAVE="$2" ; shift 2 ;;
    --dir-scratch) DIR_SCRATCH="$2" ; shift 2 ;;
    --keep-slice) KEEP_SLICE="true" ; shift ;;
    --keep-cbar) KEEP_CBAR="true" ; shift ;;
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
  echo '  -l | --no-log            disable writing to output log'
  echo '  --layout                 a string identifying the number of'
  echo '                           slices, slice plane, rows and columns'
  echo '    Layouts are specifed by using delimiters:'
  echo '    (;) row delimiter'
  echo '    (,) column delimiter'
  echo '    (:) number and plane delimiter'
  echo '        Applied in row -> column -> plane order'
  echo '    See examples below'
  echo '  --dir-save <value>       directory to save output'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo ''
  echo ' Example Layouts:'
  echo ' (1) 3 slices, 1 from each plane in a horizontal array:'
  echo '     offset 1 slice from center'
  echo '     >>  --layout 1:x,1:y,1:z'
  echo '     >>  --offset 1,1,1'
  echo ' (2) single plane, 5x5 axial montage layout:'
  echo '     >>  --layout 5:z;5:z;5:z;5:z;5:z'
  echo '     >>  --offset 0,0,0'
  echo ' (3) 3x5 montage layout, single plane in each row:'
  echo '     - row 1: 5 slices in x-plane'
  echo '     - row 2: 5 slices in y-plane'
  echo '     - row 3: 5 slices in z-plane'
  echo '     >>  --layout 5:x;5:y;5:z'
  echo '     >>  --offset 0,0,0'
  NO_LOG=true
  exit 0
fi

#===============================================================================
# Start of Function
#===============================================================================
# set default filename
DIR_PROJECT=$(${DIR_INC}/bids/get_dir.sh -i ${BG})
PID=$(${DIR_INC}/bids/get_field.sh -i ${BG} -f sub)
SID=$(${DIR_INC}/bids/get_field.sh -i ${BG} -f ses)
if [[ -z "${FILE_NAME}" ]]; then
  if [[ -n "${PID}" ]]; then
    FILE_NAME="sub-${PID}"
    if [[ -n "${SID}" ]]; then
      FILE_NAME="${FILE_NAME}_ses-${SID}"
    fi
  else
    FILE_NAME="overlay"
  fi
  FILE_NAME="${FILE_NAME}_${DATE_SUFFIX}"
fi

# set default save directory
if [[ -n "${DIR_SAVE}" ]]; then
  DIR_SAVE=${DIR_PROJECT}/overlay_png
fi
mkdir -p ${DIR_SAVE}

# parse parameters for FG and ROIs ---------------------------------------------
FG=(${FG//;/ })
FG_MASK=(${FG_MASK//;/ })
FG_THRESH=(${FG_THRESH//;/ })
FG_COLOR=(${FG_COLOR//;/ })
FG_ORDER=(${FG_COLOR_ORDER//;/ })
FG_CBAR=(${FG_CBAR//;/ })

ROI=(${ROI//;/ })
ROI_LEVEL=(${ROI_LEVEL//;/ })
ROI_COLOR=(${ROI_COLOR//;/ })
ROI_ORDER=(${ROI_ORDER//;/ })
ROI_CBAR=(${ROI_CBAR//;/ })

OFFSET=(${OFFSET//,/ })

# Get image informtation -------------------------------------------------------
unset DIMS PIXDIM ORIGIN ORIENT
DIMS=($(${DIR_INC}/generic/nii_info.sh -i ${BG} -f voxels))
PIXDIM=($(${DIR_INC}/generic/nii_info.sh -i ${BG} -f spacing))
ORIGIN=($(${DIR_INC}/generic/nii_info.sh -i ${BG} -f origin))
ORIENT=($(${DIR_INC}/generic/nii_info.sh -i ${BG} -f orient))

## use mm only if image is in known standard space -----------------------------
if [[ "${LABEL_NO_SLICE}" == "false" ]] &&
   [[ "${LABEL_USE_VOX}" == "false" ]]; then
  LABEL_USE_VOX="true"
  MSG="MESSAGE [INC:${FCN_NAME}] using voxel coordinate labels"
  STD_LS=($(ls ${DIR_TEMPLATE}))
  for (( i=0; i<${#STD_LS[@]}; i++ )); do
    if [[ "${BG}" == *"${STD_LS[${i}]}"* ]]; then
      LABEL_USE_VOX="false"
      MSG="MESSAGE [INC:${FCN_NAME}] using mm coordinate labels"
      break
    fi
  done
fi
if [[ "${VERBOSE}" == "1" ]]; then echo ${MSG}; fi

# Figure out number slices for each orientation --------------------------------
### *** is PLANE useful and necessary?
NX=0; NY=0; NZ=0
ROW_LAYOUT=(${LAYOUT//\;/ })
for (( i=0; i<${#ROW_LAYOUT[@]}; i++ )); do
  COL_LAYOUT=(${ROW_LAYOUT[${i}]//\,/ })
  for (( j=0; j<${#COL_LAYOUT[@]}; j++ )); do
    TEMP=(${COL_LAYOUT[${j}]//\:/ })
    if [[ "${TEMP[1]}" =~ "x" ]]; then
      NX=$((${NX}+${TEMP[0]}))
      PLANE+=("X")
    fi
    if [[ "${TEMP[1]}" =~ "y" ]]; then
      NY=$((${NY}+${TEMP[0]}))
      PLANE+=("Y")
    fi
    if [[ "${TEMP[1]}" =~ "z" ]]; then
      NZ=$((${NZ}+${TEMP[0]}))
      PLANE+=("Z")
    fi
  done
done

# Calculate slices to plot =====================================================
# parse variable to determine image limits ------------------------------------
if [[ -z "${LIMITS}" ]]; then
  if [[ -n ${ROI} ]]; then 
    LIM_CHK=(${LIM_CHK[@]} ${ROI[@]})
  elif [[ -n ${FG_MASK} ]]; then
    LIM_CHK=(${LIM_CHK[@]} ${FG_MASK[@]})    
  elif [[ -n ${FG} ]]; then
    LIM_CHK=(${LIM_CHK[@]} ${FG[@]})
  elif [[ -n ${BG_MASK} ]]; then
    LIM_CHK=(${LIM_CHK[@]} ${BG_MASK})
  else
    LIM_CHK=(${LIM_CHK[@]} ${BG})
  fi
elif [[ "${LIMITS^^}" == "BG" ]]; then
  LIM_CHK=(${LIM_CHK[@]} ${BG})
elif [[ "${LIMITS^^}" == "BG_MASK" ]]; then
  LIM_CHK=(${LIM_CHK[@]} ${BG_MASK})
elif [[ "${LIMITS^^}" == *"FG"* ]]; then
  TEMP=(${LIMITS//;/ })
  if [[ "${TEMP[0]}" == "FG" ]]; then
    LIM_CHK=(${LIM_CHK[@]} ${FG[@]})
  elif  [[ "${TEMP[0]}" == "FG_MASK" ]]; then
    LIM_CHK=(${LIM_CHK[@]} ${FG_MASK[@]})
  fi
  if [[ ${#TEMP[@]} -gt 1 ]]; then
    LIM_CHK=${LIM_CHK[${#TEMP[@]}]}
  fi
elif [[ "${LIMITS^^}" == *"ROI"* ]]; then
  TEMP=(${LIMITS//;/ })
  LIM_CHK=(${LIM_CHK[@]} ${FG[@]})
  if [[ ${#TEMP[@]} -gt 1 ]]; then
    LIM_CHK=${LIM_CHK[${#TEMP[@]}]}
  fi
else
  LIMITS_TEMP=(${LIMITS//;/ })
fi

## calculate slices in each plane ----------------------------------------------
## (1) find bounding box within image
## (2) add in desired offset
## (3) constrain limits to image boundaries
## (4) calculate slices to use
### (4a) get edge slices if possible, and toss to avoid edges of image/roi
### (4b) constrain to desired slice number, or fewer if slices unavailable
## (5) convert to percentage of image width for FSL slicer

## (1) find bounding box within image - - - - - - - - - - - - - - - - - - - - -
unset XLIM YLIM ZLIM
XLIM=(9999 0)
YLIM=(9999 0)
ZLIM=(9999 0)
if [[ -n "${LIM_CHK}" ]]; then
  for (( i=0; i<${#LIM_CHK[@]}; i++ )); do
    unset BB_STR BB
    BB_STR=$(3dAutobox -extent -input ${LIM_CHK[${i}]} 2>&1)
    BBX=$(echo ${BB_STR} | sed -e 's/.*x=\(.*\) y=.*/\1/')
    BBY=$(echo ${BB_STR} | sed -e 's/.*y=\(.*\) z=.*/\1/')
    BBZ=$(echo ${BB_STR} | sed -e 's/.*z=\(.*\) Extent.*/\1/')
    #'#************************************remove prevents bad code highlighting
    BBX=(${BBX//../ });
    BBY=(${BBY//../ });
    BBZ=(${BBZ//../ });
    if [[ ${BBX[0]} -lt ${XLIM[0]} ]]; then XLIM[0]=${BBX[0]}; fi
    if [[ ${BBX[1]} -gt ${XLIM[1]} ]]; then XLIM[1]=${BBX[1]}; fi
    if [[ ${BBY[0]} -lt ${YLIM[0]} ]]; then YLIM[0]=${BBY[0]}; fi
    if [[ ${BBY[1]} -gt ${YLIM[1]} ]]; then YLIM[1]=${BBY[1]}; fi
    if [[ ${BBZ[0]} -lt ${ZLIM[0]} ]]; then ZLIM[0]=${BBZ[0]}; fi
    if [[ ${BBZ[1]} -gt ${ZLIM[1]} ]]; then ZLIM[1]=${BBZ[1]}; fi
  done
else
  XLIM=(${LIMITS_TEMP[0]//,/ })
  YLIM=(${LIMITS_TEMP[1]//,/ })
  ZLIM=(${LIMITS_TEMP[2]//,/ })
fi

## calculate X slices - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
if [[ ${NX} > 0 ]]; then
  unset XVOX XPCT RANGE TN STEP

  XLIM[0]=$((${XLIM[0]}+${OFFSET[0]}))
  XLIM[1]=$((${XLIM[1]}+${OFFSET[0]}))
  if [[ ${XLIM[0]} -lt 1 ]]; then ${XLIM[0]}=1; fi
  if [[ ${XLIM[1]} -gt ${DIMS[0]} ]]; then ${XLIM[1]}=${DIMS[0]}; fi
  
  RANGE=$((${XLIM[1]}-${XLIM[0]}))
  TN=$((${NX}+1))
  STEP=1
  if [[ ${RANGE} -gt ${TN} ]]; then STEP=$((${RANGE}/${TN})); fi
  XVOX=($(seq ${XLIM[0]} ${STEP} ${XLIM[1]}))
  if [[ ${#XVOX[@]} -gt ${NX} ]]; then
    XVOX=(${XVOX[@]:1:${NX}})
  fi
  NX=${#XVOX[@]}
  
  for (( i=0; i<${NX}; i++ )); do
    XPCT+=($(echo "scale=4; ${XVOX[${i}]}/${DIMS[0]}" | bc -l))
  done
fi

## calculate Y slices - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
if [[ ${NY} > 0 ]]; then
  unset YVOX YPCT RANGE STEP TN

  YLIM[0]=$((${YLIM[0]}+${OFFSET[1]}))
  YLIM[1]=$((${YLIM[1]}+${OFFSET[1]}))
  if [[ ${YLIM[0]} -lt 1 ]]; then ${YLIM[1]}=1; fi
  if [[ ${YLIM[1]} -gt ${DIMS[1]} ]]; then ${YLIM[1]}=${DIMS[1]}; fi
  
  RANGE=$((${YLIM[1]}-${YLIM[0]}))
  TN=$((${NY}+1))
  STEP=1
  if [[ ${RANGE} -gt ${TN} ]]; then STEP=$((${RANGE}/${TN})); fi
  YVOX=($(seq ${YLIM[0]} ${STEP} ${YLIM[1]}))
  if [[ ${#YVOX[@]} -gt ${NY} ]]; then
    YVOX=(${YVOX[@]:1:${NY}})
  fi
  NX=${#YVOX[@]}
  
  for (( i=0; i<${NY}; i++ )); do
    YPCT+=($(echo "scale=4; ${YVOX[${i}]}/${DIMS[1]}" | bc -l))
  done
fi

## calculate Z slices - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
if [[ ${NZ} > 0 ]]; then
  unset ZVOX ZPCT RANGE STEP TN

  ZLIM[0]=$((${ZLIM[0]}+${OFFSET[2]}))
  ZLIM[1]=$((${ZLIM[1]}+${OFFSET[2]}))
  if [[ ${ZLIM[0]} -lt 1 ]]; then ${ZLIM[2]}=1; fi
  if [[ ${ZLIM[1]} -gt ${DIMS[2]} ]]; then ${ZLIM[1]}=${DIMS[2]}; fi

  RANGE=$((${ZLIM[1]}-${ZLIM[0]}))
  TN=$((${NZ}+1))
  STEP=1
  if [[ ${RANGE} -gt ${TN} ]]; then STEP=$((${RANGE}/${TN})); fi
  ZVOX=($(seq ${ZLIM[0]} ${STEP} ${ZLIM[1]}))
  if [[ ${#ZVOX[@]} -gt ${NZ} ]]; then
    ZVOX=(${ZVOX[@]:1:${NZ}})
  fi
  NZ=${#ZVOX[@]}

  for (( i=0; i<${NZ}; i++ )); do
    ZPCT+=($(echo "scale=4; ${ZVOX[${i}]}/${DIMS[2]}" | bc -l))
  done
fi

#===============================================================================
# check if all images in same space --------------------------------------------
FIELD_CHK="dim,pixdim,quatern_b,quatern_c,quatern_d,qoffset_x,qoffset_y,qoffset_z,srow_x,srow_y,srow_z"
if [[ -n ${BG_MASK} ]]; then
  unset SPACE_CHK
  SPACE_CHK=$(${DIR_INC}/generic/nii_compare.sh -i ${BG} -j ${BG_MASK} -f ${FIELD_CHK})
  if [[ "${SPACE_CHK}" == "false" ]]; then
    antsApplyTransforms -d 3 -n GenericLabel \
      -i ${BG_MASK} -o ${DIR_SCRATCH}/BG_mask.nii.gz -r ${BG}
    BG_MASK="${DIR_SCRATCH}/BG_mask.nii.gz"
  fi
fi
if [[ -n ${FG} ]]; then
  for (( i=0; i<${#FG[@]}; i++ )); do
    unset SPACE_CHK
    SPACE_CHK=$(${DIR_INC}/generic/nii_compare.sh -i ${BG} -j ${FG[${i}]} -f ${FIELD_CHK})
    if [[ "${SPACE_CHK}" == "false" ]]; then
      antsApplyTransforms -d 3 -n Linear \
        -i ${FG[${i}]} -o ${DIR_SCRATCH}/FG_${i}.nii.gz -r ${BG}
      FG[${i}]="${DIR_SCRATCH}/FG_${i}.nii.gz"
    fi
  done
fi
if [[ -n ${FG_MASK} ]]; then
  for (( i=0; i<${#FG_MASK[@]}; i++ )); do
    unset SPACE_CHK
    SPACE_CHK=$(${DIR_INC}/generic/nii_compare.sh -i ${BG} -j ${FG_MASK[${i}]} -f ${FIELD_CHK})
    if [[ "${SPACE_CHK}" == "false" ]]; then
      antsApplyTransforms -d 3 -n GenericLabel \
        -i ${FG_MASK[${i}]} -o ${DIR_SCRATCH}/FG_mask-${i}.nii.gz -r ${BG}
      FG_MASK[${i}]="${DIR_SCRATCH}/FG_mask-${i}.nii.gz"
    fi
  done
fi
if [[ -n ${ROI} ]]; then
  for (( i=0; i<${#ROI[@]}; i++ )); do
    unset SPACE_CHK
    SPACE_CHK=$(${DIR_INC}/generic/nii_compare.sh -i ${BG} -j ${ROI[${i}]} -f ${FIELD_CHK})
    if [[ "${SPACE_CHK}" == "false" ]]; then
      antsApplyTransforms -d 3 -n MultiLabel \
        -i ${ROI[${i}]} -o ${DIR_SCRATCH}/ROI_${i}.nii.gz -r ${BG}
      ROI[${i}]="${DIR_SCRATCH}/ROI_${i}.nii.gz"
    fi
  done
fi

# Make Background ==============================================================
HILO=(${BG_THRESH//,/ })
if [[ -n ${BG_MASK} ]]; then
  LO=$(fslstats -K ${BG_MASK} ${BG} -p ${HILO[0]})
  HI=$(fslstats -K ${BG_MASK} ${BG} -p ${HILO[1]})
else
  LO=$(fslstats ${BG} -p ${HILO[0]})
  HI=$(fslstats ${BG} -p ${HILO[1]})
fi

## apply mask
if [[ -n ${BG_MASK} ]]; then
  fslmaths ${BG} -mas ${BG_MASK} ${DIR_SCRATCH}/BG.nii.gz
  BG=${DIR_SCRATCH}/BG.nii.gz
fi

## generate color bar
Rscript ${DIR_INC}/export/make_colors.R \
  "palette" ${BG_COLOR} \
  "n" "200" \
  "order" ${BG_ORDER} \
  "bg" ${COLOR_PANEL} \
  "dir.save" ${DIR_SCRATCH} \
  "prefix" "CBAR_BG"

### add labels to color bar
if [[ "${BG_CBAR}" == "true" ]]; then
  TTXT=$(printf "%0.2f\n" ${LO})
  mogrify -font ${FONT_NAME} -pointsize ${FONT_SIZE} \
    -fill "${COLOR_TEXT}" -undercolor "${COLOR_PANEL}" \
    -gravity Center -annotate 90x90+0+225 "${TTXT}" \
    ${DIR_SCRATCH}/CBAR_BG.png
  TTXT=$(printf "%0.2f\n" ${HI})
  mogrify -font ${FONT_NAME} -pointsize ${FONT_SIZE} \
    -fill "${COLOR_TEXT}" -undercolor "${COLOR_PANEL}" \
    -gravity Center -annotate 90x90+0-225 "${TTXT}" \
    ${DIR_SCRATCH}/CBAR_BG.png
fi

## generate slice PNGs
slice_fcn="slicer ${BG} -u -l ${DIR_SCRATCH}/CBAR_BG.lut -i ${LO} ${HI}"
for (( i=0; i<${NX}; i++ )); do
  slice_fcn="${slice_fcn} -x ${XPCT[${i}]} ${DIR_SCRATCH}/X${i}.png"
done
for (( i=0; i<${NY}; i++ )); do
  slice_fcn="${slice_fcn} -y ${YPCT[${i}]} ${DIR_SCRATCH}/Y${i}.png"
done
for (( i=0; i<${NZ}; i++ )); do
  slice_fcn="${slice_fcn} -z ${ZPCT[${i}]} ${DIR_SCRATCH}/Z${i}.png"
done
eval ${slice_fcn}

# post processing on slices ---------------
## (1) resample slices to have max dimension of 500 pixels
## (2) recolor background as necessary
## *****this should be replaced with utilization of the background mask to control the transparency, such that dark patches are not accidentally made transparent
for (( i=0; i<${NX}; i++ )); do
  convert ${DIR_SCRATCH}/X${i}.png -resize ${MAX_PIXELS}x${MAX_PIXELS} ${DIR_SCRATCH}/X${i}.png
  if [[ "${COLOR_PANEL}" != "#000000" ]]; then
    mogrify -fill "${COLOR_PANEL}" -opaque "#000000" ${DIR_SCRATCH}/X${i}.png
  fi
done
for (( i=0; i<${NY}; i++ )); do
  convert ${DIR_SCRATCH}/Y${i}.png -resize ${MAX_PIXELS}x${MAX_PIXELS} ${DIR_SCRATCH}/Y${i}.png
  if [[ "${COLOR_PANEL}" != "#000000" ]]; then
    mogrify -fill "${COLOR_PANEL}" -opaque "#000000" ${DIR_SCRATCH}/Y${i}.png
  fi
done
for (( i=0; i<${NZ}; i++ )); do
  convert ${DIR_SCRATCH}/Z${i}.png -resize ${MAX_PIXELS}x${MAX_PIXELS} ${DIR_SCRATCH}/Z${i}.png
  if [[ "${COLOR_PANEL}" != "#000000" ]]; then
    mogrify -fill "${COLOR_PANEL}" -opaque "#000000" ${DIR_SCRATCH}/Z${i}.png
  fi
done

# Add Foreground Overlays ======================================================
if [[ -n ${FG} ]]; then
  for (( i=0; i<${#FG[@]}; i++ )); do
    unset HILO LO HI
    HILO=(${FG_THRESH[${i}]//,/ })
    if [[ -z ${FG_MASK} ]] || [[ "${FG_MASK[${i}]}" != "null" ]]; then
      LO=$(fslstats ${BG} -p ${HILO[0]})
      HI=$(fslstats ${BG} -p ${HILO[1]})
    else
      LO=$(fslstats -K ${BG_MASK} ${BG} -p ${HILO[0]})
      HI=$(fslstats -K ${BG_MASK} ${BG} -p ${HILO[1]})
    fi

    ## apply mask
    if [[ -n ${FG_MASK} ]] && [[ "${FG_MASK[${i}]}" != "null" ]]; then
      fslmaths ${FG[${i}]} -mas ${FG_MASK[${i}]} ${DIR_SCRATCH}/FG_${i}.nii.gz
      FG[${i}]=${DIR_SCRATCH}/FG_${i}.nii.gz
    fi

    ## generate color bar
    Rscript ${DIR_INC}/export/make_colors.R \
      "palette" ${FG_COLOR[${i}]} \
      "n" 200 \
      "order" ${FG_ORDER[${i}]} \
      "bg" ${COLOR_PANEL} \
      "dir.save" ${DIR_SCRATCH} \
      "prefix" "CBAR_FG_${i}"
  
    ### add labels to color bar
    if [[ "${BG_CBAR}" == "true" ]]; then
      TTXT=$(printf "%0.2f\n" ${LO})
      mogrify -font ${FONT_NAME} -pointsize ${FONT_SIZE} \
        -fill "${COLOR_TEXT}" -undercolor "${COLOR_PANEL}" \
        -gravity Center -annotate 90x90+0+225 "${TTXT}" \
        ${DIR_SCRATCH}/CBAR_FG_${i}.png
      TTXT=$(printf "%0.2f\n" ${HI})
      mogrify -font ${FONT_NAME} -pointsize ${FONT_SIZE} \
        -fill "${COLOR_TEXT}" -undercolor "${COLOR_PANEL}" \
        -gravity Center -annotate 90x90+0-225 "${TTXT}" \
        ${DIR_SCRATCH}/CBAR_FG_${i}.png
    fi

    ## generate slice PNGs - - - - - - - - - - - - - - - - - - - - - - - - - - -
    slice_fcn="slicer ${FG[${i}]}"
    slice_fcn="${slice_fcn} -u "
    slice_fcn="${slice_fcn} -l ${DIR_SCRATCH}/CBAR_FG_${i}.lut"
    slice_fcn="${slice_fcn} -i ${LO} ${HI}"
    for (( j=0; j<${NX}; j++ )); do
      slice_fcn="${slice_fcn} -x ${XPCT[${j}]} ${DIR_SCRATCH}/X${j}_FG_${i}.png"
    done
    for (( j=0; j<${NY}; j++ )); do
      slice_fcn="${slice_fcn} -y ${YPCT[${i}]} ${DIR_SCRATCH}/Y${j}_FG_${i}.png"
    done
    for (( j=0; j<${NZ}; j++ )); do
      slice_fcn="${slice_fcn} -z ${ZPCT[${i}]} ${DIR_SCRATCH}/Z${j}_FG_${i}.png"
    done
    eval ${slice_fcn}

    ## set background transparency and overlay on background - - - - - - - - - -
    for (( j=0; j<${NX}; j++ )); do
      convert ${DIR_SCRATCH}/X${j}_FG_${i}.png \
        -resize ${MAX_PIXELS} ${DIR_SCRATCH}/X${j}_FG_${i}.png
      convert ${DIR_SCRATCH}/X${j}_FG_${i}.png \
        -transparent "${COLOR_PANEL}" -transparent "#000000" \
        ${DIR_SCRATCH}/X${j}_FG_${i}.png 
      composite ${DIR_SCRATCH}/X${j}_FG_${i}.png \
        ${DIR_SCRATCH}/X${j}.png \
        ${DIR_SCRATCH}/X${j}.png     
    done
    for (( j=0; j<${NY}; j++ )); do
      convert ${DIR_SCRATCH}/Y${j}_FG_${i}.png \
        -resize ${MAX_PIXELS} ${DIR_SCRATCH}/Y${j}_FG_${i}.png
      convert ${DIR_SCRATCH}/Y${j}_FG_${i}.png \
        -transparent "${COLOR_PANEL}" -transparent "#000000" \
        ${DIR_SCRATCH}/Y${j}_FG_${i}.png 
      composite ${DIR_SCRATCH}/Y${j}_FG_${i}.png \
        ${DIR_SCRATCH}/Y${j}.png \
        ${DIR_SCRATCH}/Y${j}.png  
    done
    for (( j=0; j<${NZ}; j++ )); do
      convert ${DIR_SCRATCH}/Z${j}_FG_${i}.png \
        -resize ${MAX_PIXELS} ${DIR_SCRATCH}/Z${j}_FG_${i}.png
      convert ${DIR_SCRATCH}/Z${j}_FG_${i}.png \
        -transparent "${COLOR_PANEL}" \
        -transparent "#000000" \
        ${DIR_SCRATCH}/Z${j}_FG_${i}.png 
      composite ${DIR_SCRATCH}/Z${j}_FG_${i}.png \
        ${DIR_SCRATCH}/Z${j}.png \
        ${DIR_SCRATCH}/Z${j}.png   
    done
  done
fi

# Add ROI ======================================================================
if [[ -n ${ROI} ]]; then
  ROI_MERGE=${DIR_SCRATCH}/ROI.nii.gz
  fslmaths ${BG} -thr 0 -uthr 0 ${ROI_MERGE}
  for (( i=0; i<${#ROI[@]}; i++ )); do
  ROI_N=0
  for (( i=0; i<${#ROI[@]}; i++ )); do
    unset ROI_VALS TVALS
    TEMP_ROI_LS=(${ROI_LEVEL[${i}]//,/ })
    for (( j=0; j<${#TEMP_ROI_LS[@]}; j++ )); do
      unset TEMP_ROI_VALS
      TEMP_ROI_VALS=(${TEMP_ROI_LS[${j}]//\:/ }) 
      if [[ ${#TEMP_ROI_VALS[@]} -gt 1 ]]; then
        ROI_VALS+=($(seq ${TEMP_ROI_VALS[0]} ${TEMP_ROI_VALS[1]}))
      else
        ROI_VALS+=(${TEMP_ROI_VALS[0]})
      fi
    done
    
    for (( j=0; j<${#ROI_VALS[@]}; j++ )); do
      ROI_N=$((${ROI_N}+1))
      fslmaths ${ROI[${i}]} -thr ${ROI_VALS[${j}]} -uthr ${ROI_VALS[${j}]} \
        -bin -mul ${ROI_N} ${DIR_SCRATCH}/ROI_temp.nii.gz
      fslmaths ${DIR_SCRATCH}/ROI_temp.nii.gz \
        -edge -bin ${DIR_SCRATCH}/ROI_mask-edge.nii.gz
      fslmaths ${DIR_SCRATCH}/ROI_temp.nii.gz \
        -mas ${DIR_SCRATCH}/ROI_mask-edge.nii.gz \
        -add ${ROI_MERGE} ${ROI_MERGE}
    done
  done
fi

## generate color bar
Rscript ${DIR_INC}/export/make_colors.R \
  "palette" ${ROI_COLOR} \
  "n" ${ROI_N} \
  "order" ${ROI_ORDER} \
  "bg" ${COLOR_PANEL} \
  "dir.save" ${DIR_SCRATCH} \
  "prefix" "CBAR_ROI"

slice_fcn="slicer ${ROI_MERGE} -u -l ${DIR_SCRATCH}/CBAR_ROI.lut -i 0 ${ROI_N}"
for (( i=0; i<${NX}; i++ )); do
  slice_fcn="${slice_fcn} -x ${XPCT[${i}]} ${DIR_SCRATCH}/X${i}_ROI.png"
done
for (( i=0; i<${NY}; i++ )); do
  slice_fcn="${slice_fcn} -y ${YPCT[${i}]} ${DIR_SCRATCH}/Y${i}_ROI.png"
done
for (( i=0; i<${NZ}; i++ )); do
  slice_fcn="${slice_fcn} -z ${ZPCT[${i}]} ${DIR_SCRATCH}/Z${i}_ROI.png"
done
eval ${slice_fcn}

for (( i=0; i<${NX}; i++ )); do
  convert ${DIR_SCRATCH}/X${i}_ROI.png \
    -resize ${MAX_PIXELS} ${DIR_SCRATCH}/X${i}_ROI.png
  convert ${DIR_SCRATCH}/X${i}_ROI.png \
    -transparent "${COLOR_PANEL}" -transparent "#000000" \
    ${DIR_SCRATCH}/X${i}_ROI.png 
  composite ${DIR_SCRATCH}/X${i}_ROI.png \
    ${DIR_SCRATCH}/X${i}.png \
    ${DIR_SCRATCH}/X${i}.png     
done
for (( i=0; i<${NY}; i++ )); do
  convert ${DIR_SCRATCH}/Y${i}_ROI.png \
    -resize ${MAX_PIXELS} ${DIR_SCRATCH}/Y${i}_ROI.png
  convert ${DIR_SCRATCH}/Y${i}_ROI.png \
    -transparent "${COLOR_PANEL}" -transparent "#000000" \
    ${DIR_SCRATCH}/Y${i}_ROI.png 
  composite ${DIR_SCRATCH}/Y${i}_ROI.png \
    ${DIR_SCRATCH}/Y${i}.png \
    ${DIR_SCRATCH}/Y${i}.png  
done
for (( i=0; i<${NZ}; i++ )); do
  convert ${DIR_SCRATCH}/Z${i}_ROI.png \
    -resize ${MAX_PIXELS} ${DIR_SCRATCH}/Z${i}_ROI.png
  convert ${DIR_SCRATCH}/Z${i}_ROI.png \
    -transparent "${COLOR_PANEL}" \
    -transparent "#000000" \
    ${DIR_SCRATCH}/Z${i}_ROI.png 
  composite ${DIR_SCRATCH}/Z${i}_ROI.png \
    ${DIR_SCRATCH}/Z${i}.png \
    ${DIR_SCRATCH}/Z${i}.png   
done

# Add labels after FG and ROIs are composited
for (( i=0; i<${NX}; i++ )); do
  if [[ "${LABEL_NO_SLICE}" == "false" ]]; then
    if [[ "${LABEL_USE_VOX}" == "false" ]]; then
      LABEL_X=$(echo "scale=2; ${ORIGIN[0]}/${PIXDIM[0]}" | bc -l)
      LABEL_X=$(echo "scale=2; ${LABEL_X}-${XVOX[${i}]}" | bc -l)
      LABEL_X=$(echo "scale=2; ${LABEL_X}*${PIXDIM[0]}" | bc -l)
      LABEL_X="${LABEL_X}mm"
    else
      LABEL_X=${XVOX[${i}]}
    fi
    LABEL_X="x=${LABEL_X}"
    mogrify -font ${FONT_NAME} -pointsize ${FONT_SIZE} \
      -fill "${COLOR_TEXT}" -undercolor "${COLOR_PANEL}" \
      -gravity NorthWest -annotate +10+10 "${LABEL_X}" \
      ${DIR_SCRATCH}/X${i}.png
  fi
done
for (( i=0; i<${NY}; i++ )); do
  if [[ "${LABEL_NO_SLICE}" == "false" ]]; then
    if [[ "${LABEL_USE_VOX}" == "false" ]]; then
      LABEL_Y=$(echo "scale=2; ${ORIGIN[1]}/${PIXDIM[1]}" | bc -l)
      LABEL_Y=$(echo "scale=2; ${LABEL_Y}-${YVOX[${i}]}" | bc -l)
      LABEL_Y=$(echo "scale=2; ${LABEL_Y}*${PIXDIM[1]}" | bc -l)
      LABEL_Y="${LABEL_Y}mm"
    else
      LABEL_Y=${YVOX[${i}]}
    fi
    LABEL_Y="y=${LABEL_Y}"
    mogrify -font ${FONT_NAME} -pointsize ${FONT_SIZE} \
      -fill "${COLOR_TEXT}" -undercolor "${COLOR_PANEL}" \
      -gravity NorthWest -annotate +10+10 "${LABEL_Y}" \
      ${DIR_SCRATCH}/Y${i}.png
  fi
done
for (( i=0; i<${NX}; i++ )); do
  if [[ "${LABEL_NO_SLICE}" == "false" ]]; then
    if [[ "${LABEL_USE_VOX}" == "false" ]]; then
      LABEL_Z=$(echo "scale=2; ${ORIGIN[2]}/${PIXDIM[2]}" | bc -l)
      LABEL_Z=$(echo "scale=2; ${LABEL_Z}-${ZVOX[${i}]}" | bc -l)
      LABEL_Z=$(echo "scale=2; ${LABEL_Z}*${PIXDIM[2]}" | bc -l)
      LABEL_Z="${LABEL_Z}mm"
    else
      LABEL_Z=${ZVOX[${i}]}
    fi
    LABEL_Z="z=${LABEL_Z}"
    mogrify -font ${FONT_NAME} -pointsize ${FONT_SIZE} \
      -fill "${COLOR_TEXT}" -undercolor "${COLOR_PANEL}" \
      -gravity NorthWest -annotate +10+10 "${LABEL_Z}" \
      ${DIR_SCRATCH}/Z${i}.png
  fi
done

# merge PNGs according to prescribed layout ====================================
# add laterality label if desired ----------------------------------------------
XCOUNT=0
YCOUNT=0
ZCOUNT=0
ROW_LAYOUT=(${LAYOUT//\;/ })
for (( i=0; i<${#ROW_LAYOUT[@]}; i++ )); do
  COL_LAYOUT=(${ROW_LAYOUT[${i}]//\,/ })
  montage_fcn="montage"    
  for (( j=0; j<${#COL_LAYOUT[@]}; j++ )); do
     TEMP=(${COL_LAYOUT[${j}]//\:/ })
     if [[ "${TEMP[1]}" =~ "x" ]]; then
       for (( k=0; k<${TEMP[0]}; k++ )); do
         montage_fcn="${montage_fcn} ${DIR_SCRATCH}/X${XCOUNT}.png"
         XCOUNT=$((${XCOUNT}+1))
       done
     fi
     if [[ "${TEMP[1]}" =~ "y" ]]; then
       for (( k=0; k<${TEMP[0]}; k++ )); do
         montage_fcn="${montage_fcn} ${DIR_SCRATCH}/Y${YCOUNT}.png"
         YCOUNT=$((${YCOUNT}+1))
       done
     fi
     if [[ "${TEMP[1]}" =~ "z" ]]; then
       for (( k=0; k<${TEMP[0]}; k++ )); do
         montage_fcn="${montage_fcn} ${DIR_SCRATCH}/Z${ZCOUNT}.png"
         ZCOUNT=$((${ZCOUNT}+1))
       done
     fi
  done
  png_fcn=${montage_fcn}' -tile x1 -geometry +0+0 -gravity center -background "'${COLOR_PANEL}'" ${DIR_SCRATCH}/image_row${i}.png'
  eval ${png_fcn}
done

FLS=($(ls ${DIR_SCRATCH}/image_row*.png))
if [[ ${#FLS[@]} -gt 1 ]]; then
  montage_fcn="montage ${DIR_SCRATCH}/image_row0.png"
  for (( i=1; i<${#FLS[@]}; i++ )); do
    montage_fcn="${montage_fcn} ${FLS[${i}]}"
  done
  montage_fcn=${montage_fcn}' -tile 1x -geometry +0+0 -gravity center  -background "'${COLOR_PANEL}'" ${DIR_SCRATCH}/image_col.png'
  eval ${montage_fcn}
else
  mv ${DIR_SCRATCH}/image_row0.png ${DIR_SCRATCH}/image_col.png
fi

# add color bars
unset CBAR_LS
if [[ "${BG_CBAR}" == "true" ]]; then
  CBAR_LS+=("${DIR_SCRATCH}/CBAR_BG.png")
fi
if [[ -n ${FG} ]]; then
  TLS=($(ls ${DIR_SCRATCH}/CBAR_FG*.png))
  TBOOL=(${FG_CBAR//,/ })
  for (( i=0; i<${#TLS[@]}; i++ )); do
    if [[ "${TBOOL[${i}]}" == "true" ]]; then
      CBAR_LS+=("${TLS[${i}]}")
    fi
  done
fi
if [[ -n ${ROI} ]]; then
  TLS=($(ls ${DIR_SCRATCH}/CBAR_ROI*.png))
  TBOOL=(${ROI_CBAR//,/ })
  for (( i=0; i<${#TLS[@]}; i++ )); do
    if [[ "${TBOOL[${i}]}" == "true" ]]; then
      CBAR_LS+=("${TLS[${i}]}")
    fi
  done
fi

if [[ ${#CBAR_LS[@]} -gt 0 ]]; then  
  montage_fcn="montage ${DIR_SCRATCH}/image_col.png"
  for (( i=0; i<${#CBAR_LS[@]}; i++ )); do
    montage_fcn="${montage_fcn} ${CBAR_LS[${i}]}"
  done
  montage_fcn=${montage_fcn}' -tile x1 -geometry +0+0 -gravity center  -background "'${COLOR_PANEL}'" ${DIR_SCRATCH}/${FILE_NAME}.png'
  eval ${montage_fcn}
else
  mv ${DIR_SCRATCH}/image_col.png ${DIR_SCRATCH}/${FILE_NAME}.png
fi

if [[ "${LABEL_LR}" == "true" ]]; then
  if [[ "${ORIENT,,}" == *"r"* ]]; then
  #&#8596
    TTXT="R \u8596 L"
  else
    TTXT="L \u8596 R"
  fi
  mogrify -font ${FONT_NAME} -pointsize ${FONT_SIZE} \
    -fill "${COLOR_TEXT}" -undercolor "${COLOR_PANEL}" \
    -gravity SouthWest -annotate +10+10 "${TTXT}" \
    ${DIR_SCRATCH}/${IMAGE_NAME}.png
fi


# move final png file
mv ${DIR_SCRATCH}/${IMAGE_NAME}.png ${DIR_SAVE}/

exit 0


########################
ROW_LAYOUT=(${IMG_LAYOUT//\;/ })
for (( i=0; i<${#ROW_LAYOUT[@]}; i++ )); do
  COL_LAYOUT=(${ROW_LAYOUT[${i}]//\,/ })
  png_fcn="pngappend"    
  for (( j=0; j<${#COL_LAYOUT[@]}; j++ )); do
     TEMP=(${COL_LAYOUT[${j}]//\:/ })
     if [[ "${TEMP[1]}" =~ "x" ]]; then
       for (( k=0; k<${TEMP[0]}; k++ )); do
         png_fcn="${png_fcn} ${DIR_SCRATCH}/X${XCOUNT}.png + 0"
         XCOUNT=$((${XCOUNT}+1))
       done
     fi
     if [[ "${TEMP[1]}" =~ "y" ]]; then
       for (( k=0; k<${TEMP[0]}; k++ )); do
         png_fcn="${png_fcn} ${DIR_SCRATCH}/Y${YCOUNT}.png + 0"
         YCOUNT=$((${YCOUNT}+1))
       done
     fi
     if [[ "${TEMP[1]}" =~ "z" ]]; then
       for (( k=0; k<${TEMP[0]}; k++ )); do
         png_fcn="${png_fcn} ${DIR_SCRATCH}/Z${ZCOUNT}.png + 0"
         ZCOUNT=$((${ZCOUNT}+1))
       done
     fi
  done
  png_fcn=${png_fcn::-3}
  png_fcn="${png_fcn} ${DIR_SCRATCH}/image_row${i}.png"
  eval ${png_fcn}
done

FLS=($(ls ${DIR_SCRATCH}/image_row*.png))
png_fcn="pngappend ${DIR_SCRATCH}/image_row0.png"
for (( i=1; i<${#FLS[@]}; i++ )); do
  png_fcn="${png_fcn} - 0 ${FLS[${i}]}"
done
png_fcn="${png_fcn} ${DIR_SCRATCH}/image_col.png"
eval ${png_fcn}

# add color bars
unset CBAR_LS CBAR_COUNT
CBAR_COUNT=0
if [[ "${BG_CBAR}" == "true" ]]; then
  CBAR_COUNT=$((${CBAR_COUNT}+1))
  CBAR_LS+=("${DIR_SCRATCH}/cbar${CBAR_COUNT}.png")
fi
CBAR_TEMP=(${FG_CBAR//,/ })
for (( i=0; i<${#FLS[@]}; i++ )); do
  if [[ "${#CBAR_TEMP}" == "1" ]]; then
    if [[ "${CBAR_TEMP}" == "true" ]]; then
      CBAR_COUNT=$((${CBAR_COUNT}+1))
      WHICH_CBAR=$((${i}+2))
      CBAR_LS+=("${DIR_SCRATCH}/cbar${WHICH_CBAR}.png")
    fi
  else
    if [[ "${CBAR_TEMP[${i}]}" == "true" ]]; then
      CBAR_COUNT=$((${CBAR_COUNT}+1))
      WHICH_CBAR=$((${i}+2))
      CBAR_LS+=("${DIR_SCRATCH}/cbar${WHICH_CBAR}.png")
    fi
  fi
done
if [[ -n ${ROI} ]]; then
  if [[ "${ROI_CBAR}" == "true" ]]; then
    CBAR_COUNT=$((${CBAR_COUNT}+1))
    TLS=($(ls ${DIR_SCRATCH}/cbar*))
    WHICH_CBAR=${#TLS[@]}
    CBAR_LS+=("${DIR_SCRATCH}/cbar${WHICH_CBAR}.png")
  fi
fi

if [[ "${CBAR_COUNT}" > "0" ]]; then  
  png_fcn="pngappend ${DIR_SCRATCH}/image_col.png"
  for (( i=0; i<${CBAR_COUNT}; i++ )); do
    png_fcn="${png_fcn} + 0 ${CBAR_LS[${i}]}"
  done
  png_fcn="${png_fcn} ${DIR_SCRATCH}/${IMAGE_NAME}.png"
  eval ${png_fcn}
else
  mv ${DIR_SCRATCH}/image_col.png ${DIR_SCRATCH}/${IMAGE_NAME}.png
fi

#*(*********************************add R-l labels)

# move final png file
mv ${DIR_SCRATCH}/${IMAGE_NAME}.png ${DIR_SAVE}/

exit 0


