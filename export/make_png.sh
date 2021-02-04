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
    ${DIR_INC}/log/logProject.sh --operator ${OPERATOR} \
    --dir-project ${DIR_PROJECT} --pid ${PID} --sid ${SID} \
    --hardware ${HARDWARE} --kernel ${KERNEL} --hpc-q ${HPC_Q} --hpc-slots ${HPC_SLOTS} \
    --fcn-name ${FCN_NAME} --proc-start ${PROC_START} --proc-stop ${PROC_STOP} --exit-code ${EXIT_CODE}
  fi
}
trap egress EXIT

# Parse inputs -----------------------------------------------------------------
OPTS=$(getopt -o hvl --long \
bg-nii:,bg-mask:,bg-thresh:,bg-color:,bg-direction:,bg-cbar,\
fg-nii:,fg-mask:,fg-thresh:,fg-color:,fg-direction:,fg-cbar,\
roi-nii:,roi-levels:,roi-color:,roi-direction:,roi-cbar,\
image-layout:,ctr-offset:,\
label-slice,label-mm,label-lr,\
color-panel:,color-text:,font-name:,font-size:,file-name:,
dir-save:,dir-scratch:,\
help,verbose,no-log -n 'parse-options' -- "$@")
if [[ $? != 0 ]]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
BG=${DIR_LOCAL}/HCPYA_700um_T1w.nii.gz
BG_MASK=${DIR_LOCAL}/HCPYA_700um_mask-brain.nii.gz
BG_THRESH=2,98
BG_COLOR="#010101,#ffffff"
BG_ORDER="normal"
BG_CBAR="false"

FG=${DIR_LOCAL}/HCPYA_700um_T2w.nii.gz
FG_MASK=${DIR_LOCAL}/HCPYA_700um_mask-bg.nii.gz
FG_THRESH=2,98
FG_COLOR="timbow"
FG_ORDER="normal"
FG_CBAR="true"

ROI=${DIR_LOCAL}/HCPYA_700um_label-bg.nii.gz
ROI_LEVELS=1:32
ROI_COLOR="timbow"
ROI_ORDER="random"
ROI_CBAR="false"

LABEL_SLICE="true"
LABEL_MM="true"
LABEL_LR="true"
COLOR_PANEL="#FFFFFF"
COLOR_TEXT="#000000"
FONT_NAME=NimbusSans-Regular
FONT_SIZE=14
DIR_SAVE=${DIR_SCRATCH}
IMAGE_NAME="image_final"

LAYOUT=1:x,1:y,1:z
OFFSET=1,0,0

# DEBUG values -----------------------------------------------------------------
sg Research-INC_img_core
module load R
source /Shared/pinc/sharedopt/apps/sourcefiles/afni_source.sh
source /Shared/pinc/sharedopt/apps/sourcefiles/ants_source.sh
source /Shared/pinc/sharedopt/apps/sourcefiles/fsl_source.sh
DIR_INC=/Shared/inc_scratch/code
DIR_TEMPLATE=/Dedicated/inc_database/templates
DIR_LOCAL=/Shared/koscikt_scratch/toLSS
DIR_SCRATCH=/Shared/koscikt_scratch/toLSS

BG=${DIR_LOCAL}/HCPYA_700um_T1w.nii.gz
BG_MASK=${DIR_LOCAL}/HCPYA_700um_mask-brain.nii.gz
BG_THRESH=2,98
BG_COLOR="#010101,#ffffff"
BG_ORDER="normal"
BG_FIDELITY=200
BG_CBAR="false"

FG=${DIR_LOCAL}/HCPYA_700um_T2w.nii.gz
FG_MASK=${DIR_LOCAL}/HCPYA_700um_mask-bg.nii.gz
FG_THRESH=2,98
FG_COLOR="timbow"
FG_COLOR_ORDER="normal"
FG_FIDELITY=200
FG_CBAR="true"

ROI=${DIR_LOCAL}/HCPYA_700um_label-bg.nii.gz
ROI_LEVELS=1:32
ROI_COLOR="timbow"
ROI_COLOR_ORDER="random"
ROI_CBAR="false"

