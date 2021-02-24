#!/bin/bash -e
#===============================================================================
# Make PNG images of brains, suitable for publication.
# - flexible overlay, color, and layout options
# - can plot many timpoints of a single slice
# Authors: Timothy R. Koscik, PhD
# Date: 2021-02-04
#===============================================================================
PROC_START=$(date +%Y-%m-%dT%H:%M:%S%z)
FCN_NAME=($(basename "$0"))
DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
OPERATOR=$(whoami)
KERNEL="$(uname -s)"
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
    logBenchmark --operator ${OPERATOR} \
    --hardware ${HARDWARE} --kernel ${KERNEL} --hpc-q ${HPC_Q} --hpc-slots ${HPC_SLOTS} \
    --fcn-name ${FCN_NAME} --proc-start ${PROC_START} --proc-stop ${PROC_STOP} --exit-code ${EXIT_CODE}
    if [[ -n "${DIR_PROJECT}" ]]; then
      logProject --operator ${OPERATOR} \
      --dir-project ${DIR_PROJECT} --pid ${PID} --sid ${SID} \
      --hardware ${HARDWARE} --kernel ${KERNEL} --hpc-q ${HPC_Q} --hpc-slots ${HPC_SLOTS} \
      --fcn-name ${FCN_NAME} --proc-start ${PROC_START} --proc-stop ${PROC_STOP} --exit-code ${EXIT_CODE}
      if [[ -n "${SID}" ]]; then
        logSession --operator ${OPERATOR} \
        --dir-project ${DIR_PROJECT} --pid ${PID} --sid ${SID} \
        --hardware ${HARDWARE} --kernel ${KERNEL} --hpc-q ${HPC_Q} --hpc-slots ${HPC_SLOTS} \
        --fcn-name ${FCN_NAME} --proc-start ${PROC_START} --proc-stop ${PROC_STOP} --exit-code ${EXIT_CODE}
      fi
    fi
    if [[ "${FCN_NAME}" == *"QC"* ]]; then
      logQC --operator ${OPERATOR} \
      --dir-project ${DIR_PROJECT} --pid ${PID} --sid ${SID} --scan-date ${SCAN_DATE} \
      --fcn-name ${FCN_NAME} --proc-start ${PROC_START} --proc-stop ${PROC_STOP} --exit-code ${EXIT_CODE} \
      --notes ${NOTES}
    fi
  fi
}
trap egress EXIT

# Parse inputs -----------------------------------------------------------------
OPTS=$(getopt -o hvl --long \
bg:,bg-volume:,bg-mask:,bg-mask-volume:,\
bg-threshold:,bg-color:,bg-order:,bg-cbar,\
fg:,fg-mask:,fg-mask-volume:,\
fg-threshold:,fg-alpha:,fg-color:,fg-direction:,fg-cbar,\
roi:,roi-volume:,roi-value:,roi-color:,roi-order:,roi-cbar,\
plane:,slice:,slice-method:,layout:,\
no-slice-label,use-vox-label,no-lr-label,no-volume-label,use-volume-number,label-decimal:,\
color-panel:,color-text:,color-decimal:,font:,font-size:,max-pixels:,\
keep-slice,keep-cbar,\
filename:,dir-save:,dir-scratch:,help,verbose,no-log -n 'parse-options' -- "$@")
if [[ $? != 0 ]]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
BG=
BG_VOL=1
BG_MASK=
BG_MASK_VOL=1
BG_THRESH=0,100
BG_COLOR="#010101,#FFFFFF"
BG_ORDER="normal"
BG_CBAR="false"

FG=
FG_MASK=
FG_MASK_VOL=1
FG_THRESH=0,100
FG_ALPHA=50
FG_COLOR="timbow"
FG_ORDER="normal"
FG_CBAR="true"

ROI=
ROI_VOLUME=
ROI_VALUE=
ROI_COLOR="#FF69B4"
ROI_ORDER="random"
ROI_CBAR="false"

PLANE=z
SLICE=
SLICE_METHOD=cog
LAYOUT=1x10

LABEL_NO_SLICE="false"
LABEL_USE_VOX="false"
LABEL_NO_LR="false"
LABEL_NO_TIME="false"
LABEL_USE_VOL="false"
LABEL_DECIMAL=1
COLOR_PANEL="#000000"
COLOR_TEXT="#FFFFFF"
COLOR_DECIMAL=2
FONT=NimbusSans-Regular
FONT_SIZE=24
MAX_PIXELS=500


KEEP_SLICE="false"
KEEP_CBAR="false"
FILENAME=
DIR_SAVE=
DIR_SCRATCH=${INC_SCRATCH}/${OPERATOR}_${DATE_SUFFIX}

