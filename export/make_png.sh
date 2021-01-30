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
other-inputs:,template:,space:,\
dir-save:,dir-scratch:,\
help,verbose,keep,no-log -n 'parse-options' -- "$@")
if [[ $? != 0 ]]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
DIR_LOCAL=/Shared/koscikt_scratch/toLSS

BG=${DIR_LOCAL}/HCPYA_700um_T1w.nii.gz
BG_THRESH=0.02,0.98
BG_COLOR="#000000,#ffffff"
BG_MASK=${DIR_LOCAL}/HCPYA_700um_mask-head.nii.gz

FG=${DIR_LOCAL}/HCPYA_700um_T2w.nii.gz
FG_THRESH=0.02,0.98
FG_COLOR="timbow"
FG_MASK=${DIR_LOCAL}/HCPYA_700um_mask-brain.nii.gz

ROI=${DIR_LOCAL}/HCPYA_700um_label-bg.nii.gz
ROI_LEVELS=1:26
ROI_COLORS="randomTimbow"

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

LABEL_SLICE="true"
LABEL_LR="true"
LABEL_CBAR="true"

####


FG=(${FG//,/ })
FG_THRESH=(${FG_THRESH//;/ })
FG_COLOR=(${FG_COLOR//;/ })
FG_MASK=(${FG_MASK//,/ })

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
  if [[ "${BBX[0]}" < "${XLIM[0]}" ]]; then XLIM[0]=${BBX[0]}; fi
  if [[ "${BBY[0]}" < "${YLIM[0]}" ]]; then YLIM[0]=${BBY[0]}; fi
  if [[ "${BBZ[0]}" < "${ZLIM[0]}" ]]; then ZLIM[0]=${BBZ[0]}; fi
  if [[ "${BBX[1]}" > "${XLIM[1]}" ]]; then XLIM[1]=${BBX[1]}; fi
  if [[ "${BBY[1]}" > "${YLIM[1]}" ]]; then YLIM[1]=${BBY[1]}; fi
  if [[ "${BBZ[1]}" > "${ZLIM[1]}" ]]; then ZLIM[1]=${BBZ[1]}; fi
done

# Get image dimensions ---------------------------------------------------------
unset IMGDIMS
IMGDIMS=($(nifti_tool -disp_hdr -field dim -quiet -infiles ${BG}))
IMGDIMS=(${IMGDIMS[@]:1:3})

# convert dimension limits to a proportion of max ------------------------------
XLIM[0]=$(echo "scale=4; ${XLIM[0]}/${IMGDIMS[0]}" | bc -l)
XLIM[1]=$(echo "scale=4; ${XLIM[1]}/${IMGDIMS[0]}" | bc -l)
YLIM[0]=$(echo "scale=4; ${YLIM[0]}/${IMGDIMS[1]}" | bc -l)
YLIM[1]=$(echo "scale=4; ${YLIM[1]}/${IMGDIMS[1]}" | bc -l)
ZLIM[0]=$(echo "scale=4; ${ZLIM[0]}/${IMGDIMS[2]}" | bc -l)
ZLIM[1]=$(echo "scale=4; ${ZLIM[1]}/${IMGDIMS[2]}" | bc -l)

# add in desired slice offsets (i.e., to avoid middle slice) -------------------
SLICE_OFFSET=(${SLICE_OFFSET//, /})
SLICE_PCT+=$(echo "scale=4; 1/${IMGDIMS[0]}" | bc -l)
SLICE_PCT+=$(echo "scale=4; 1/${IMGDIMS[1]}" | bc -l)
SLICE_PCT+=$(echo "scale=4; 1/${IMGDIMS[2]}" | bc -l)
if [[ "${SLICE_OFFSET[0]}" != "0" ]]; then
  XLIM[0]=$(echo "scale=4; ${XLIM[0]}+${SLICE_PCT}" | bc -l)
  XLIM[1]=$(echo "scale=4; ${XLIM[1]}+${SLICE_PCT}" | bc -l)
fi
if [[ "${SLICE_OFFSET[1]}" != "0" ]]; then
  YLIM[0]=$(echo "scale=4; ${YLIM[0]}+${SLICE_PCT}" | bc -l)
  YLIM[1]=$(echo "scale=4; ${YLIM[1]}+${SLICE_PCT}" | bc -l)
fi
if [[ "${SLICE_OFFSET[2]}" != "0" ]]; then
  ZLIM[0]=$(echo "scale=4; ${ZLIM[0]}+${SLICE_PCT}" | bc -l)
  ZLIM[1]=$(echo "scale=4; ${ZLIM[1]}+${SLICE_PCT}" | bc -l)
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

# calculate slice positions as proportion of total extent of each plane --------
DX=$((${NX}+2))
DX=$(echo "scale=4; 1/${DX}" | bc -l)
X=($(seq ${XLIM[0]} ${DX} ${XLIM[1]}))
X=(${X[@]:1:${NX}})

DY=$((${NY}+2))
DY=$(echo "scale=4; 1/${DY}" | bc -l)
Y=($(seq ${YLIM[0]} ${DY} ${YLIM[1]}))
Y=(${Y[@]:1:${NY}})

DZ=$((${NZ}+2))
DZ=$(echo "scale=4; 1/${DZ}" | bc -l)
Z=($(seq ${ZLIM[0]} ${DZ} ${ZLIM[1]}))
Z=(${Z[@]:1:${NZ}})

# check if all images in same space --------------------------------------------
CHK_FIELD=("dim" "pixdim" "quatern_b" "quatern_c" "quatern_d" "qoffset_x" "qoffset_y" "qoffset_z" "srow_x" "srow_y" "srow_z")
if [[ -n ${FG_MASK} ]]; then
  for (( i=0; i<${#FG_MASK[@]}; i++ )); do
    for (( j=0; j<${#CHK_FIELD[@]}; j++ )); do
      unset CHK
      CHK=$(nifti_tool -diff_hdr -field ${CHK_FIELD[${j}]} -infiles ${BG} ${FG_MASK[${i}]})
      if [[ -n ${CHK} ]]; then
        antsApplyTransforms \
        -d 3 -n GenericLabel \
        -i ${FG_MASK[${j}]} \
        -o ${DIR_SCRATCH}/FG_mask-${j}.nii.gz \
        -r ${BG}
        FG_MASK[${j}]="${DIR_SCRATCH}/FG_mask-${j}.nii.gz"
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
if [[ -n ${FG} ]]; then
  for (( i=0; i<${#FG[@]}; i++ )); do
    for (( j=0; j<${#CHK_FIELD[@]}; j++ )); do
      unset CHK
      CHK=$(nifti_tool -diff_hdr -field ${CHK_FIELD[${j}]} -infiles ${BG} ${FG[${i}]})
      if [[ -n ${CHK} ]]; then
        antsApplyTransforms \
        -d 3 -n Linear \
        -i ${FG[${j}]} \
        -o ${DIR_SCRATCH}/FG_${j}.nii.gz \
        -r ${BG}
        FG[${j}]="${DIR_SCRATCH}/FG_${j}.nii.gz"
        break
      fi
    done
  done
fi

# apply masks ------------------------------------------------------------------
if [[ -n ${BG_MASK} ]]; then
  fslmaths ${BG} -mas ${BG_MASK} ${DIR_SCRATCH}/BG_mask.nii.gz
  BG=${DIR_SCRATCH}/BG_masked.nii.gz
fi
for (( i=0; i<${#FG[@]}; i++ )); do
  if [[ -n ${FG_MASK} ]] & [[ "${FG_MASK[${i}]}" != "null" ]]; then
    fslmaths ${FG[${i}]} -mas ${FG_MASK[${i}]} ${DIR_SCRATCH}/FG_${j}_masked.nii.gz
    FG[${i}]=${DIR_SCRATCH}/FG_${j}_masked.nii.gz
  fi
done

# setup ROIs -------------------------------------------------------------------
if [[ -n ${ROI} ]]; then
  ROI_LEVELS=(${ROI_LEVELS//,/ })
  unset ROI_VALS
  for (( i=0; i<${#ROI_LEVELS[@]}; i++ ));
    if [[ "${ROI_LEVELS[${i}]}" =~ ":" ]]; then
      TEMP=(${ROI_LEVELS[${i}]//:/ })
      ROI_VALS+=($(seq ${TEMP[0]} ${TEMP[1]}))
    else
      ROI_VALS+=(${ROI_LEVELS[${i}]})
    fi
  done
  fslmaths ${ROI} -mul 0 ${DIR_SCRATCH}/ROI.nii.gz
  for (( i=0; i<${#ROI_VALS[@]}; i++ )); do
    fslmaths ${ROI} \
    -thr ${ROI_VALS[${i}]} 
    -uthr ${ROI_VALS[${i}]} \
    -bin -mul ${i} \
    -add ${DIR_SCRATCH}/ROI.nii.gz \
    ${DIR_SCRATCH}/ROI.nii.gz
  done
  ROI=${DIR_SCRATCH}/ROI.nii.gz
  fslmaths ${ROI} -edge -bin ${DIR_SCRATCH}/ROI_mask-edge.nii.gz
  fslmaths ${ROI} -mas ${DIR_SCRATCH}/ROI_mask-edge.nii.gz ${ROI}
fi

# Make image -------------------------------------------------------------------
BG_THRESH=(${BG_THRESH//,/ })
ol_fcn="overlay 0 0 ${BG} ${BG_THRESH[0]} ${BG_THRESH[1]}"
if [[ -n ${FG} ]]; then
  for (( i=0; i<${#FG[@]}; i++ )); do
    unset TEMP_THRESH
    TEMP_THRESH=(${FG_THRESH[${i}]//,/ })
    ol_fcn="${ol_fcn} ${FG[${i}]} ${TEMP_THRESH[0]} ${TEMP_THRESH[1]}"
  done
fi
if [[ -n ${ROI} ]]; then
  ol_fcn="${ol_fcn} ${ROI} 0 1"
fi
ol_fcn="${ol_fcn} ${DIR_SCRATCH}/OVERLAY.nii.gz"
eval ${ol_fcn}

# get slices -------------------------------------------------------------------
for (( i=0; i<${#X[@]}; i++ )); do
  slicer ${DIR_SCRATCH}/OVERLAY.nii.gz \
    -u -l ${DIR_SCRATCH}/temp.lut \
    -x ${X[${i}]} ${DIR_SCRATCH}/X${i}.png
    if [[ "${LABEL_SLICE}" == "true" ]]; then
      SLICE_NUM=$(echo "scale=0; ${X[${i}]}/${SLICE_PCT[0]" | bc -l)
      ###Convert coordinate to mm?
      mogrify -font NimbusSans-Regular -fill white -undercolor '#00000000' \
        -pointsize 14 -gravity NorthWest -annotate +10+10 "x=${SLICE_NUM}" \
        ${DIR_SCRATCH}/X${i}.png
    fi
done
for (( i=0; i<${#Y[@]}; i++ )); do
  slicer ${DIR_SCRATCH}/OVERLAY.nii.gz \
    -u -l ${DIR_SCRATCH}/temp.lut \
    -y ${Y[${i}]} ${DIR_SCRATCH}/Y${i}.png
done
for (( i=0; i<${#Z[@]}; i++ )); do
  slicer ${DIR_SCRATCH}/OVERLAY.nii.gz \
    -u -l ${DIR_SCRATCH}/temp.lut \
    -z ${Z[${i}]} ${DIR_SCRATCH}/Z${i}.png
done
    


slicer overlay_render.nii.gz -u -l /Shared/koscikt_scratch/toHOME/timbow.lut -x 0.505 mid_sag.png -y 0.5 


mid_cor.png -z 0.5 mid_axi.png
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