LABEL_SLICE="true"
LABEL_MM="true"
LABEL_LR="true"
COLOR_PANEL="#FFFFFF"
COLOR_TEXT="#000000"
FONT_NAME=NimbusSans-Regular
FONT_SIZE=14
DIR_SAVE=${DIR_SCRATCH}
IMAGE_NAME="image_final"

# ------------------------------------------------------------------------------

DIR_SAVE=
DIR_SCRATCH=${DIR_TMP}/${OPERATOR}_${DATE_SUFFIX}
while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --bg-nii) BG="$2" ; shift 2 ;;
    --bg-mask) BG_MASK="$2" ; shift 2 ;;
    --bg-thresh) BG_THRESH="$2" ; shift 2 ;;
    --bg-color) BG_COLOR="$2" ; shift 2 ;;
    --bg-order) BG_ORDER="$2" ; shift 2 ;;
    --bg-cbar) BG_CBAR=true ; shift ;;
    --fg-nii) FG="$2" ; shift 2 ;;
    --fg-mask) FG_MASK="$2" ; shift 2 ;;
    --fg-thresh) FG_THRESH="$2" ; shift 2 ;;
    --fg-color) FG_COLOR="$2" ; shift 2 ;;
    --fg-order) FG_ORDER="$2" ; shift 2 ;;
    --fg-cbar) FG_CBAR=true ; shift ;;
    --roi-nii) ROI="$2" ; shift 2 ;;
    --roi-level) ROI_LEVEL="$2" ; shift 2 ;;
    --roi-color) ROI_COLOR="$2" ; shift 2 ;;
    --roi-order) ROI_ORDER="$2" ; shift 2 ;;
    --roi-cbar) ROI_CBAR="$2" ; shift 2 ;;
    --layout) LAYOUT="$2" ; shift 2 ;;
    --offset) OFFSET="$2" ; shift 2 ;;
    --label-slice) LABEL_SLICE="$2" ; shift 2 ;;
    --label-mm) LABEL_MM="$2" ; shift 2 ;;
    --label-lr) LABEL_LR="$2" ; shift 2 ;;
    --color-panel) COLOR_PANEL="$2" ; shift 2 ;;
    --color-text) COLOR_TEXT="$2" ; shift 2 ;;
    --font-name) FONT_NAME="$2" ; shift 2 ;;
    --font-size) FONT_SIZE="$2" ; shift 2 ;;
    --file-name) FILE_NAME="$2" ; shift 2 ;;
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





# ------------------------------------------------------------------------------
# 3x5 montage layout, with 5 slices from each plane: 
# row 1: 5 slices in x-plane, row 2: 5 slices in y-plane, row 3: 5 slices in z-plane
# slices are selected according to the formula (TOTAL_SLICES - (CTR_OFFSET*TOTAL_SLICES))/(NSLICES+2)[2:(NSLICES-1)]
# if the CTR_OFFSET is too small or too large, slices out of range will reduce the number of slices included
IMG_LAYOUT="5:x;5:y;5:z"
SLICE_OFFSET=0,0,0

# ------------------------------------------------------------------------------
# 3 plane layout:
# a single slice from each plane, offset by 1 slice from the center
#IMG_LAYOUT="1:x,1:y,1:z"
#SLICE_OFFSET=1,1,1

# ------------------------------------------------------------------------------
# single plane montage layout, 5x5 axial: 
# if a plane appears in multiple rows slices will be calculated based on the total number of slices desired from that plane
#IMG_LAYOUT="5:z;5:z;5:z;5:z;5:z"
#CTR_OFFSET=0,0,0