while true; do
  case "$1" in
    -h | --help) HELP="true" ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -l | --no-log) NO_LOG="true" ; shift ;;
    --bg) BG="$2" ; shift 2 ;;
    --bg-volume) BG_VOL="$2" ; shift 2 ;;
    --bg-mask) BG_MASK="$2" ; shift 2 ;;
    --bg-mask-volume) BG_MASK_VOL="$2" ; shift 2 ;;
    --bg-threshold) BG_THRESH="$2" ; shift 2 ;;
    --bg-color) BG_COLOR="$2" ; shift 2 ;;
    --bg-order) BG_ORDER="$2" ; shift 2 ;;
    --bg-cbar) BG_CBAR="true" ; shift ;;
    --fg) FG="$2" ; shift 2 ;;
    --fg-mask) FG_MASK="$2" ; shift 2 ;;
    --fg-mask-volume) FG_MASK_VOL="$2" ; shift 2 ;;
    --fg-threshold) FG_THRESH="$2" ; shift 2 ;;
    --fg-alpha) FG_ALPHA="$2" ; shift 2 ;;
    --fg-color) FG_COLOR="$2" ; shift 2 ;;
    --fg-order) FG_ORDER="$2" ; shift 2 ;;
    --fg-cbar) FG_CBAR="false" ; shift ;;
    --roi) ROI="$2" ; shift 2 ;;
    --roi-volume) ROI_VOLUME="$2" ; shift 2 ;;
    --roi-value) ROI_VALUE="$2" ; shift 2 ;;
    --roi-color) ROI_COLOR="$2" ; shift 2 ;;
    --roi-order) ROI_ORDER="$2" ; shift 2 ;;
    --roi-cbar) ROI_CBAR="true" ; shift 2 ;;
    --plane) PLANE="$2" ; shift 2 ;;
    --slice) SLICE="2" ; shift 2 ;;
    --slice-method) SLICE_METHOD="2" ; shift 2 ;;
    --layout) LAYOUT="$2" ; shift 2 ;;
    --no-slice-label) LABEL_NO_SLICE="true" ; shift ;;
    --use-vox-label) LABEL_USE_VOX="true" ; shift ;;
    --no-lr-label) LABEL_NO_LR="true" ; shift ;;
    --no-volume-label) LABEL_NO_VOLUME="true" ; shift ;;
    --use-volume-number) LABEL_USE_VOL="true" ; shift ;;
    --label-decimal) LABEL_DECIMAL="$2" ; shift 2 ;;
    --color-panel) COLOR_PANEL="$2" ; shift 2 ;;
    --color-text) COLOR_TEXT="$2" ; shift 2 ;;
    --color-decimal) COLOR_DECIMAL="$2" ; shift 2 ;;
    --font) FONT="$2" ; shift 2 ;;
    --font-size) FONT_SIZE="$2" ; shift 2 ;;
    --max-pixels) MAX_PIXELS="$2" ; shift 2 ;;
    --filename) FILENAME="$2" ; shift 2 ;;
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
  echo '-h | --help                 display command help'
  echo '-v | --verbose              add verbose output to log file'
  echo '-l | --no-log               disable writing to output log'
  echo '--bg                        path to NIfTI file for background, single volume'
  echo '                              e.g., anatomical'
  echo '--bg-volume                 volume to use for multivolume image, default=1'
  echo '--bg-mask                   region to plot, will be binarized'
  echo '--bg-mask-volume            volume for multivolume mask, default=1'
  echo '--bg-threshold              background intensity range, default=0,100'
  echo '--bg-color                  color scale for background, details below'
  echo '--bg-order                  order of the color bar, details below'
  echo '--bg-cbar                   toggle to turn ON color bar for background'
  echo '--fg (required)             path to NIfTI file for foreground, multi-volume'
  echo '                            multiple FG images semicolon-delimited,'
  echo '                            plotted in order specified, 1st on bottom'
  echo '                              e.g., time-series, tensor, etc.'
  echo '--fg-mask                   region to plot, will be binarized'
  echo '--fg-mask-volume            volume for multivolume mask, default=1'
  echo '--fg-threshold              foreground intensity range, default=0,100'
  echo '--fg-alpha                  strength of forground overlay on preceeding'
  echo '                            layers (0-100), default=75'
  echo '--fg-color                  color scale for foreground, details below'
  echo '                            semicolon-delimited color schemes corresponding'
  echo '                            to multiple foreground images'
  echo '--fg-order                  order of the color bar, details below'
  echo '--fg-cbar                   toggle to turn ON color bar for foreground'
  echo '--roi                       path to NIfTI file to plot ROI outlines,'
  echo '                            should be integer values corresponding to'
  echo '                            regional labels, semicolon delimited for'
  echo '                            multiple files. All are combined into a single'
  echo '                            sequentially numbered label set'
  echo '--roi-volume                volume(s) for multi volume label files,'
  echo '                            -all for all volumes in a file'
  echo '                            -semicolon-delimiters for multiple files'
  echo '                            -comma-delimiters for lists of single volumes'
  echo '                            -colon-delimiters for ranges of volumes'
  echo '                            e.g., 1,3:5;all;1'
  echo '                              would yield: volumes 1,3,4,5 from ROI 1'
  echo '                                           all volumes from ROI 2'
  echo '                                           volume 1 from ROI 3'
  echo '--roi-value                 which label values from a file to include,'
  echo '                            will be applied to all volumes from that ROI file'
  echo '                            specification is the same as for ROI volumes'
  echo '--roi-color                 color scheme to use for ROIs,'
  echo '                              default="#FF69B4" (hot pink)'
  echo '--roi-order                 order of the color bar, details below'
  echo '--roi-cbar                  toggle to turn ON color bar for ROI'
  echo '--plane                     plane of section for images'
  echo '--slice                     location of slice to plot, numeric'
  echo '                            -not specifiying this option will cause the'
  echo '                             slice to be calculated based on input'
  echo '                             foreground and masks'
  echo '                            # < 0     - slice distance fom image edge in mm'
  echo '                            0 < # < 1 - slice at percentage of image width'
  echo '                            # > 1     - slice number in voxels from edge'
  echo '--slice-method              method used to calculate slice location'
  echo '                            -cog (default) center of gravity'
  echo '                                   (intensity-weighted geometric center)'
  echo '                                   based on first FG image (within mask)'
  echo '                            -min   slice on minimum value'
  echo '                            -max   slice on maximum value'
  echo '--layout                    specification of the number and arrangement'
  echo '                            of slices. x-delimited grid arrangement or'
  echo '                            semicolon-delimited specification of rows'
  echo '                            e.g., 5x5 - a 5-row by 5 column grid'
  echo '                                  5;6;5 - 3 rows, with 5, 6, and 5'
  echo '                                          slices respectively'
  echo '--no-slice-label            toggle, turn off location labels'
  echo '--use-voxel-label           toggle, use voxels not mm for location label'
  echo '--no-lr-label               toggle, turn off L and R indicator'
  echo '--no-volume-label           toggle, turn off volume labels'
  echo '--use-volume-number         toggle, use volume number not time (in s)'
  echo '--label-decimal             number of decimal places for labels, default=1'
  echo '--color-panel               color of background in image, default="#000000"'
  echo '--color-text                color of text elements, default="#FFFFFF"'
  echo '--color-decimal             number of decimal places of color bar labels, default=2'
  echo '--font                      name of font to be used, default=NimbusSans-Regular'
  echo '--font-size                 font size to use in final image, default=24'
  echo '                            might need to be adjusted depending on image size'
  echo '--max-pixels                maximum number of pixels for each slice, default=500'
  echo '                            This will up- or down-sample slices accordingly,'
  echo '                            but will retain aspect ratios'
  echo '--filename                  desired filename of output image,'
  echo '                            default=sub-${PID}_ses-${SID}_YYMMDDThhmmssnnn'
  echo '                                    overlay4D_YYMMDDThhmmssnnn'
  echo '--dir-save                  location to save final image'
  echo '--dir_scratch               directory to use to construct image'
  echo '--keep-slice                toggle, keep individual slices, same save directory'
  echo '--keep-cbar                 toggle to keep color bar images, same save directory'
  echo ''
  echo ' Details: --------------------------------------------------------------'
  echo 'thresholds:   comma-delimited minimum and maximum range of image values to'
  echo '              plot as a % of total range (0-100). default=0,100'
  echo 'colors:   colors can be specified via any comma-delimited combination of'
  echo '          HEX colors in order from low to high. Color gradients will be'
  echo '          constructed evenly distributing colors across the image range.'
  echo '          example: Red - White - Blue color gradients'
  echo '                   "#FF0000,#FFFFFF,#0000FF"'
  echo '          Several named color schemes are available:'
  echo '          -(timbow)  a rainbow color scheme based on colors from viridis'
  echo '          -viridis   including: viridis, magma, inferno, plasma, and'
  echo '                               cividis variants'
  echo '          -cubehelix  a common astronomical color gradient, where colors'
  echo '                      are selected such that intensity varies continuously'
  echo '                      from low to high along with color.'
  echo '                      Optional parameters can be specified as'
  echo '                      comma-delimited, named values after cubehelix,'
  echo '                        default="cubehelix,start,0.5,r,-1.5,hue,2,gamma,1"'
  echo '          -hot        "hot" colors, Dark red to bright yellow'
  echo '                        "#7F0000,#FF0000,#FF7F00,#FFFF00,#FFFF7F"'
  echo '          -cold       "cold" colors, dark blue to bright cyan'
  echo '                        "#00007F,#0000FF,#007FFF,#00FFFF,#7FFFFF"'
  echo '          -grayscale  [grayscale, gray, grey] "#000000,#FFFFFF"'
  echo '          -rainbow    rainbow colors, commonly referred to as "jet"'
  echo '                        "#FF0000,#FFFF00,#00FF00,#00FFFF,#0000FF,#FF00FF"'
  echo 'color order:   A modifier to add to change to the order that colors are used'
  echo '               in the color scheme. Options include:'
  echo '                 r, rand, random: randomize the order of colors'
  echo '                 rev, reverse, i, inv, inverse: invert the order of colors'
  NO_LOG=true
  exit 0
fi

#===============================================================================
# Start of Function
#===============================================================================
# set default filename
DIR_PROJECT=$(getDir -i ${BG})
PID=$(getField -i ${BG} -f sub)
SID=$(getField -i ${BG} -f ses)
if [[ -z "${FILENAME}" ]]; then
  if [[ -n "${PID}" ]]; then
    FILENAME="sub-${PID}"
    if [[ -n "${SID}" ]]; then
      FILENAME="${FILENAME}_ses-${SID}"
    fi
  else
    FILENAME="overlay4D"
  fi
  FILENAME="${FILENAME}_${DATE_SUFFIX}"
fi

# set default save directory
if [[ -n "${DIR_SAVE}" ]]; then
  DIR_SAVE=${DIR_PROJECT}/overlay_png
fi
mkdir -p ${DIR_SAVE}

# parse parameters for FG and ROIs ---------------------------------------------
FG=(${FG//;/ })
FG_MASK=(${FG_MASK//;/ })
FG_MASK_VOL=(${FG_MASK_VOL//;/ })
FG_THRESH=(${FG_THRESH//;/ })
FG_COLOR=(${FG_COLOR//;/ })
FG_ORDER=(${FG_COLOR_ORDER//;/ })
FG_CBAR=(${FG_CBAR//;/ })
FG_N=${#FG[@]}
if [[ ${FG_N} -gt 1 ]]; then
  if [[ ${#FG_MASK_VOL[@]} -eq 1 ]]; then
    for (( i=0; i<${FG_N}; i++ )); do
      FG_MASK_VOL[${i}]=(${FG_MASK_VOL[0]})
    done
  fi
fi

if [[ -z ${BG} ]]; then
  BG=${FG[0]}
  BG_VOL=1
  if [[ -n ${FG_MASK} ]]; then
    BG_MASK=${FG_MASK[0]}
    BG_MASK_VOL=1
  fi
fi

ROI=(${ROI//;/ })
ROI_VOLUME=(${ROI_VOLUME//;/ })
ROI_VALUE=(${ROI_VALUE//;/ })
ROI_COLOR=(${ROI_COLOR//;/ })
ROI_ORDER=(${ROI_ORDER//;/ })
ROI_CBAR=(${ROI_CBAR//;/ })

case ${PLANE,,} in
  x) PLANE_NUM=0 ;;
  y) PLANE_NUM=1 ;;
  z) PLANE_NUM=2 ;;
esac

# Get image information -------------------------------------------------------
unset BG_DIMS BG_PIXDIM BG_ORIGIN BG_ORIENT
BG_DIMS=($(niiInfo -i ${BG} -f voxels))
BG_PIXDIM=($(niiInfo -i ${BG} -f spacing))
BG_ORIGIN=($(niiInfo -i ${BG} -f origin))
BG_ORIENT=($(niiInfo -i ${BG} -f orient))
unset FG_DIMS FG_PIXDIM FG_ORIGIN FG_ORIENT FG_VOLS FG_TR
FG_DIMS=($(niiInfo -i ${FG[0]} -f voxels))
FG_PIXDIM=($(niiInfo -i ${FG[0]} -f spacing))
FG_ORIGIN=($(niiInfo -i ${FG[0]} -f origin))
FG_ORIENT=($(niiInfo -i ${FG[0]} -f orient))
FG_VOLS=($(niiInfo -i ${FG[0]} -f volumes))
FG_TR=$(niiInfo -i ${FG[0]} -f tr)

# get slice percentage --------------------------------------------------------
if [[ -n ${SLICE} ]]; then
  unset COORDS
  if [[ -n ${SLICE_METHOD} ]]; then
    coord_fcn="COORDS=($(fslstats "
    if [[ -n ${FG_MASK} ]]; then
      coord_fcn="${coord_fcn} -K ${FG_MASK[0]}"
    fi
    coord_fcn="${coord_fcn} ${FG[0]}"
    case ${SLICE_METHOD,,} in 
      cog) coord_fcn="${coord_fcn} -C))" ;;
      min) coord_fcn="${coord_fcn} -X))" ;;
      max) coord_fcn="${coord_fcn} -x))" ;;
    esac
    eval ${coord_fcn}
  else
    unset BB_CHK BB_STR BBX BBY BBZ
    BB_CHK=${FG[0]}
    if [[ -n ${FG_MASK} ]]; then BB_CHK=${FG_MASK[0]}; fi
    BB_STR=$(3dAutobox -extent -input ${BB_CHK} 2>&1)
    BBX=$(echo ${BB_STR} | sed -e 's/.*x=\(.*\) y=.*/\1/') #"#'# prevents bad syntax highlighting below
    BBX=(${BBX//../ });
    BBY=$(echo ${BB_STR} | sed -e 's/.*y=\(.*\) z=.*/\1/') #"#'#
    BBY=(${BBY//../ });
    BBZ=$(echo ${BB_STR} | sed -e 's/.*z=\(.*\) Extent.*/\1/') #"#'#
    BBZ=(${BBZ//../ });
    COORDS+=$(echo "scale=4; ((${BBX[0]}+${BBX[1]})/2)" | bc -l) #"#'#
    COORDS+=$(echo "scale=4; ((${BBY[0]}+${BBY[1]})/2)" | bc -l) #"#'#
    COORDS+=$(echo "scale=4; ((${BBZ[0]}+${BBZ[1]})/2)" | bc -l) #"#'#
  fi
  SLICE_PCT=$(echo "scale=4; ${COORDS[${PLANE_NUM}]}/${FG_DIMS[${PLANE_NUM}]}" | bc -l)
else
  if [[ ${SLICE} -lt 0 ]]; then
    SLICE_PCT=$(echo "scale=4; sqrt(((${SLICE}/${PIXDIM[${PLANE_NUM}]})/${DIMS[${PLANE_NUM}]})^2)" | bc -l) #"#'#
  elif [[ ${SLICE} -lt 1 ]]; then
    SLICE_PCT=${SLICE}
  elif [[ ${SLICE} -ge 1 ]]; then
    SLICE_PCT=$(echo "scale=4; ${SLICE}/${DIMS[${PLANE_NUM}]}" | bc -l)
  fi
fi
SLICE_NUM=$(echo "scale=0; ${SLICE_PCT}*${DIMS[${PLANE_NUM}]}" | bc -l)

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

# Figure out number slices based on number of volumes in FG --------------------
## Assuming all images are in sync in 4D, e.g., timepoints, tensors, or statmaps
## are the same for each FG image
NV=0
if [[ "${LAYOUT,,}" == *"x"* ]]; then
  TEMP_LAYOUT=(${LAYOUT//x/ })
  NV=$((${TEMP_LAYOUT[0]} * ${TEMP_LAYOUT[1]}))
  unset LAYOUT
  for (( i=0; i<${TEMP_LAYOUT[1]}; i++ )); do
    LAYOUT+=(${TEMP_LAYOUT[0]})
  done
else
  LAYOUT=(${LAYOUT//\;/ })
  for (( i=0; i<${#LAYOUT[@]}; i++ )); do
    NV=$((${NV} + ${LAYOUT[${i}]}))
  done
fi
NROW=${#LAYOUT[@]}

# select desired volume from multivolume images --------------------------------
TV=$(niiInfo -i ${BG} -f vols)
if [[ ${TV} -gt 1 ]]; then
  if [[ ${BG_VOL} > ${TV} ]]; then
    echo "ERROR [INC:${FCN_NAME}] BG_VOL out of range, <${TV}"
    exit 1
  else
    WHICH_VOL=$((${BG_VOL}-1))
    fslroi ${BG} ${DIR_SCRATCH}/BG.nii.gz ${WHICH_VOL} 1
    BG=${DIR_SCRATCH}/BG.nii.gz
  fi
fi

if [[ -n ${BG_MASK} ]]; then
  TV=$(niiInfo -i ${BG_MASK} -f vols)
  if [[ ${TV} -gt 1 ]]; then
    if [[ ${BG_MASK_VOL} > ${TV} ]]; then
      echo "ERROR [INC:${FCN_NAME}] BG_MASK_VOL out of range, <${TV}"
      exit 1
    else
      WHICH_VOL=$((${BG_MASK_VOL}-1))
      fslroi ${BG_MASK} ${DIR_SCRATCH}/BG_MASK.nii.gz ${WHICH_VOL} 1
      BG_MASK=${DIR_SCRATCH}/BG_MASK.nii.gz
    fi
  fi
fi

if [[ -n ${FG_MASK} ]]; then
  for (( i=0; i<${FG_N}; i++ )); do
    TV=$(niiInfo -i ${FG_MASK[${i}]} -f vols)
    if [[ ${TV} -gt 1 ]]; then
      if [[ ${FG_MASK_VOL[${i}]} > ${TV} ]]; then
        echo "ERROR [INC:${FCN_NAME}] FG_MASK_VOL[${i}] out of range, <${TV}"
        exit 1
      else
        WHICH_VOL=$((${FG_MASK_VOL[${i}]}-1))
        fslroi ${FG_MASK[${i}]} ${DIR_SCRATCH}/FG_MASK_${i}.nii.gz ${WHICH_VOL} 1
        FG_MASK[${i}]=${DIR_SCRATCH}/FG_MASK_${i}.nii.gz
      fi
    fi
  done
fi

if [[ -n ${ROI} ]]; then
  labelUnique --label ${ROI} --volume ${ROI_VOLUME} --value ${ROI_VALUE} \
  --dir-save ${DIR_SCRATCH} --prefix ROI
  ROI=${DIR_SCRATCH}/ROI.nii.gz
  ROI_VOLUME=1
  ROI_VALUE="all"
fi

# Calculate slices to plot =====================================================
if [[ ${NV} -gt ${FG_VOLS} ]]; then
  TROW=$((${NROW} - 1))
  LAYOUT[${TROW}]=$(echo "scale=0; ${LAYOUT[${TROW}]} - (${FG_VOLS} - ${NV})" | bc -l) #"#'#
  while [[ ${LAYOUT[${TROW}]} -lt 0 ]]; do
    UROW=$((${TROW} - 1))
    LAYOUT[${UROW}]=$(echo "scale=0; ${LAYOUT[${UROW}]} + ${LAYOUT[${TROW}]}" | bc -l)
    NROW=${UROW}
  done
  NV=${FG_VOLS}
fi
STEP=$(echo "scale=4; ${FG_VOLS} / ${NV}" | bc -l)
V=($(seq 1 ${STEP} ${FG_VOLS}))
V=($(printf "%0.0f " ${V[@]}))

#===============================================================================
# check if all images in same space --------------------------------------------
FIELD_CHK="dim,pixdim,quatern_b,quatern_c,quatern_d,qoffset_x,qoffset_y,qoffset_z,srow_x,srow_y,srow_z"
if [[ -n ${BG_MASK} ]]; then
  unset SPACE_CHK
  SPACE_CHK=$(niiCompare -i ${BG} -j ${BG_MASK} -f ${FIELD_CHK})
  if [[ "${SPACE_CHK}" == "false" ]]; then
    antsApplyTransforms -d 3 -n GenericLabel \
      -i ${BG_MASK} -o ${DIR_SCRATCH}/BG_mask.nii.gz -r ${BG}
    BG_MASK="${DIR_SCRATCH}/BG_mask.nii.gz"
  fi
fi
if [[ -n ${FG} ]]; then
  for (( i=0; i<${#FG[@]}; i++ )); do
    unset SPACE_CHK
    SPACE_CHK=$(niiCompare -i ${BG} -j ${FG[${i}]} -f ${FIELD_CHK})
    if [[ "${SPACE_CHK}" == "false" ]]; then
      antsApplyTransforms -d 3 -e 3 -n Linear \
        -i ${FG[${i}]} -o ${DIR_SCRATCH}/FG_${i}.nii.gz -r ${BG}
      FG[${i}]="${DIR_SCRATCH}/FG_${i}.nii.gz"
    fi
  done
fi
if [[ -n ${FG_MASK} ]]; then
  for (( i=0; i<${#FG_MASK[@]}; i++ )); do
    unset SPACE_CHK
    SPACE_CHK=$(niiCompare -i ${BG} -j ${FG_MASK[${i}]} -f ${FIELD_CHK})
    if [[ "${SPACE_CHK}" == "false" ]]; then
      antsApplyTransforms -d 3 -n GenericLabel \
        -i ${FG_MASK[${i}]} -o ${DIR_SCRATCH}/FG_mask-${i}.nii.gz -r ${BG}
      FG_MASK[${i}]="${DIR_SCRATCH}/FG_mask-${i}.nii.gz"
    fi
  done
fi
if [[ -n ${ROI} ]]; then
  unset SPACE_CHK
  SPACE_CHK=$(niiCompare -i ${BG} -j ${ROI} -f ${FIELD_CHK})
  if [[ "${SPACE_CHK}" == "false" ]]; then
    antsApplyTransforms -d 3 -n MultiLabel -i ${ROI} -o ${ROI} -r ${BG}
  fi
fi

# make panel background ========================================================
RESIZE_STR="${MAX_PIXELS}x${MAX_PIXELS}"
for (( i=0; i<${NV}; i++ )); do
  convert -size ${RESIZE_STR} canvas:${COLOR_PANEL} ${DIR_SCRATCH}/V${i}.png
done

# Make Background ==============================================================
## generate color bar
Rscript ${INC_R}/makeColors.R \
  "palette" ${BG_COLOR} "n" 200 \
  "order" ${BG_ORDER} "bg" ${COLOR_PANEL} \
  "dir.save" ${DIR_SCRATCH} "prefix" "CBAR_BG"
# make transparency color bar for binary masks
Rscript ${INC_R}/makeColors.R \
  "palette" "#000000,#FFFFFF" "n" 2 "no.png" \
  "dir.save" ${DIR_SCRATCH} "prefix" "CBAR_MASK"
### add labels to color bar
if [[ "${BG_CBAR}" == "true" ]]; then
  text_fcn='TTXT=$(printf "%0.'${COLOR_DECIMAL}'f\n" ${LO})'
  eval ${text_fcn}
  convert -background "transparent" -fill ${COLOR_TEXT} \
    -font ${FONT} -pointsize ${FONT_SIZE} \
    caption:"${TTXT}" -rotate 90 ${DIR_SCRATCH}/LABEL_LO.png
  text_fcn='TTXT=$(printf "%0.'${COLOR_DECIMAL}'f\n" ${HI})'
  eval ${text_fcn}
  convert -background "transparent" -fill ${COLOR_TEXT} \
    -font ${FONT} -pointsize ${FONT_SIZE} \
    caption:"${TTXT}" -rotate 90 ${DIR_SCRATCH}/LABEL_HI.png
  composite -gravity SouthEast \
    ${DIR_SCRATCH}/LABEL_LO.png \
    ${DIR_SCRATCH}/CBAR_BG.png \
    ${DIR_SCRATCH}/CBAR_BG.png
  composite -gravity NorthEast \
    ${DIR_SCRATCH}/LABEL_HI.png \
    ${DIR_SCRATCH}/CBAR_BG.png \
    ${DIR_SCRATCH}/CBAR_BG.png
fi

## generate slice PNGs
HILO=(${BG_THRESH//,/ })
if [[ -n ${BG_MASK} ]]; then
  LO=$(fslstats -K ${BG_MASK} ${BG} -p ${HILO[0]})
  HI=$(fslstats -K ${BG_MASK} ${BG} -p ${HILO[1]})
else
  LO=$(fslstats ${BG} -p ${HILO[0]})
  HI=$(fslstats ${BG} -p ${HILO[1]})
fi

# if not specified make background mask based on image thresholds
if [[ -z ${BG_MASK} ]]; then
  fslmaths ${BG} -thr ${LO} -bin ${DIR_SCRATCH}/BGMASK.nii.gz
  BG_MASK=${DIR_SCRATCH}/BGMASK.nii.gz
fi
# make background slice
slicer ${BG} \
  -u -l ${DIR_SCRATCH}/CBAR_BG.lut -i ${LO} ${HI} \
  -${PLANE,,} ${SLICE_PCT} ${DIR_SCRATCH}/BG.png
# resize images
 convert ${DIR_SCRATCH}/BG.png \
  -resize ${RESIZE_STR} -gravity center \
  ${DIR_SCRATCH}/BG.png
# make transparency by mask
slicer ${BG_MASK} \
  -u -l ${DIR_SCRATCH}/CBAR_MASK.lut -i 0 1 \
  -${PLANE,,} ${SLICE_PCT} ${DIR_SCRATCH}/BGMASK.png
# resize transparency mask
convert ${DIR_SCRATCH}/BGMASK.png \
  -resize ${RESIZE_STR} -gravity center \
  ${DIR_SCRATCH}/BGMASK.png

# composite background on image for each slice
for (( i=0; i<${NV}; i++ )); do
  composite ${DIR_SCRATCH}/BG.png \
    ${DIR_SCRATCH}/V${i}.png \
    ${DIR_SCRATCH}/BGMASK.png \
    ${DIR_SCRATCH}/V${i}.png
done

# Add Foreground Overlays ======================================================
for (( i=0; i<${#FG[@]}; i++ )); do
  fslsplit ${FG[${i}]} ${DIR_SCRATCH}/FG_${i}_ -t
  fslmaths ${FG[${i}]} -Tmax ${DIR_SCRATCH}/FG_${i}_tmax.nii.gz
  fslmaths ${FG[${i}]} -Tmin ${DIR_SCRATCH}/FG_${i}_tmin.nii.gz

  unset HILO LO HI
  HILO=(${FG_THRESH[${i}]//,/ })
  if [[ -z ${FG_MASK} ]] || [[ "${FG_MASK[${i}]}" != "null" ]]; then
    LO=$(fslstats ${DIR_SCRATCH}/FG_${i}_tmin.nii.gz -p ${HILO[0]})
    HI=$(fslstats ${DIR_SCRATCH}/FG_${i}_tmax.nii.gz -p ${HILO[1]})
  else
    LO=$(fslstats -K ${FG_MASK[${i}]} ${DIR_SCRATCH}/FG_${i}_tmin.nii.gz -p ${HILO[0]})
    HI=$(fslstats -K ${FG_MASK[${i}]} ${DIR_SCRATCH}/FG_${i}_tmax.nii.gz -p ${HILO[1]})
  fi

  ## generate color bar
  Rscript ${INC_R}/makeColors.R \
    "palette" ${FG_COLOR[${i}]} "n" 200 \
    "order" ${FG_ORDER[${i}]} "bg" ${COLOR_PANEL} \
    "dir.save" ${DIR_SCRATCH} "prefix" "CBAR_FG_${i}"
  ### add labels to color bar
  if [[ "${FG_CBAR[${i}]}" == "true" ]]; then
    text_fcn='TTXT=$(printf "%0.'${COLOR_DECIMAL}'f\n" ${LO})'
    eval ${text_fcn}
    convert -background "transparent" -fill ${COLOR_TEXT} \
      -font ${FONT} -pointsize ${FONT_SIZE} \
      caption:"${TTXT}" -rotate 90 ${DIR_SCRATCH}/LABEL_LO.png
    text_fcn='TTXT=$(printf "%0.'${COLOR_DECIMAL}'f\n" ${HI})'
    eval ${text_fcn}
    convert -background "transparent" -fill ${COLOR_TEXT} \
      -font ${FONT} -pointsize ${FONT_SIZE} \
      caption:"${TTXT}" -rotate 90 ${DIR_SCRATCH}/LABEL_HI.png
    composite -gravity SouthEast \
      ${DIR_SCRATCH}/LABEL_LO.png \
      ${DIR_SCRATCH}/CBAR_FG_${i}.png \
      ${DIR_SCRATCH}/CBAR_FG_${i}.png
    composite -gravity NorthEast \
      ${DIR_SCRATCH}/LABEL_HI.png \
      ${DIR_SCRATCH}/CBAR_FG_${i}.png \
      ${DIR_SCRATCH}/CBAR_FG_${i}.png
  fi

  ## generate slice PNGs - - - - - - - - - - - - - - - - - - - - - - - - - - -
  for (( j=0; j<${NV}; j++ )); do
    SNUM=$(printf "%04.0f" ${V[${j}]})
    fslmaths ${DIR_SCRATCH}/FG_${i}_${SNUM}.nii.gz -thr ${LO} \
      ${DIR_SCRATCH}/FG_${i}_${SNUM}.nii.gz
    if [[ -n ${FG_MASK} ]] || [[ "${FG_MASK[${i}]}" != "null" ]]; then
      fslmaths ${DIR_SCRATCH}/FG_${i}_${SNUM}.nii.gz \
        -mas ${FG_MASK[${i}]} ${DIR_SCRATCH}/FG_${i}_${SNUM}.nii.gz
    fi
    fslmaths ${DIR_SCRATCH}/FG_${i}_${SNUM}.nii.gz \
      -bin ${DIR_SCRATCH}/FGMASK_${i}_${SNUM}.nii.gz
    # make foreground slice
    slicer ${DIR_SCRATCH}/FG_${i}_${SNUM}.nii.gz \
      -u -l ${DIR_SCRATCH}/CBAR_FG_${i}.lut \
      -i ${LO} ${HI} -${PLANE,,} ${SLICE_PCT} \
      ${DIR_SCRATCH}/V${j}_FG_${i}.png
    convert ${DIR_SCRATCH}/V${j}_FG_${i}.png \
      -resize ${RESIZE_STR} -gravity center \
      ${DIR_SCRATCH}/V${j}_FG_${i}.png
    # make mask transparency
    slicer ${DIR_SCRATCH}/FGMASK_${i}_${SNUM}.nii.gz \
      -u -l ${DIR_SCRATCH}/CBAR_FG_${i}.lut \
      -i 0 1 -${PLANE,,} ${SLICE_PCT} \
      ${DIR_SCRATCH}/V${j}_FGMASK_${i}.png
    convert ${DIR_SCRATCH}/V${j}_FGMASK_${i}.png \
      -resize ${RESIZE_STR} -gravity center \
      ${DIR_SCRATCH}/V${j}_FGMASK_${i}.png
    # set background transparency and overlay on background
    composite -blend ${FG_ALPHA}x100% \
      ${DIR_SCRATCH}/V${j}_FG_${i}.png \
      ${DIR_SCRATCH}/V${j}.png \
      ${DIR_SCRATCH}/V${j}_FGMASK_${i}.png \
      ${DIR_SCRATCH}/V${j}.png
  done
fi

# Add ROI ======================================================================
if [[ -n ${ROI} ]]; then
  ## total number of ROIs
  ROI_N=$(fslstats ${ROI} -p 100)
  ## convert ROIs to outlines
  labelOutline --label ${ROI} --prefix ROI_OUTLINE --dir-save ${DIR_SCRATCH}
  ## make ROI mask
  fslmaths ${DIR_SCRATCH}/ROI_OUTLINE.nii.gz -bin ${DIR_SCRATCH}/ROI_MASK.nii.gz
  ## generate color bar
  Rscript ${INC_R}/makeColors.R \
    "palette" ${ROI_COLOR} "n" ${ROI_N} \
    "order" ${ROI_ORDER} "bg" ${COLOR_PANEL} \
    "dir.save" ${DIR_SCRATCH} "prefix" "CBAR_ROI"
  for (( i=0; i<${NV}; i++ )); do
    ## get slices
    slicer ${DIR_SCRATCH}/ROI_OUTLINE.nii.gz \
      -u -l ${DIR_SCRATCH}/CBAR_ROI.lut -i 0 ${ROI_N} \
      -${PLANE,,} ${SLICE_PCT} ${DIR_SCRATCH}/V${i}_ROI.png
    ## resize images
    convert ${DIR_SCRATCH}/V${i}_ROI.png \
      -resize ${RESIZE_STR} -gravity center \
      ${DIR_SCRATCH}/V${i}_ROI.png
    ## get slices for overlay mask
    slicer ${DIR_SCRATCH}/ROI_MASK.nii.gz \
      -u -l ${DIR_SCRATCH}/CBAR_MASK.lut -i 0 1 \
      -${PLANE,,} ${SLICE_PCT} ${DIR_SCRATCH}/V${i}_ROIMASK.png
    ## resize overlay mask
    convert ${DIR_SCRATCH}/V${i}_ROIMASK.png \
      -resize ${RESIZE_STR} -gravity center \
      ${DIR_SCRATCH}/V${i}_ROIMASK.png
    ## composite on background
    composite ${DIR_SCRATCH}/V${i}_ROI.png \
      ${DIR_SCRATCH}/V${i}.png \
      ${DIR_SCRATCH}/V${i}_ROIMASK.png \
      ${DIR_SCRATCH}/V${i}.png
  done
fi

# Add labels after FG and ROIs are composited
if [[ "${LABEL_NO_SLICE}" == "false" ]]; then
  if [[ "${LABEL_USE_VOX}" == "false" ]]; then
    LABEL_SLICE=$(echo "scale=${LABEL_DECIMAL}; ${ORIGIN[${PLANE_NUM}]}/${PIXDIM[${PLANE_NUM}]}" | bc -l)
    LABEL_SLICE=$(echo "scale=${LABEL_DECIMAL}; ${LABEL_SLICE}-${SLICE_NUM}" | bc -l)
    LABEL_SLICE=$(echo "scale=${LABEL_DECIMAL}; ${LABEL_SLICE}*${PIXDIM[${PLANE_NUM}]}" | bc -l)
    LABEL_SLICE="${LABEL_SLICE}mm"
  else
    LABEL_SLICE=${SLICE_NUM}
  fi
  LABEL_SLICE="${PLANE,,}=${LABEL_SLICE}"
  mogrify -font ${FONT} -pointsize ${FONT_SIZE} \
    -fill "${COLOR_TEXT}" -undercolor "${COLOR_PANEL}" \
    -gravity NorthWest -annotate +10+10 "${LABEL_SLICE}" \
    ${DIR_SCRATCH}/V0.png
fi
for (( i=0; i<${NV}; i++ )); do
  if [[ "${LABEL_NO_TIME}" == "false" ]]; then
    LABEL_TIME=${V[${i}]}
    if [[ "${LABEL_USE_VOL}" == "false" ]]; then
      LABEL_TIME=$(echo "scale=${LABEL_DECIMAL}; ${LABEL_TIME}*${FG_TR}" | bc -l)
      LABEL_TIME="${LABEL_TIME} s"
    fi
    mogrify -font ${FONT} -pointsize ${FONT_SIZE} \
      -fill "${COLOR_TEXT}" -undercolor "${COLOR_PANEL}" \
      -gravity South -annotate +10+10 "${LABEL_TIME}" \
      ${DIR_SCRATCH}/V${i}.png
  fi
done

# merge PNGs according to prescribed layout ====================================
# add laterality label if desired ----------------------------------------------
COUNT=0
for (( i=0; i<${NROW}; i++ )); do
  montage_fcn="montage"
  for (( j=0; j<${LAYOUT[${i}]}; j++ )); do
    montage_fcn="${montage_fcn} ${DIR_SCRATCH}/V${COUNT}.png"
    COUNT=$((${COUNT}+1))
  done
  montage_fcn="${montage_fcn} -tile x1"
  montage_fcn="${montage_fcn} -geometry +0+0"
  montage_fcn="${montage_fcn} -gravity center"
  montage_fcn=${montage_fcn}' -background "'${COLOR_PANEL}'"'
  montage_fcn="${montage_fcn} ${DIR_SCRATCH}/image_row${i}.png"
  eval ${montage_fcn}
done

FLS=($(ls ${DIR_SCRATCH}/image_row*.png))
if [[ ${#FLS[@]} -gt 1 ]]; then
  montage_fcn="montage ${DIR_SCRATCH}/image_row0.png"
  for (( i=1; i<${#FLS[@]}; i++ )); do
    montage_fcn="${montage_fcn} ${FLS[${i}]}"
  done
  montage_fcn="${montage_fcn} -tile 1x"
  montage_fcn="${montage_fcn} -geometry +0+0"
  montage_fcn="${montage_fcn} -gravity center"
  montage_fcn=${montage_fcn}' -background "'${COLOR_PANEL}'"'
  montage_fcn="${montage_fcn} ${DIR_SCRATCH}/image_col.png"
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
  montage_fcn="${montage_fcn} -tile x1"
  montage_fcn="${montage_fcn} -geometry +0+0"
  montage_fcn="${montage_fcn} -gravity center"
  montage_fcn=${montage_fcn}' -background "'${COLOR_PANEL}'"'
  montage_fcn="${montage_fcn} ${DIR_SCRATCH}/${FILENAME}.png"
  eval ${montage_fcn}
else
  mv ${DIR_SCRATCH}/image_col.png ${DIR_SCRATCH}/${FILENAME}.png
fi

if [[ "${LABEL_NO_LR}" == "false" ]]; then
  TTXT="L"
  if [[ "${ORIENT,,}" == *"r"* ]]; then TTXT="R"; fi
  mogrify -font ${FONT} -pointsize ${FONT_SIZE} \
    -fill "${COLOR_TEXT}" -undercolor "${COLOR_PANEL}" \
    -gravity SouthWest -annotate +10+10 "${TTXT}" \
    ${DIR_SCRATCH}/${FILENAME}.png
fi

# move final png file
mv ${DIR_SCRATCH}/${FILENAME}.png ${DIR_SAVE}/

# move optional outputs, slices and color bars
if [[ "${KEEP_SLICE}" == "true" ]]; then
  for (( i=0; i<${NV}; i++ )); do
    mv ${DIR_SCRATCH}/V${i}.png ${DIR_SAVE}/${FILENAME}_V${i}.png
  done
fi
if [[ "${KEEP_CBAR}" == "true" ]]; then
  rename CBAR ${FILENAME}_CBAR ${DIR_SCRATCH}/*.png
  mv {DIR_SCRATCH}/${FILENAME}_CBAR*.png ${DIR_SAVE}/
fi

#-------------------------------------------------------------------------------
# End of Function
#-------------------------------------------------------------------------------
exit 0