####
# parse foreground parameters --------------------------------------------------
FG=(${FG//,/ })
FG_MASK=(${FG_MASK//,/ })
FG_THRESH=(${FG_THRESH//;/ })
FG_COLOR=(${FG_COLOR//;/ })
FG_COLOR_ORDER=(${FG_COLOR_ORDER//,/ })
FG_FIDELITY=(${FG_FIDELITY//;/ })
FG_CBAR=(${FG_CBAR//,/ })

# Get image informtation -------------------------------------------------------
unset DIMS PIXDIM ORIGIN
DIMS=($(nifti_tool -disp_hdr -field dim -quiet -infiles ${BG}))
DIMS=(${DIMS[@]:1:3})
PIXDIM=($(nifti_tool -disp_hdr -field pixdim -quiet -infiles ${BG}))
PIXDIM=(${PIXDIM[@]:1:3})
ORIGIN+=($(nifti_tool -disp_hdr -field qoffset_x -quiet -infiles ${BG}))
ORIGIN+=($(nifti_tool -disp_hdr -field qoffset_y -quiet -infiles ${BG}))
ORIGIN+=($(nifti_tool -disp_hdr -field qoffset_z -quiet -infiles ${BG}))
ORIENT=($(3dinfo -orient ${BG}))

## use mm only if image is in known standard space -----------------------------
if [[ "${LABEL_MM}" == "true" ]]; then
  LABEL_MM="false"
  STD_LS=($(ls ${DIR_TEMPLATE}))
  STD_LS=("${STD_LS[@]/code}")
  STD_LS=("${STD_LS[@]/xfm}")
  for (( i=0; i<${#STD_LS[@]}; i++ )); do
    if [[ "${BG}" == *"${STD_LS[${i}]}"* ]]; then
      LABEL_MM="true"
      break
    fi
  done
  if [[ "${LABEL_MM}" == "true" ]]; then
    echo "MESSAGE [INC:${FCN_NAME}] using mm coordinate labels"
  else
    echo "MESSAGE [INC:${FCN_NAME}] using voxel coordinate labels"
  fi
fi

# Figure out number slices for each orientation --------------------------------
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

# Calculate slices to plot =====================================================
# Find image extent ------------------------------------------------------------
unset XLIM YLIM ZLIM
XLIM=(9999 0)
YLIM=(9999 0)
ZLIM=(9999 0)
unset CHK_LS
if [[ -n ${FG_MASK} ]] | [[ -n ${ROI} ]]; then
  if [[ -n ${FG_MASK} ]]; then
    CHK_LS=(${CHK_LS[@]} ${FG_MASK[@]})    
  fi
  if [[ -n ${ROI} ]]; then
    CHK_LS=(${CHK_LS[@]} ${ROI[@]})
  fi
elif [[ -n ${FG} ]]; then
  CHK_LS=(${CHK_LS[@]} ${FG[@]})
elif [[ -n ${BG_MASK} ]]; then
  CHK_LS=(${CHK_LS[@]} ${BG_MASK})
else
  CHK_LS=(${CHK_LS[@]} ${BG[@]})
fi
for (( i=0; i<${#CHK_LS[@]}; i++ )); do
  unset BB BBX BBX BBZ
  BB=$(3dAutobox -extent -input ${CHK_LS[${i}]} 2>&1)
  BBX=$(echo ${BB} | sed -e 's/.*x=\(.*\) y=.*/\1/')
  BBY=$(echo ${BB} | sed -e 's/.*y=\(.*\) z=.*/\1/')
  BBZ=$(echo ${BB} | sed -e 's/.*z=\(.*\) Extent.*/\1/')
  BBX=(${BBX//../ }); BBY=(${BBY//../ }); BBZ=(${BBZ//../ })
  if [[ ${BBX[0]} -lt ${XLIM[0]} ]]; then XLIM[0]=${BBX[0]}; fi
  if [[ ${BBY[0]} -lt ${YLIM[0]} ]]; then YLIM[0]=${BBY[0]}; fi
  if [[ ${BBZ[0]} -lt ${ZLIM[0]} ]]; then ZLIM[0]=${BBZ[0]}; fi
  if [[ ${BBX[1]} -gt ${XLIM[1]} ]]; then XLIM[1]=${BBX[1]}; fi
  if [[ ${BBY[1]} -gt ${YLIM[1]} ]]; then YLIM[1]=${BBY[1]}; fi
  if [[ ${BBZ[1]} -gt ${ZLIM[1]} ]]; then ZLIM[1]=${BBZ[1]}; fi
done

# add in desired slice offsets (i.e., to avoid middle slice) -------------------
SLICE_OFFSET=(${SLICE_OFFSET//,/ })
XLIM[0]=$((${XLIM[0]}+${SLICE_OFFSET[0]}))
XLIM[1]=$((${XLIM[1]}+${SLICE_OFFSET[0]}))
YLIM[0]=$((${YLIM[0]}+${SLICE_OFFSET[1]}))
YLIM[1]=$((${YLIM[1]}+${SLICE_OFFSET[1]}))
YLIM[0]=$((${YLIM[0]}+${SLICE_OFFSET[2]}))
YLIM[1]=$((${YLIM[1]}+${SLICE_OFFSET[2]}))
## check if limits exceed dims
if [[ ${XLIM[0]} -lt 1 ]]; then ${XLIM[0]}=1; fi
if [[ ${YLIM[0]} -lt 1 ]]; then ${YLIM[0]}=1; fi
if [[ ${ZLIM[0]} -lt 1 ]]; then ${ZLIM[0]}=1; fi
if [[ ${XLIM[1]} -gt ${DIMS[0]} ]]; then ${XLIM[1]}=${DIMS[0]}; fi
if [[ ${YLIM[1]} -gt ${DIMS[1]} ]]; then ${YLIM[1]}=${DIMS[1]}; fi
if [[ ${ZLIM[1]} -gt ${DIMS[2]} ]]; then ${ZLIM[1]}=${DIMS[2]}; fi

# find number of possible slices -----------------------------------------------
DX=$((${XLIM[1]}-${XLIM[0]}))
DY=$((${YLIM[1]}-${YLIM[0]}))
DZ=$((${ZLIM[1]}-${ZLIM[0]}))

# grab 2 extra slices, if possible, and toss to avoid edges --------------------
TX=$((${NX}+1))
if [[ ${DX} -gt ${TX} ]]; then
  SX=$((${DX}/${TX}))
  X_VOX=($(seq ${XLIM[0]} ${SX} ${XLIM[1]}))
  X_VOX=(${X_VOX[@]:1:${NX}})
else
  X_VOX=($(seq ${XLIM[0]} 1 ${XLIM[1]}))
fi
TY=$((${NY}+1))
if [[ ${DY} -gt ${TY} ]]; then
  SY=$((${DY}/${TY}))
  Y_VOX=($(seq ${YLIM[0]} ${SY} ${YLIM[1]}))
  Y_VOX=(${Y_VOX[@]:1:${NY}})
else
  Y_VOX=($(seq ${YLIM[0]} 1 ${YLIM[1]}))
fi
TZ=$((${NZ}+1))
if [[ ${DZ} -gt ${TZ} ]]; then
  SZ=$((${DZ}/${TZ}))
  Z_VOX=($(seq ${ZLIM[0]} ${SZ} ${ZLIM[1]}))
  Z_VOX=(${Z_VOX[@]:1:${NZ}})
else
  Z_VOX=($(seq ${ZLIM[0]} 1 ${ZLIM[1]}))
fi

# convert slices to proportion of max ------------------------------------------
unset X_PCT Y_PCT Z_PCT
NX=${#X_VOX[@]}
NY=${#Y_VOX[@]}
NZ=${#Z_VOX[@]}
for (( i=0; i<${NX}; i++ )); do
  X_PCT+=($(echo "scale=4; ${X_VOX[${i}]}/${DIMS[0]}" | bc -l))
done
for (( i=0; i<${NY}; i++ )); do
  Y_PCT+=($(echo "scale=4; ${Y_VOX[${i}]}/${DIMS[0]}" | bc -l))
done
for (( i=0; i<${NZ}; i++ )); do
  Z_PCT+=($(echo "scale=4; ${Z_VOX[${i}]}/${DIMS[0]}" | bc -l))
done

#===============================================================================
# check if all images in same space --------------------------------------------
CHK_FIELD=("dim" "pixdim" "quatern_b" "quatern_c" "quatern_d" "qoffset_x" "qoffset_y" "qoffset_z" "srow_x" "srow_y" "srow_z")
if [[ -n ${FG} ]]; then
  for (( i=0; i<${#FG[@]}; i++ )); do
    for (( j=0; j<${#CHK_FIELD[@]}; j++ )); do
      unset CHK
      CHK=$(nifti_tool -diff_hdr -field ${CHK_FIELD[${j}]} -infiles ${BG} ${FG[${i}]})
      if [[ -n ${CHK} ]]; then
        antsApplyTransforms \
          -d 3 -n Linear \
          -i ${FG[${i}]} \
          -o ${DIR_SCRATCH}/FG_${i}.nii.gz \
          -r ${BG}
        FG[${i}]="${DIR_SCRATCH}/FG_${i}.nii.gz"
        break
      fi
    done
  done
fi
if [[ -n ${FG_MASK} ]]; then
  for (( i=0; i<${#FG_MASK[@]}; i++ )); do
    for (( j=0; j<${#CHK_FIELD[@]}; j++ )); do
      unset CHK
      CHK=$(nifti_tool -diff_hdr -field ${CHK_FIELD[${j}]} -infiles ${BG} ${FG_MASK[${i}]})
      if [[ -n ${CHK} ]]; then
        antsApplyTransforms \
          -d 3 -n GenericLabel \
          -i ${FG_MASK[${i}]} \
          -o ${DIR_SCRATCH}/FG_mask-${i}.nii.gz \
          -r ${BG}
        FG_MASK[${i}]="${DIR_SCRATCH}/FG_mask-${i}.nii.gz"
        break
      fi
    done
  done
fi
if [[ -n ${ROI} ]]; then
  for (( j=0; j<${#CHK_FIELD[@]}; j++ )); do
    unset CHK
    CHK=$(nifti_tool -diff_hdr -field ${CHK_FIELD[${j}]} -infiles ${BG} ${ROI})
    if [[ -n ${CHK} ]]; then
      antsApplyTransforms \
        -d 3 -n MultiLabel \
        -i ${ROI} \
        -o ${DIR_SCRATCH}/ROI.nii.gz \
        -r ${BG}
      ROI="${DIR_SCRATCH}/ROI.nii.gz"
      break
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
  "n" ${BG_FIDELITY} \
  "order" ${BG_COLOR_ORDER} \
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
for (( i=0; i<${NX}; i++ )); do
  slicer ${BG} \
    -u -l ${DIR_SCRATCH}/CBAR_BG.lut \
    -i ${LO} ${HI} \
    -x ${X_PCT[${i}]} ${DIR_SCRATCH}/X${i}.png
  if [[ "${COLOR_PANEL}" != "#000000" ]]; then
    mogrify -fill "${COLOR_PANEL}" -opaque "#000000" -fuzz 1 ${DIR_SCRATCH}/X${i}.png
  fi
  if [[ "${LABEL_SLICE}" == "true" ]]; then
    if [[ "${LABEL_MM}" == "true" ]]; then
      LABEL_X=$(echo "scale=2; ${ORIGIN[0]}/${PIXDIM[0]}" | bc -l)
      LABEL_X=$(echo "scale=2; ${LABEL_X}-${X_VOX[${i}]}" | bc -l)
      LABEL_X=$(echo "scale=2; ${LABEL_X}*${PIXDIM[0]}" | bc -l)
      LABEL_X="${LABEL_X}mm"
    else
      LABEL_X=${X_VOX[${i}]}
    fi
    LABEL_X="x=${LABEL_X}"
    mogrify -font ${FONT_NAME} -pointsize ${FONT_SIZE} \
      -fill "${COLOR_TEXT}" -undercolor "${COLOR_PANEL}" \
      -gravity NorthWest -annotate +10+10 "${LABEL_X}" \
      ${DIR_SCRATCH}/X${i}.png
  fi
done
for (( i=0; i<${NY}; i++ )); do
  slicer ${BG} \
    -u -l ${DIR_SCRATCH}/CBAR_BG.lut \
    -i ${LO} ${HI} \
    -y ${Y_PCT[${i}]} ${DIR_SCRATCH}/Y${i}.png
  if [[ "${COLOR_PANEL}" != "#000000" ]]; then
    mogrify -fill "${COLOR_PANEL}" -opaque "#000000" ${DIR_SCRATCH}/Y${i}.png
  fi
  if [[ "${LABEL_SLICE}" == "true" ]]; then
    if [[ "${LABEL_MM}" == "true" ]]; then
      LABEL_Y=$(echo "scale=2; ${ORIGIN[1]}/${PIXDIM[1]}" | bc -l)
      LABEL_Y=$(echo "scale=2; ${LABEL_Y}-${Y_VOX[${i}]}" | bc -l)
      LABEL_Y=$(echo "scale=2; ${LABEL_Y}*${PIXDIM[1]}" | bc -l)
      LABEL_Y="${LABEL_Y}mm"
    else
      LABEL_Y=${Y_VOX[${i}]}
    fi
    LABEL_Y="y=${LABEL_Y}"
    mogrify -font ${FONT_NAME} -pointsize ${FONT_SIZE} \
      -fill "${COLOR_TEXT}" -undercolor "${COLOR_PANEL}" \
       -gravity NorthWest -annotate +10+10 "${LABEL_Y}" \
      ${DIR_SCRATCH}/Y${i}.png
  fi
done
for (( i=0; i<${NZ}; i++ )); do
  slicer ${BG} \
    -u -l ${DIR_SCRATCH}/CBAR_BG.lut \
    -i ${LO} ${HI} \
    -z ${Z_PCT[${i}]} ${DIR_SCRATCH}/Z${i}.png
  if [[ "${COLOR_PANEL}" != "#000000" ]]; then
    mogrify -fill "${COLOR_PANEL}" -opaque "#000000" ${DIR_SCRATCH}/Z${i}.png
  fi
  if [[ "${LABEL_SLICE}" == "true" ]]; then
    if [[ "${LABEL_MM}" == "true" ]]; then
      LABEL_Z=$(echo "scale=2; ${ORIGIN[0]}/${PIXDIM[0]}" | bc -l)
      LABEL_Z=$(echo "scale=2; ${LABEL_Z}-${Z_VOX[${i}]}" | bc -l)
      LABEL_Z=$(echo "scale=2; ${LABEL_Z}*${PIXDIM[0]}" | bc -l)
      LABEL_Z="${LABEL_Z}mm"
    else
      LABEL_Z=${Z_VOX[${i}]}
    fi
    LABEL_Z="z=${LABEL_Z}"
    mogrify -font ${FONT_NAME} -pointsize ${FONT_SIZE} \
      -fill "${COLOR_TEXT}" -undercolor "${COLOR_PANEL}" \
      -gravity NorthWest -annotate +10+10 "${LABEL_Z}" \
      ${DIR_SCRATCH}/Z${i}.png
  fi
done

# Add Foreground Overlays ======================================================
if [[ -n ${FG} ]]; then
  for (( i=0; i<${#FG[@]}; i++ )); do
    unset HILO LO HI
    HILO=(${FG_THRESH[${i}]//,/ })
    if [[ -n ${FG_MASK} ]]; then
      if [[ "${FG_MASK[${i}]}" != "null" ]]; then
        LO=$(fslstats -K ${BG_MASK} ${BG} -p ${HILO[0]})
        HI=$(fslstats -K ${BG_MASK} ${BG} -p ${HILO[1]})
      else
        LO=$(fslstats ${BG} -p ${HILO[0]})
        HI=$(fslstats ${BG} -p ${HILO[1]})
      fi
    else
      LO=$(fslstats ${BG} -p ${HILO[0]})
      HI=$(fslstats ${BG} -p ${HILO[1]})
    fi

    ## apply mask
    if [[ -n ${BG_MASK} ]]; then
      if [[ "${FG_MASK[${i}]}" != "null" ]]; then
        fslmaths ${FG[${i}]} -mas ${FG_MASK[${i}]} ${DIR_SCRATCH}/FG_${i}.nii.gz
        FG[${i}]=${DIR_SCRATCH}/FG_${i}.nii.gz
      fi
    fi

    ## generate color bar
    Rscript ${DIR_INC}/export/make_colors.R \
      "palette" ${FG_COLOR[${i}]} \
      "n" ${FG_FIDELITY[${i}]} \
      "order" ${FG_COLOR_ORDER[${i}]} \
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

    ## generate slice PNGs
    for (( x=0; x<${NX}; x++ )); do
      slicer ${FG[${i}]} \
        -u -l ${DIR_SCRATCH}/CBAR_FG_${i}.lut \
        -i ${LO} ${HI} \
        -x ${X_PCT[${x}]} ${DIR_SCRATCH}/temp.png
      convert ${DIR_SCRATCH}/temp.png \
        -transparent "${COLOR_PANEL}" -transparent "#000000" ${DIR_SCRATCH}/temp.png
      composite ${DIR_SCRATCH}/temp.png ${DIR_SCRATCH}/X${x}.png ${DIR_SCRATCH}/X${x}.png     
    done
    for (( y=0; y<${NY}; y++ )); do
      slicer ${FG[${i}]} \
        -u -l ${DIR_SCRATCH}/CBAR_FG_${i}.lut \
        -i ${LO} ${HI} \
        -y ${Y_PCT[${y}]} ${DIR_SCRATCH}/temp.png
      convert ${DIR_SCRATCH}/temp.png \
        -transparent "${COLOR_PANEL}" -transparent "#000000" ${DIR_SCRATCH}/temp.png
      composite ${DIR_SCRATCH}/temp.png ${DIR_SCRATCH}/Y${y}.png ${DIR_SCRATCH}/Y${y}.png   
    done
    for (( z=0; z<${NY}; z++ )); do
      slicer ${FG[${i}]} \
        -u -l ${DIR_SCRATCH}/CBAR_FG_${i}.lut \
        -i ${LO} ${HI} \
        -z ${Z_PCT[${z}]} ${DIR_SCRATCH}/temp.png
      convert ${DIR_SCRATCH}/temp.png \
        -transparent "${COLOR_PANEL}" -transparent "#000000" ${DIR_SCRATCH}/temp.png
      composite ${DIR_SCRATCH}/temp.png ${DIR_SCRATCH}/Z${z}.png ${DIR_SCRATCH}/Z${z}.png   
    done
  done
fi

# Add ROI ======================================================================
if [[ -n ${ROI} ]]; then
  # gather just desired ROIs ---------------------------
  ROI_LEVELS=(${ROI_LEVELS//,/ })
  fslmaths ${ROI} -thr 0 -uthr 0 ${DIR_SCRATCH}/ROI.nii.gz
  for (( i=0; i<${#ROI_LEVELS[@]}; i++ )); do
    if [[ "${ROI_LEVELS[${i}]}" =~ ":" ]]; then
      TCUT=(${ROI_LEVELS[${i}]//\:/ })
      fslmaths ${ROI} -thr ${TCUT[0]} -uthr ${TCUT[1]} \
        -add ${DIR_SCRATCH}/ROI.nii.gz \
        ${DIR_SCRATCH}/ROI.nii.gz
    else
      fslmaths ${ROI} -thr ${ROI_LEVELS[${i}]} -uthr ${ROI_LEVELS[${i}]} \
        -add ${DIR_SCRATCH}/ROI.nii.gz \
        ${DIR_SCRATCH}/ROI.nii.gz
    fi
  done
  LabelClustersUniquely 3 ${DIR_SCRATCH}/ROI.nii.gz ${DIR_SCRATCH}/ROI.nii.gz 0
  ROI=${DIR_SCRATCH}/ROI.nii.gz
  
  # convert to outlines ------------------------------
  fslmaths ${ROI} -edge -bin ${DIR_SCRATCH}/ROI_mask-edge.nii.gz
  fslmaths ${ROI} -mas ${DIR_SCRATCH}/ROI_mask-edge.nii.gz ${ROI}

  ## generate color bar
  Rscript ${DIR_INC}/export/make_colors.R \
    "palette" ${ROI_COLOR} \
    "n" ${N_ROI} \
    "order" ${ROI_COLOR_ORDER} \
    "bg" ${COLOR_PANEL} \
    "dir.save" ${DIR_SCRATCH} \
    "prefix" "CBAR_ROI"

  ## generate slice PNGs
  for (( x=0; x<${NX}; x++ )); do
    slicer ${ROI} \
      -u -l ${DIR_SCRATCH}/CBAR_ROI.lut \
      -i 1 ${N_ROI} \
      -x ${X_PCT[${x}]} ${DIR_SCRATCH}/temp.png
      convert ${DIR_SCRATCH}/temp.png \
        -transparent "${COLOR_PANEL}" -transparent "#000000" ${DIR_SCRATCH}/temp.png
      composite ${DIR_SCRATCH}/temp.png ${DIR_SCRATCH}/X${x}.png ${DIR_SCRATCH}/X${x}.png       
  done
  for (( y=0; y<${NY}; y++ )); do
    slicer ${ROI} \
      -u -l ${DIR_SCRATCH}/CBAR_ROI.lut \
      -i 1 ${N_ROI} \
      -y ${Y_PCT[${y}]} ${DIR_SCRATCH}/temp.png
      convert ${DIR_SCRATCH}/temp.png \
        -transparent "${COLOR_PANEL}" -transparent "#000000" ${DIR_SCRATCH}/temp.png
      composite ${DIR_SCRATCH}/temp.png ${DIR_SCRATCH}/Y${y}.png ${DIR_SCRATCH}/Y${y}.png    
  done
  for (( z=0; z<${NZ}; z++ )); do
    slicer ${ROI} \
      -u -l ${DIR_SCRATCH}/CBAR_ROI.lut \
      -i 1 ${N_ROI} \
      -z ${Z_PCT[${z}]} ${DIR_SCRATCH}/temp.png
      convert ${DIR_SCRATCH}/temp.png \
        -transparent "${COLOR_PANEL}" -transparent "#000000" ${DIR_SCRATCH}/temp.png
      composite ${DIR_SCRATCH}/temp.png ${DIR_SCRATCH}/Z${x}.png ${DIR_SCRATCH}/Z${x}.png    
  done
fi

# merge PNGs according to prescribed layout ====================================
# add laterality label if desired ----------------------------------------------
XCOUNT=0
YCOUNT=0
ZCOUNT=0
ROW_LAYOUT=(${IMG_LAYOUT//\;/ })
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
montage_fcn="montage ${DIR_SCRATCH}/image_row0.png"
for (( i=1; i<${#FLS[@]}; i++ )); do
  montage_fcn="${montage_fcn} ${FLS[${i}]}"
done
montage_fcn=${montage_fcn}' -tile 1x -geometry +0+0 -gravity center  -background "'${COLOR_PANEL}'" ${DIR_SCRATCH}/image_col.png'
eval ${montage_fcn}

# add color bars
unset CBAR_LS CBAR_COUNT
CBAR_COUNT=0
if [[ "${BG_CBAR}" == "true" ]]; then
  CBAR_COUNT=$((${CBAR_COUNT}+1))
  CBAR_LS+=("${DIR_SCRATCH}/CBAR_BG.png")
fi
CBAR_TEMP=(${FG_CBAR//,/ })
for (( i=0; i<${#FLS[@]}; i++ )); do
  if [[ "${#CBAR_TEMP}" == "1" ]]; then
    if [[ "${CBAR_TEMP}" == "true" ]]; then
      CBAR_COUNT=$((${CBAR_COUNT}+1))
      WHICH_CBAR=$((${i}+2))
      CBAR_LS+=("${DIR_SCRATCH}/CBAR_FG_${i}.png")
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
  montage_fcn="montage ${DIR_SCRATCH}/image_col.png"
  for (( i=0; i<${CBAR_COUNT}; i++ )); do
    montage_fcn="${montage_fcn} ${CBAR_LS[${i}]}"
  done
  montage_fcn=${montage_fcn}' -tile x1 -geometry +0+0 -gravity center  -background "'${COLOR_PANEL}'" ${DIR_SCRATCH}/${IMAGE_NAME}.png'
  eval ${montage_fcn}
else
  mv ${DIR_SCRATCH}/image_col.png ${DIR_SCRATCH}/${IMAGE_NAME}.png
fi

if [[ "${LABEL_LR}" == "true" ]]; then
  if [[ "${ORIENT,,}" == *"r"* ]]; then
  #&#8596
    TTXT="R <-> L"
  else
    TTXT="L <-> R"
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

# move final png file
mv ${DIR_SCRATCH}/${IMAGE_NAME}.png ${DIR_SAVE}/

exit 0


