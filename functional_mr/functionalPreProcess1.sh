#!/bin/bash

####################

ver=1.0.0
verDate=5/15/19

####################


# A giant wrapper script that will pre-process functional (task or rest) EPI data:
#  1) Phase distortion correction (unwrapping) - Gradient Echo and Spin Echo blips or Phase & Magnitude fieldMap
#  2) Motion correction
#  3) EPI to structural target (T2, T1, etc.)
#  4) Concatenation of transforms (EPI to standard/atlas)
#  5) Unified transform to standard space, concatenation of multiple runs
#
# by Joel Bruss (joel-bruss@uiowa.edu)

#########################################################################################################

scriptName="functionalPreProcess1.sh"
scriptDir=/Shared/nopoulos/nimg_core
atlasDir=/Shared/nopoulos/nimg_core/templates_human
userID=`whoami`
source $scriptDir/sourcePack.sh

unwrapProc=0

#Source versions of programs used:
VER_afni=${VER_afni}
VER_ants=${VER_ants}
VER_fsl=${VER_fsl}

#########################################################################################################

printCommandLine() {
  echo ""
  echo "Usage: functionalProcessingStream1.sh --epiList=epiList --unwrapData=unwrapData --unwrapType=unwrapType --T1=T1 --T2=T2 --anatTarget=anatTarget --anatMask=anatMask"
  echo "       --anatToAtlasXfm=anatToAtlasXfm --subject=sub --session=ses --site=site --researcher=researcher --project=project --researchGroup=researchGroup"
  echo ""
  echo "   where:"
  echo "     --epiList:  Input EPI (comma-separated list of input EPI to be processed(e.g. 'epi1,epi2')"
  echo "     --unwrapData:  blipUp/Down pair used for distortion correction."
  echo "                   *If using multiple images, this will be a comma-seperated list"
  echo "                   *Must be either:"
  echo "                     blip up/down pairs"
  echo "                     phase/magnitude (fieldMap) pairs (Siemens).  Must be comma-separted, phase image first"
  echo "                     phase/magnitude 4D image (GE."
  echo "     --unwrapType:  fieldmap -OR- blip"
  echo "                   NOTE:  If NOT using unwrapData, leave unwrapData and unwrapType blank."
  echo "     --blipType:  gradientecho -OR- spinecho"
  echo "                   *If using fieldmap data or NOT using blip data, leave blank"
  echo "     --T1:  T1 (with skull) for use with fieldMap processing.  Also used for tissue classification."
  echo "     --T2:  T2 (with skull) for use with fieldMap processing."
  echo "                   *T1 and T2 must be in the same space as anatTarget."
  echo "     --anatMask:  Anatomcial mask used to aid in registration"
  echo "     --anatToAtlasXfm:  Anatomical to standard/atlas transform stack"
  echo "                   *Instruction set to get from T1/T2 to standard/atlas space"
  echo ""
  echo "    Project-specific variables:"
  echo "     --subject:  Subject"
  echo "     --session:  Session"
  echo "     --site:  Site"
  echo "     --researcher:  Researcher"
  echo "     --project:  Project"
  echo "     --researchGroup:  Permissions group"
  echo ""
  echo ""
  exit 1
}

get_opt1() {
  arg=$(echo "$1" | sed 's/=.*//')
  echo "$arg"
}

get_arg1() {
    if [ X"$(echo "$1" | grep '=')" = X ] ; then
      echo "Option $1 requires an argument" 1>&2
      exit 1
    else
      arg=$(echo "$1" | sed 's/.*=//')
      if [ X"$arg" = X ] ; then
          echo "Option $1 requires an argument" 1>&2
          exit 1
      fi
	    echo "$arg"
    fi
}

while [ $# -ge 1 ] ; do
    iarg=$(get_opt1 "$1");
    case "$iarg"
	in
    -h)
        PrintCommandLine;
        exit 0;;
    --researcher) #e.g. /Shared/nopolous
        researcher=$(get_arg1 "$1");
        export researcher
        if [[ "${researcher}" == "" ]]; then
          echo "Error: The input '--researcher' is required"
          exit 1
        fi
          shift;;
    --project) #e.g. sca_pilot
        project=$(get_arg1 "$1");
        export project
        if [[ "${project}" == "" ]]; then
          echo "Error: The input '--project' is required"
          exit 1
        fi
          shift;;
    --subject) #e.g. 231
        subject=$(get_arg1 "$1");
        export subject
        if [[ "${subject}" == "" ]]; then
          echo "Error: The input '--subject' is required"
          exit 1
        fi
          shift;;
    --session) #e.g. 328zk16wb6
        session=$(get_arg1 "$1");
        export session
        if [[ "${session}" == "" ]]; then
          echo "Error: The input '--session' is required"
          exit 1
        fi
          shift;;
    --site) #e.g. 00201
        site=$(get_arg1 "$1");
        export site
        if [[ "${site}" == "" ]]; then
          echo "Error: The input '--site' is required"
          exit 1
        fi
          shift;;
    --researchGroup) #e.g. 900031646
        researchGroup=$(get_arg1 "$1");
        export researchGroup
        if [[ "${researchGroup}" == "" ]]; then
          echo "Error: The input '--researchGroup' is required"
          exit 1
        fi
          shift;; 
    --epiList) #Input EPI(s) to process
        epiList=$(get_arg1 "$1");
        export epiList
        if [[ "${epiList}" == "" ]]; then
          echo "Error: The input '--epiList' is required"
          exit 1
        fi
          shift;;
    --unwrapData) #Blip-pair for distortion correction, can also be a phase/magnitude fmap pair of a 4D phase/magnitude file
        unwrapData=$(get_arg1 "$1");
        export unwrapData
        if [[ "${unwrapData}" == "" ]]; then
          echo "Error: The input '--unwrapData' is required"
          exit 1
        fi
        unwrapProc=1
        export unwrapProc
          shift;;
    --unwrapType) #fieldmap -OR- blip
        unwrapType=$(get_arg1 "$1");
        export unwrapType
          shift;;
    --blipType) #gradientecho -OR- spinecho
        blipType=$(get_arg1 "$1");
        export blipType
        if [[ "${blipType}" != "gradientecho" && "${blipType}" != "spinecho" ]]; then
            echo "Error: The input '--blipType' is required (either 'gradientecho' or 'spinecho')"
            exit 1
        fi
          shift;;
    --T1) #T1 (with skull), used with fmap processing, also to get tissue classes for nuisance regression.  Must be in the same space as T2 and anatMask
        T1=$(get_arg1 "$1");
        export T1
        if [[ "${T1}" == "" ]]; then
          echo "Error: The input '--T1' is required"
          exit 1
        fi
        if [[ ! -e $T1 ]]; then
          echo "Error Nonexistent or improper T1 file specified.  Please check and try again with '--T1'"
          exit 1
        fi
          shift;;
    --T2) #T2 (with skull), used with tissueSeg, fmap/blip registration.  Must be in the same space as T1 and anatMask
        T2=$(get_arg1 "$1");
        export T2
        if [[ "${T2}" == "" ]]; then
          echo "Error: The input '--T2' is required"
          exit 1
        fi
        if [[ ! -e $T2 ]]; then
          echo "Error Nonexistent or improper T2 file specified.  Please check and try again with '--T2'"
          exit 1
        fi
        T2Base=`basename $T2 | awk -F"." '{print $1}'`
        export T2Base
          shift;;
    --anatMask) #Anatomical mask, same space as T1 and T2 (e.g. /Shared/nopoulos/sca_pilot/derivatives/anat/mask/sub-231_ses-328zk16wb6_site-00201_mask-brain.nii.gz)
        anatMask=$(get_arg1 "$1");
        export anatMask
        if [[ "${anatMask}" == "" ]]; then
          echo "Error: The input '--anatMask' is required"
          exit 1
        fi
        if [[ ! -e $anatMask ]]; then
          echo "Error Nonexistent or improper target anatomical mask file specified.  Please check and try again with '--anatMask'"
          exit 1
        fi
          shift;;
    --anatToAtlasXfm) #Transform stack from anat to standard/atlas (e.g. sub-231_ses-328zk16wb6_site-00201_from-T1w+rigid_to-HCPMNI2009c+800um_xfm-stack.nii.gz)
        anatToAtlasXfm=$(get_arg1 "$1");
        export anatToAtlasXfm
        if [[ "$anatToAtlasXfm" == "" ]]; then
          echo "Error: The input '--anatToAtlasXfm' is required"
          exit 1
        fi
        if [[ ! -e ${anatToAtlasXfm} ]]; then
          echo "Error Nonexistent or improper anat to Atlas warp file specified.  Please check and try again with '--anatToAtlasXfm'"
          exit 1
        fi
        atlasName=`basename ${anatToAtlasXfm} | awk -F"to-" '{print $2}' | awk -F"+" '{print $1}'`
        atlasSize=`basename ${anatToAtlasXfm} | awk -F"to-" '{print $2}' | awk -F"+" '{print $2}' | awk -F"_" '{print $1}'`
        export atlasName
        export atlasSize
          shift;;
    ?)
      echo "ERROR: Invalid option"
      printCommandLine
      ;;
     esac
done

#########################################################################################################

#Begin Logging
if [[ ! -d ${researcher}/${project}/log ]]; then
  mkdir -p ${researcher}/${project}/log
fi

subject_log=${researcher}/${project}/log/sub-${subject}_ses-${session}_site-${site}.log

echo '#--------------------------------------------------------------------------------' >> ${subject_log}
echo "ParentTask:functionalPreProcessing" >> ${subject_log}
echo "script:${scriptDir}/${scriptName}" >> ${subject_log}
echo "software:AFNI,version:${VER_afni}" >> ${subject_log}
echo "software:ANTs,version:${VER_ants}" >> ${subject_log}
echo "software:FSL,version:${VER_fsl}" >> ${subject_log}
echo "owner: ${userID}" >> ${subject_log} >> ${subject_log}
date +"start:%Y-%m-%dT%H:%M:%S%z" >> ${subject_log} >> ${subject_log}

#########################################################################################################

########################################

#Data dependencies:
 #EPI data
  #Final place for motion-corrected EPI in standard/atlas space
finalEpiDir=${researcher}/${project}/derivatives/func/reg_${atlasName}_${atlasSize}
  if [[ ! -d $finalEpiDir ]]; then
    mkdir -p $finalEpiDir
  fi
  #Motion correction directory
motionCorrDir=${researcher}/${project}/derivatives/func/prep/sub-${subject}/ses-${session}/motionCorr
  if [[ ! -d $motionCorrDir ]]; then
    mkdir -p $motionCorrDir
  fi
  #Transform directory
xfmDir=${researcher}/${project}/derivatives/xfm/sub-${subject}/ses-${session}
  if [[ ! -d $xfmDir ]]; then
    mkdir -p $xfmDir
  fi

 #Anat data
  #Tissue class segmentation directory
tisDir=${researcher}/${project}/derivatives/anat/segmentation

  if [[ ! -d $tisDir ]]; then
    mkdir -p $tisDir
  fi

  #unwrap data
if [[ $unwrapProc -eq 1 ]]; then
  if [[ "${unwrapType}" != "fieldmap" &&  "${unwrapType}" != "blip" ]]; then
    echo "Error: The input '--unwrapType' is required (either 'fieldmap' or 'blip')"
    exit 1
  fi
fi
if [[ "${unwrapType}" == "blip" ]]; then #Blip Correction
  if [[ "${blipType}" != "gradientecho" && "${blipType}" != "spinecho" ]]; then
    echo "Error: The input '--blipType' is required (either 'gradientecho' or 'spinecho')"
    exit 1
  fi
  blipDir=${researcher}/${project}/derivatives/func/prep/sub-${subject}/ses-${session}/blipDir
  if [[ ! -d $blipDir ]]; then
    mkdir -p $blipDir
  fi
fi
if [[ "${unwrapType}" == "fieldmap" ]]; then #fieldMap Correction
  fmapDir=${researcher}/${project}/derivatives/func/prep/sub-${subject}/ses-${session}/fmapDir
  if [[ ! -d $fmapDir ]]; then
    mkdir -p $fmapDir
  fi
fi

########################################

#ANTs call to register each TR to motCorAvg (use inital MOCO params as initialization via an ITK-compatible .mat file
affineMotion()
{
  fixed=$1
  moving=$2
  outDir=$3
  mocoParams=$4
  paramLine=$5

  fixedBase=`basename ${fixed} | awk -F"." '{print $1}'`
  movingBase=`basename ${moving} | awk -F"." '{print $1}'`

  #Create an ITK-compatible affine .mat file from the original MOCO parameters (first run of antsMotionCorr); use as init
  geomCenter=`$FSLDIR/bin/fslstats ${fixed} -c | awk '{OFS=" ";print($1*-1),($2*-1),$3}'`
  affParams=`cat ${mocoParams} | head -n+${paramLine} | tail -n-1 | awk -F"," '{OFS=" ";print $3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14}'`

  cat ${scriptDir}/dummyAffine.txt | sed "s/GEOMCENTER/${geomCenter}/g" | sed "s/AFFPARAMS/${affParams}/g" > ${outDir}/tmpAffine${paramLine}.txt
  $ANTSPATH/ConvertTransformFile 3 ${outDir}/tmpAffine${paramLine}.txt ${outDir}/tmpAffine${paramLine}.mat --convertToAffineType

  $ANTSPATH/antsRegistration -d 3 --float 0 \
  --output ${outDir}/${movingBase}_to_${fixedBase}_ \
  --interpolation Linear \
  --winsorize-image-intensities [0.005,0.995] \
  --use-histogram-matching 1 \
  --initial-moving-transform ${outDir}/tmpAffine${paramLine}.mat \
  --transform Affine[0.1] \
  --metric MI[${fixed},${moving},1,32,Regular,0.25] \
  --convergence [1000x500x250x100,1e-6,10] \
  --shrink-factors 8x4x2x1 \
  --smoothing-sigmas 3x2x1x0vox

  rm ${outDir}/tmpAffine${paramLine}.txt ${outDir}/tmpAffine${paramLine}.mat
}

#ANTs Motion Correction syntax
antsMotionCorrCall()
{
  moving=$1
  fixed=$2
  outputCall=$3
  flagCall=$4
  transformType=$5

  $ANTSPATH/antsMotionCorr -d 3 \
  -o [${outputCall}] \
  -m MI[${fixed},${moving},1,32,Regular,0.2] \
  -t ${transformType}[0.1] ${flagCall}
}

#Phase distortion correction (blip-up/blip-down) via topup/applytopup
blipCor()
{
  blipUp=$1
  blipDown=$2
  T2=$3
  anatMask=$4
  outDir=$5
  blipType=$6

  $scriptDir/functionalBlipUnwrapping.sh --blipType=${blipType} \
  --blipUp=${blipUp} \
  --blipDown=${blipDown} \
  --T2=${T2} \
  --anatMask=${anatMask} \
  --outDir=${outDir} \
  --researcher=${researcher} \
  --project=${project} \
  --subject=${subject} \
  --session=${session} \
  --site=${site} \
  --researchGroup=${researchGroup}
}

#Unwrapping of EPI via fieldMap
fmapCor()
{
  phase=$1
  magnitude=$2
  T1=$3
  T2=$4
  anatMask=$5
  epiMotCor=$6
  dwellTime=$7
  peDir=$8
  fmapDir=$9
  fmapType=${10}
  
  ${scriptDir}/functionalFmapUnwrapping.sh --fmapType=${fmapType} \
  --phase=${phase} \
  --magnitude=${magnitude} \
  --T1=${T1} \
  --T2=${T2} \
  --anatMask=${anatMask} \
  --epiAvg=${epiMotCor} \
  --dwellTime=${dwellTime} \
  --peDir="${peDir}" \
  --fmapDir=${fmapDir} \
  --researcher=${researcher} \
  --project=${project} \
  --subject=${subject} \
  --session=${session} \
  --site=${site} \
  --researchGroup=${researchGroup}
}

#Simple function to count number of items in an input variable
howmany()
{
  input=$1
  VAR=`echo $1 | sed 's/,/ /g'`
  VAR=( $VAR )
  numVars=`echo ${#VAR[@]}`
}

#Mask Creation
maskPrep()
{
  input=$1
  inBase=`basename $input | awk -F"." '{print $1}'`
  inDir=`dirname $input`

  $AFNIDIR/3dSkullStrip -input $input -mask_vol -prefix $inDir/${inBase}_mask.nii.gz
}

#Convert antsMotionCorr MOCOparams (rigid body/6 paramater model) to an AFNI/FSL compatible .par file (deg and mm); calculate absolute and relative displacment
MOCO_to_par()
{
  input=$1

  #Reorder the file (stripping off header)
    #Reorder from "rot1 rot2 rot3 trans1 trans2 trans3" to "-rot3 -rot1 -rot2 trans3 trans1 -trans2" for raw
    #Further, make RPI/LPI/RAI such that final mapping is (from AFNI) 2,3,1,5,6,4
    #pitch(x), yaw(y), roll(z),dL,dP,dS
  cat $input | tail -n+2 | awk -F"," '{OFS=" "; print ($3*-1),($4*-1),($5*-1),$6,($7*-1),$8}' > ${motionCorrDir}/${epiBase}_mcImg.par

  #Convert Radians to degrees
    #rotRad=(rotDeg*pi)/180
      #pi=3.14159
  cat ${motionCorrDir}/${epiBase}_mcImg.par | awk -v pi=3.14159 '{OFS=" "; print (($1*180)/pi),(($2*180)/pi),(($3*180)/pi),$4,$5,$6}' > ${motionCorrDir}/${epiBase}_mcImg_deg.par

  #Convert rotations to mm per Power et. al. 2012 (radius of 50mm)
    #Convert degrees to mm, leave translations alone.
      #((2r*Pi)/360) * rotDeg = Distance (mm)
        #d=2r=2*50=100
	#pi=3.14159
    #Distance (mm) = ((d*pi)/360)*((180*rotRad)/pi) = (d*rotRad)/2
  cat ${motionCorrDir}/${epiBase}_mcImg.par | awk -v d=100 '{OFS=" "; print ((d*$1)/2),((d*$2)/2),((d*$3)/2),$4,$5,$6}' > ${motionCorrDir}/${epiBase}_mcImg_mm.par

  #Absolute Displacement
  cat ${motionCorrDir}/${epiBase}_mcImg.par | awk '{print (sqrt(0.2*80^2*((cos($1)-1)^2+(sin($1))^2 + (cos($2)-1)^2 + (sin($2))^2 + (cos($3)-1)^2 + (sin($3)^2)) + $4^2+$5^2+$6^2))}' > ${motionCorrDir}/${epiBase}_mcImg_abs.rms

  #Relative Displacement
    #Create the relative displacement .par file from the input using AFNI's 1d_tool.py to first calculate the derivatives
  $AFNIDIR/1d_tool.py -infile ${motionCorrDir}/${epiBase}_mcImg.par -set_nruns 1 -derivative -write ${motionCorrDir}/${epiBase}_mcImg_deriv.par
  cat ${motionCorrDir}/${epiBase}_mcImg_deriv.par | awk '{print (sqrt(0.2*80^2*((cos($1)-1)^2+(sin($1))^2 + (cos($2)-1)^2 + (sin($2))^2 + (cos($3)-1)^2 + (sin($3)^2)) + $4^2+$5^2+$6^2))}' > ${motionCorrDir}/${epiBase}_mcImg_rel.rms
}

#Check for Phase Encoding Direction ("i" = x, "j" = y), dwellTime (Effective Echo spacing)
  #Likely values for dwellTime are, GE=0.00056, Siemens=0.00064
peDwellCheck()
{
  input=$1

  peDirJson=`cat $input | grep '"PhaseEncodingDirection"' | awk -F":" '{print $2}' | awk -F"," '{print $1}' | sed -e 's/"//g' | sed -e 's/ //g'`
  dwellTime=`cat $input | grep '"EffectiveEchoSpacing"' | awk -F":" '{print $2}' | awk -F"," '{print $1}' | sed -e 's/"//g' | sed -e 's/ //g'`
}

#Reassemble a time-series back to 4D
reAssemble()
{
  assembleList=`echo $1`
  targetSpacing=$2
  targetOrigin=$3
  outputAssembled=$4

  #Reassemble the time-series
  $ANTSPATH/ImageMath 4 \
  ${outputAssembled} \
  TimeSeriesAssemble \
  ${targetSpacing} ${targetOrigin} ${assembleList}
}

#Resample a file to a specified set of dimensions
resampleFile()
{
  input=$1
  outDir=$2
  outBase=$3
  resampDims=$4
  resampTarget=$5
  nnResample=$6

  resampDimsTrunc=`echo ${resampDims} | awk -F"x" '{OFS="x";print $1,$2,$3}' | sed 's/x/ /g'`
  targetBase=`basename ${resampTarget} | awk -F"." '{print $1}'`

  $ANTSPATH/ResampleImageBySpacing 3 ${input} ${outDir}/${outBase}_res_to-${targetBase}.nii.gz ${resampDimsTrunc} 0 0 ${nnResample}
}

#Warp one file to another, restricted by (usually phase-encoding dimension) in nonlinear stage
restrictWarp()
{
  fixed=$1
  moving=$2
  outDir=$3
  restrictDim=$4

  fixedBase=`basename ${fixed} | awk -F"." '{print $1}'`
  movingBase=`basename ${moving} | awk -F"." '{print $1}'`

  $ANTSPATH/antsRegistration -d 3 --float 0 \
  --output ${outDir}/${movingBase}_to-${fixedBase}_ \
  --interpolation Linear \
  --winsorize-image-intensities [0.005,0.995] \
  --use-histogram-matching 0 \
  --initial-moving-transform [${fixed},${moving},1] \
  --transform Rigid[0.1] \
  --restrict-deformation [1x1x1x1x1x1] \
  --metric MI[${fixed},${moving},1,32,Regular,0.25] \
  --convergence [1000x500x250x100,1e-6,10] \
  --shrink-factors 8x4x2x1 \
  --smoothing-sigmas 3x2x1x0vox \
  --transform Affine[0.1] \
  --restrict-deformation [1x1x1x1x1x1] \
  --metric MI[${fixed},${moving},1,32,Regular,0.25] \
  --convergence [1000x500x250x100,1e-6,10] \
  --shrink-factors 8x4x2x1 \
  --smoothing-sigmas 3x2x1x0vox \
  --transform SyN[0.1,3,0] \
  --restrict-deformation [${restrictDim}] \
  --metric CC[${fixed},${moving},1,4] \
  --convergence [100x70x50x20,1e-6,10] \
  --shrink-factors 8x4x2x1 \
  --smoothing-sigmas 3x2x1x0vox
}

#Segment the T1,T2 into three tissue classes
segmentTissue()
{
  T1=$1
  T2=$2
  mask=$3
  output=$4

  $ANTSPATH/antsAtroposN4.sh -d 3 -a $T1 -a $T2 -x $mask -c 3 -o ${output} -m 5 -n 5
}

#Split apart a time-series
splitFile()
{
  input=$1

  inputBase=`basename $input | awk -F"." '{print $1}'`

  #Split apart time series
  pushd ${motionCorrDir} > /dev/null

  $ANTSPATH/ImageMath 4 \
  ${inputBase}_TMPSPLIT.nii.gz \
  TimeSeriesDisassemble \
  $input

    #Ouput split images will have the naming convention "name"1(0-(totalTr-1)).nii.gz
      #That is, this is a zero numbering convention (e.g. 1000-1407 (if 408 TRs))

  popd > /dev/null
}

#Log the star/stop times
timeLog()
{
  input=$1

  if [[ ${input} == "s" ]]; then
    timeStamp=`date +"start:%Y-%m-%dT%H:%M:%S%z"`
  else
    timeStamp=`date +"end:%Y-%m-%dT%H:%M:%S%z"`
  fi
}

########################################

  ########################
  #  Tissue_Segment      #
  ########################

if [[ ! -e ${tisDir}/sub-${subject}_ses-${session}_site-${site}_seg-WM.nii.gz ]]; then

  #Log the task start time, set placeholder for end time
  timeLog "s"
  echo "task:Tissue_Segment,${timeStamp},TissueSegment_TIMEEND" >> ${subject_log}

  #Segment the T1,T2
  segmentTissue ${T1} ${T2} ${anatMask} ${tisDir}/sub-${subject}_ses-${session}_site-${site}_

  mv ${tisDir}/sub-${subject}_ses-${session}_site-${site}_SegmentationPosteriors1.nii.gz ${tisDir}/sub-${subject}_ses-${session}_site-${site}_seg-CSF.nii.gz
  mv ${tisDir}/sub-${subject}_ses-${session}_site-${site}_SegmentationPosteriors2.nii.gz ${tisDir}/sub-${subject}_ses-${session}_site-${site}_seg-GM.nii.gz
  mv ${tisDir}/sub-${subject}_ses-${session}_site-${site}_SegmentationPosteriors3.nii.gz ${tisDir}/sub-${subject}_ses-${session}_site-${site}_seg-WM.nii.gz

  #Log the task end time
  timeLog "e"
  sed -i "s/TissueSegment_TIMEEND/${timeStamp}/g" ${subject_log}
fi

########################################

  ####################
  #  epiPrep_1       #
  ####################

#Process the EPI data
  #Log the task start time, set placeholder for end time
timeLog "s"
echo "task:epiPrep_1,${timeStamp},epiPrep1_TIMEEND" >> ${subject_log}

#March through EPI(s)
for epi in $(echo $epiList | sed "s/,/ /g");
  do

  #Round up some information about the input EPI
    #With new (e.g. 2+1) site variable, awk is confused by "+" (2+1 becomes 00201), string replace with underscore just to get $epiBaseStub
  epiBase=`basename $epi | awk -F"." '{print $1}'`
  epiBaseRep=`echo $epiBase | sed 's/+/_/g'`
  prefixRep=`echo sub-${subject}_ses-${session}_site-${site} | sed 's/+/_/g'`
  epiBaseStub=`echo $epiBaseRep | awk -F"${prefixRep}" '{print $2}' | cut -c2-`

  epiPath=`dirname $epi`
  numVols=`$ANTSPATH/PrintHeader $epi 2 | awk -F"x" '{print $NF}'`
  trVal=`$ANTSPATH/PrintHeader $epi 1 | awk -F"x" '{print $NF}'`
  halfTR=`echo $numVols | awk '{print (int($1/2))}'`
    #EPI origin, spacing (for resampling images, final push to reassemble a 4D file)
  origOrigin=`${ANTSPATH}/PrintHeader ${epi} 0`
  origSpacing=`${ANTSPATH}/PrintHeader ${epi} 1`
    #Determine which dimension to constrain warp to based on phase encoding dimension
      #Also pulling out dwellTime (also referred to as Effective Echo Spacing in FSL nomenclature)
  peDwellCheck $epiPath/${epiBase}.json

  if [[ $peDirJson == "i" || $peDirJson == "-i" || $peDirJson == "i-" ]]; then
    restrictDim="1x0x0"  #i or x-axis
  else
    restrictDim="0x1x0"  #j or y-axis
  fi

  #Set peDir for fmapUnwrapping (FSL)
  if [[ "${peDirJson}" == "i" ]]; then
    peDir=x
  elif [[ "${peDirJson}" == "-i" ]]; then
    peDir="-x"
  elif [[ "${peDirJson}" == "i-" ]]; then
    peDir="x-"
  elif [[ "${peDirJson}" == "j" ]]; then
    peDir="y"
  elif [[ "${peDirJson}" == "-j" ]]; then
    peDir="-y"
  else
    peDir="y-"
  fi

    ####################
    #  epiSplit        #
    ####################

    #Log the task start time, set placeholder for end time
  timeLog "s"
  echo "task:epiSplit,${timeStamp},epiSplit_TIMEEND" >> ${subject_log}

  #Split apart the EPI (handle each TR individually downstream, halfway TR used for motion correction parameters)
  splitFile ${epi}

    #Log the task end time
  timeLog "e"
  sed -i "s/epiSplit_TIMEEND/${timeStamp}/g" ${subject_log}

  ########################################

    ####################
    #  epiMotCor       #
    ####################

    #Log the task start time, set placeholder for end time
  timeLog "s"
  echo "task:epiMotCor,${timeStamp},epiMotCor_TIMEEND" >> ${subject_log}

  #Pull out the halfway TR volume as a temporary target
  splitList=`ls -1tv ${motionCorrDir}/${epiBase}_TMPSPLIT*nii.gz`
  halfVol=`echo ${splitList} | awk -v var=${halfTR} '{print $var}'`

  #Create the avg. template (all TRs aligned to halfway TR)  
    #mat files will be discarded, only needed for aligned half_Avg output
  outString="${motionCorrDir}/${epiBase}_half_Avg_,${motionCorrDir}/${epiBase}_half_Avg_Warped.nii.gz,${motionCorrDir}/${epiBase}_half_Avg.nii.gz"
  outFlags="-u 1 -e 1 -s 1x0 -f 2x1 -i 15x3 -n ${numVols} --use-histogram-matching 1"
  antsMotionCorrCall ${epi} ${halfVol} "${outString}" "${outFlags}" Affine

  #Use average as target for final run (this step is to ONLY generate traditional motion parameters (3 rotations, 3 translations))
   #Collapsed Avg. will have better resolution than the single halfway TR
    #Generate Motion Parameters with a rigid alignment
    #Downstream, each TR will be affine aligned to the half_Avg file
  outString="${motionCorrDir}/${epiBase}_motCorr_Rigid_"
  outFlags="-u 1 -e 1 -s 3x2x1x0 -f 4x3x2x1 -i 20x15x5x1 --use-histogram-matching 1"
  antsMotionCorrCall ${epi} ${motionCorrDir}/${epiBase}_half_Avg.nii.gz "${outString}" "${outFlags}" Rigid

    #Log the task end time
  timeLog "e"
  sed -i "s/epiMotCor_TIMEEND/${timeStamp}/g" ${subject_log}

  ########################################

    ####################
    #  epiMotCor_mask  #
    ####################

    #Log the task start time, set placeholder for end time
  timeLog "s"
  echo "task:epiMotCor_mask,${timeStamp},epiMotCorMask_TIMEEND" >> ${subject_log}

  #Create a mask of half TR avg. template
  maskPrep ${motionCorrDir}/${epiBase}_half_Avg.nii.gz

    #Log the task end time
  timeLog "e"
  sed -i "s/epiMotCorMask_TIMEEND/${timeStamp}/g" ${subject_log}

  ########################################

    ####################
    #  epiMotCor_strip #
    ####################

    #Log the task start time, set placeholder for end time
  timeLog "s"
  echo "task:epiMotCor_strip,${timeStamp},epiMotCorStrip_TIMEEND" >> ${subject_log}

  #Create a mask of half TR avg. template
  $AFNIDIR/3dcalc -a ${motionCorrDir}/${epiBase}_half_Avg.nii.gz -b ${motionCorrDir}/${epiBase}_half_Avg_mask.nii.gz -expr 'a*step(b)' \
  -prefix ${motionCorrDir}/${epiBase}_half_Avg_stripped.nii.gz

    #Log the task end time
  timeLog "e"
  sed -i "s/epiMotCorStrip_TIMEEND/${timeStamp}/g" ${subject_log}

  ########################################

    ########################
    #  atlasAnat_Resample  #
    ########################

    #Log the task start time, set placeholder for end time
  timeLog "s"
  echo "task:atlasAnat_Resample,${timeStamp},atlasAnatResample_TIMEEND" >> ${subject_log}

  #Resample the standard/atlas, anat/T1 to EPI space (allows FOV of atlas/anat in input EPI grid space)
    #Truncate spacing of $epi to three dimensions (replace "x" with space)
    #This resampled atlas (e.g. HCPMNI2009c+800um) will be used as a target for resampling each of the motion-corrected TRs before reassembly
  if [[ ! -e ${motionCorrDir}/${atlasName}_${atlasSize}_res_to-${epiBase}.nii.gz ]]; then
    resampleFile ${atlasDir}/${atlasName}/${atlasSize}/${atlasName}_${atlasSize}_T1w.nii.gz \
    ${motionCorrDir} ${atlasName}_${atlasSize} ${origSpacing} ${epi} 0
  fi
  if [[ ! -e ${motionCorrDir}/sub-${subject}_ses-${session}_site-${site}_T1w_res_to-${epiBase}.nii.gz ]]; then
    resampleFile ${T1} ${motionCorrDir} sub-${subject}_ses-${session}_site-${site}_T1w ${origSpacing} ${epi} 0
  fi
  if [[ $unwrapProc -eq 0 ]]; then #Resample the T2, anatMask and strip
    if [[ ! -e ${motionCorrDir}/${T2Base}_res_to-${epiBase}_stripped.nii.gz ]]; then
      resampleFile ${T2} ${motionCorrDir} ${T2Base} ${origSpacing} ${epi} 0
      resampleFile ${anatMask} ${motionCorrDir} ${T2Base}_mask ${origSpacing} ${epi} 1
      $FSLDIR/bin/fslmaths ${motionCorrDir}/${T2Base}_res_to-${epiBase}.nii.gz -mas ${motionCorrDir}/${T2Base}_mask_res_to-${epiBase}.nii.gz \
      ${motionCorrDir}/${T2Base}_res_to-${epiBase}_stripped.nii.gz
    fi
  fi

    #Log the task end time
  timeLog "e"
  sed -i "s/atlasAnatResample_TIMEEND/${timeStamp}/g" ${subject_log}

  ########################################

  #unWrapping the EPI data: no unwrap Data, Blip Data or fieldMap data
  if [[ $unwrapProc -eq 0 ]]; then  #No fieldMap or blip data to use
  
      ####################
      #  noUnwrap_proc   #
      ####################

      #Log the task start time, set placeholder for end time
    timeLog "s"
    echo "task:noUnwrap_proc,${timeStamp},noUnwrapProc_TIMEEND" >> ${subject_log}

    #Perform registration, restricted to phase encoding dimension (in nonlinear stage)
    blipTarget=${motionCorrDir}/${epiBase}_half_Avg_stripped.nii.gz
    blipTargetBase=`basename $blipTarget | awk -F"." '{print $1}'`
    anatStrippedBase=`basename ${motionCorrDir}/${T2Base}_res_to-${epiBase}_stripped.nii.gz | awk -F"." '{print $1}'`

    restrictWarp ${motionCorrDir}/${epiBase}_half_Avg_stripped.nii.gz ${motionCorrDir}/${T2Base}_res_to-${epiBase}_stripped.nii.gz ${motionCorrDir} ${restrictDim}

      #Log the task end time
    timeLog "e"
    sed -i "s/noUnwrapProc_TIMEEND/${timeStamp}/g" ${subject_log}

    ########################################

  else  #fieldMap or blip data correction

    if [[ ${unwrapType} = "fieldmap" ]]; then  #fieldMap correction

        ####################
        #  fmap_proc       #
        ####################

        #Log the task start time, set placeholder for end time
      timeLog "s"
      echo "task:fmapProc,${timeStamp},fmapProc_TIMEEND" >> ${subject_log}

      #Count number of inputs (1=GE, 2=Siemens)
      howmany $unwrapData

      if [[ $numVars -eq 1 ]]; then #GE

          ########################
          #  fmap_prep(ge)       #
          ########################

        fmapType=ge

          #Log the task start time, set placeholder for end time
        timeLog "s"
        echo "task:fmap_prep(ge),${timeStamp},fmapPrepG_TIMEEND" >> ${subject_log}

        #Pull apart the phase and magnitude from the 4D image
        $FSLDIR/bin/fslroi ${unwrapData} ${fmapDir}/raw_phase.nii.gz 0 1
        $FSLDIR/bin/fslroi ${unwrapData} ${fmapDir}/raw_magnitude.nii.gz 1 1

        #Create a mask for both the magnitude and motCorAvg image
        $FSLDIR/bin/bet ${fmapDir}/raw_magnitude.nii.gz ${fmapDir}/raw_magnitude -m -n
        $FSLDIR/bin/bet ${motionCorrDir}/${epiBase}_half_Avg.nii.gz ${fmapDir}/${epiBase}_half_Avg -m -n

        #Erode the motCorAvg mask
        ImageMath 3 ${fmapDir}/${epiBase}_half_Avg_mask_eroded.nii.gz ME ${fmapDir}/${epiBase}_half_Avg_mask.nii.gz 1
        $FSLDIR/bin/fslmaths ${fmapDir}/${epiBase}_half_Avg_mask_eroded.nii.gz -bin ${fmapDir}/${epiBase}_half_Avg_mask_eroded.nii.gz -odt char

        #Strip the raw_magnitude file (by regular mask, for registration)
        $FSLDIR/bin/fslmaths ${fmapDir}/raw_magnitude.nii.gz -mas ${fmapDir}/raw_magnitude_mask.nii.gz ${fmapDir}/raw_magnitude_stripped.nii.gz

        #Determine the 25th percentile of voxel values for stripped mag file, subtract the threshold, set new threshold to zero
        P25=`$FSLDIR/bin/fslstats ${fmapDir}/raw_magnitude_stripped.nii.gz -P 25`
        $FSLDIR/bin/fslmaths ${fmapDir}/raw_magnitude_stripped.nii.gz -sub ${P25} -thr 0 ${fmapDir}/raw_magnitude_stripped_thresh.nii.gz

        #Register the P25 magnitude image to the motCorAvg file
        $ANTSPATH/antsRegistration --dimensionality 3 --float 0 \
        --output [${fmapDir}/magnitude_to_${epiBase}_half_Avg_] \
        --interpolation Linear \
        --winsorize-image-intensities [0.005,0.995] \
        --use-histogram-matching 0 \
        --initial-moving-transform [${motionCorrDir}/${epiBase}_half_Avg_stripped.nii.gz,${fmapDir}/raw_magnitude_stripped_thresh.nii.gz,1] \
        --transform Rigid[0.1] \
        --metric MI[${motionCorrDir}/${epiBase}_half_Avg_stripped.nii.gz,${fmapDir}/raw_magnitude_stripped_thresh.nii.gz,1,32,Regular,0.25] \
        --convergence [1000x500x250x100,1e-6,10] \
        --shrink-factors 8x4x2x1 \
        --smoothing-sigmas 3x2x1x0vox \
        --transform Affine[0.1] \
        --metric MI[${motionCorrDir}/${epiBase}_half_Avg_stripped.nii.gz,${fmapDir}/raw_magnitude_stripped_thresh.nii.gz,1,32,Regular,0.25] \
        --convergence [1000x500x250x100,1e-6,10] \
        --shrink-factors 8x4x2x1 \
        --smoothing-sigmas 3x2x1x0vox

        #Apply the transform to the raw phase and magnitude images
        $ANTSPATH/antsApplyTransforms -d 3 \
        -i ${fmapDir}/raw_phase.nii.gz \
        -r ${motionCorrDir}/${epiBase}_half_Avg_stripped.nii.gz \
        -o ${fmapDir}/raw_phase_to_${epiBase}_half_Avg.nii.gz \
        -t ${fmapDir}/magnitude_to_${epiBase}_half_Avg_0GenericAffine.mat \
        -n Linear

        $ANTSPATH/antsApplyTransforms -d 3 \
        -i ${fmapDir}/raw_magnitude.nii.gz \
        -r ${motionCorrDir}/${epiBase}_half_Avg_stripped.nii.gz \
        -o ${fmapDir}/raw_magnitude_to_${epiBase}_half_Avg.nii.gz \
        -t ${fmapDir}/magnitude_to_${epiBase}_half_Avg_0GenericAffine.mat \
        -n Linear

        #Reference the minimally prepped/warped phase and magnitude images
        phase=${fmapDir}/raw_phase_to_${epiBase}_half_Avg.nii.gz
        magnitude=${fmapDir}/raw_magnitude_to_${epiBase}_half_Avg.nii.gz

        #Run the fieldMap setup
        fmapCor ${phase} ${magnitude} ${T1} ${T2} ${anatMask} ${motionCorrDir}/${epiBase}_half_Avg.nii.gz ${dwellTime} ${peDir} ${fmapDir} ${fmapType}

          #Log the task end time
        timeLog "e"
        sed -i "s/fmapPrepG_TIMEEND/${timeStamp}/g" ${subject_log}

        ########################################

      else #Siemens

          ########################
          #  fmap_prep(siemens)  #
          ########################

        fmapType=siemens

          #Log the task start time, set placeholder for end time
        timeLog "s"
        echo "task:fmap_prep(siemens),${timeStamp},fmapPrepS_TIMEEND" >> ${subject_log}

        #Reference the minimally prepped/warped phase and magnitude images
        phase=`echo ${unwrapData} | awk -F"," '{print $1}'`
        magnitude=`echo ${unwrapData} | awk -F"," '{print $2}'`

        #Run the fieldMap setup
        fmapCor ${phase} ${magnitude} ${T1} ${T2} ${anatMask} ${motionCorrDir}/${epiBase}_half_Avg.nii.gz ${dwellTime} "${peDir}" ${fmapDir} ${fmapType}

          #Log the task end time
        timeLog "e"
        sed -i "s/fmapPrepS_TIMEEND/${timeStamp}/g" ${subject_log}

        ########################################

      fi

          #########################
          #  motCorAvg_to_unwrap  #
          #########################

          #Log the task start time, set placeholder for end time
        timeLog "s"
        echo "task:motCorAvg_toUnwrap,${timeStamp},motCorAvgToUnwrap_TIMEEND" >> ${subject_log}

        #Register the motCorAvg file to the unwrapped file, restricted to Phase-encoding dimension
        restrictWarp ${fmapDir}/${epiBase}_half_Avg_unwrapped_stripped.nii.gz ${motionCorrDir}/${epiBase}_half_Avg_stripped.nii.gz ${motionCorrDir} ${restrictDim}

          #Log the task end time
        timeLog "e"
        sed -i "s/motCorAvgToUnwrap_TIMEEND/${timeStamp}/g" ${subject_log}

        ########################################

        #Log the task end time
      timeLog "e"
      sed -i "s/fmapProc_TIMEEND/${timeStamp}/g" ${subject_log}

      ########################################

    else  #Blip correction

        ####################
        #  blip_proc       #
        ####################

      #Check for Gradient Echo or Spin Echo EPI, fieldMap via Phase and Magnitude
      if [[ "${blipType}" == "gradientecho" ]]; then  #Gradient Echo EPI

        #Check to see if blip processing has been done (don't need to do for every EPI file)
        if [[ ! -e ${blipDir}/Topup_corrected_stripped.nii.gz ]]; then

            ########################
            #  blipPrep(gradEcho)  #
            ########################

            #Log the task start time, set placeholder for end time
          timeLog "s"
          echo "task:blipPrep(gradEcho),${timeStamp},blipPrepG_TIMEEND" >> ${subject_log}

          #Blip-up/blip-down for distortion correction/unwrapping, Part I
            #Creation of an undistorted blip target

          #Pull apart the input blip images
          blip1=`echo $unwrapData | awk -F"," '{print $1}'`
          blip2=`echo $unwrapData | awk -F"," '{print $2}'`

          #Check the phase encoding (neg. is blipUp, pos. is blipDown)
            #Only have to test one blip, the other should be opposite phase encoding direction
          blipBase=`basename ${blip1} | awk -F"." '{print $1}'`
          blipPath=`dirname ${blip1}`

          peCheck $blipPath/${blipBase}.json

          if echo $peDirJson | egrep -q '[-]';  then
            bu=${blip1}
            bd=${blip2}
          else
            bu=${blip2}
            bd=${blip1}
          fi

          #Create the unwrapped b0, registered to anat
          blipCor ${bu} ${bd} ${T2} ${anatMask} ${blipDir} ${blipType}

            #Log the task end time
          timeLog "e"
          sed -i "s/blipPrepG_TIMEEND/${timeStamp}/g" ${subject_log}

          ########################################
        fi

          #########################
          #  motCorAvg_to_unwrap  #
          #########################

          #Log the task start time, set placeholder for end time
        timeLog "s"
        echo "task:motCorAvg_toUnwrap,${timeStamp},motCorAvgToUnwrap_TIMEEND" >> ${subject_log}

        #Register the motCorAvg file to the unwrapped file, restricted to Phase-encoding dimension
        restrictWarp ${blipDir}/Topup_corrected_stripped.nii.gz ${motionCorrDir}/${epiBase}_half_Avg_stripped.nii.gz ${motionCorrDir} ${restrictDim}

          #Log the task end time
        timeLog "e"
        sed -i "s/motCorAvgToUnwrap_TIMEEND/${timeStamp}/g" ${subject_log}

        ########################################

      else  #Spin Echo EPI -- This section to be filled in later when we can actually acquire and process SE EPI

          ########################
          #  blipPrep(spinEcho)  #
          ########################

          #Log the task start time, set placeholder for end time
        timeLog "s"
        echo "task:blipPrep(spinEcho),${timeStamp},blipPrepS_TIMEEND" >> ${subject_log}

        ### Place holder section... to be filled in later
          #Place conditional on blip creation (only need to do once, for each EPI)

          #Log the task end time
        timeLog "e"
        sed -i "s/blipPrepS_TIMEEND/${timeStamp}/g" ${subject_log}

        ########################################
      fi
    fi
  fi

    ####################
    #  epiSplitProc    #
    ####################

    #Log the task start time, set placeholder for end time
  timeLog "s"
  echo "task:epiSplitProc,${timeStamp},epiSplitProc_TIMEEND" >> ${subject_log}

  #Co-register each split, padded EPI to rawAvg, then applywarp all the way up to MNI, re-assemble
  paramLine=2
  for splitFile in ${splitList};
    do

    #Get a base name for moving files
    splitBase=`basename $splitFile | awk -F"." '{print $1}'`

    #Register single EPI to motCorAvg (use first antsMotionCorr (affine) MOCO params to intialize)
    affineMotion ${motionCorrDir}/${epiBase}_half_Avg.nii.gz ${splitFile} ${motionCorrDir} ${motionCorrDir}/${epiBase}_half_Avg_MOCOparams.csv ${paramLine}

    #Apply all transforms (up to standard/atlas and motion-correction in one step), including some combination of:
      #Anatomical to standard/atlas
      #unwrap to anatomical
      #motCorAvg to unwrap
      #Single TR to motCorAvg
    if [[ $unwrapProc -eq 0 ]]; then  #No fieldMap or blip data to use
      $ANTSPATH/antsApplyTransforms -d 3 \
      -i ${splitFile} \
      -r ${motionCorrDir}/${atlasName}_${atlasSize}_res_to-${epiBase}.nii.gz \
      -o ${motionCorrDir}/${splitBase}_to-${atlasName}_${atlasSize}_tmp.nii.gz \
      -n Linear \
      -t ${anatToAtlasXfm} \
      -t [${motionCorrDir}/${T2Base}_res_to-${epiBase}_stripped_to-${epiBase}_half_Avg_stripped_0GenericAffine.mat,1] \
      -t ${motionCorrDir}/${T2Base}_res_to-${epiBase}_stripped_to-${epiBase}_half_Avg_stripped_1InverseWarp.nii.gz \
      -t ${motionCorrDir}/${splitBase}_to_${epiBase}_half_Avg_0GenericAffine.mat
    else
      if [[ ${unwrapType} = "fieldmap" ]]; then  #fieldMap correction
        $ANTSPATH/antsApplyTransforms -d 3 \
        -i ${splitFile} \
        -r ${motionCorrDir}/${atlasName}_${atlasSize}_res_to-${epiBase}.nii.gz \
        -o ${motionCorrDir}/${splitBase}_to-${atlasName}_${atlasSize}_tmp.nii.gz \
        -n Linear \
        -t ${anatToAtlasXfm} \
        -t [${fmapDir}/${T2Base}_res_to-${epiBase}_half_Avg_stripped_to_${epiBase}_half_Avg_unwrapped_stripped_0GenericAffine.mat,1] \
        -t ${fmapDir}/${T2Base}_res_to-${epiBase}_half_Avg_stripped_to_${epiBase}_half_Avg_unwrapped_stripped_1InverseWarp.nii.gz \
        -t ${motionCorrDir}/${epiBase}_half_Avg_stripped_to-${epiBase}_half_Avg_unwrapped_stripped_1Warp.nii.gz \
        -t ${motionCorrDir}/${epiBase}_half_Avg_stripped_to-${epiBase}_half_Avg_unwrapped_stripped_0GenericAffine.mat \
        -t ${motionCorrDir}/${splitBase}_to_${epiBase}_half_Avg_0GenericAffine.mat
      else  #Blip correction
        ####May need conditional for spin-echo down the road
        $ANTSPATH/antsApplyTransforms -d 3 \
        -i ${splitFile} \
        -r ${motionCorrDir}/${atlasName}_${atlasSize}_res_to-${epiBase}.nii.gz \
        -o ${motionCorrDir}/${splitBase}_to-${atlasName}_${atlasSize}_tmp.nii.gz \
        -n Linear \
        -t ${anatToAtlasXfm} \
        -t [${blipDir}/${T2Base}_to_TopupTarget_0GenericAffine.mat,1] \
        -t ${blipDir}/${T2Base}_to_TopupTarget_1InverseWarp.nii.gz \
        -t ${motionCorrDir}/${epiBase}_half_Avg_stripped_to-Topup_corrected_stripped_1Warp.nii.gz \
        -t ${motionCorrDir}/${epiBase}_half_Avg_stripped_to-Topup_corrected_stripped_0GenericAffine.mat \
        -t ${motionCorrDir}/${splitBase}_to_${epiBase}_half_Avg_0GenericAffine.mat
      fi
    fi
    let paramLine=paramLine+1
  done

    #Log the task end time
  timeLog "e"
  sed -i "s/epiSplitProc_TIMEEND/${timeStamp}/g" ${subject_log}

  ########################################

    ####################
    #  epiReassemble   #
    ####################

    #Log the task start time, set placeholder for end time
  timeLog "s"
  echo "task:epiReassemble,${timeStamp},epiReassemble_TIMEEND" >> ${subject_log}

  #Re-assemble the time-series (now in MNI152 space, original grid spacing)
    #Create a list of the warped files
  warpedList=`ls -1tv ${motionCorrDir}/*_to-${atlasName}_${atlasSize}_tmp.nii.gz`
  reAssemble "${warpedList}" "${origSpacing}" "${origOrigin}" \
  ${finalEpiDir}/sub-${subject}_ses-${session}_site-${site}_reg-${atlasName}+${atlasSize}_${epiBaseStub}+motCor.nii.gz

    #Log the task end time
  timeLog "e"
  sed -i "s/epiReassemble_TIMEEND/${timeStamp}/g" ${subject_log}

  ########################################

    ####################
    #  xfmCombine      #
    ####################

    #Log the task start time, set placeholder for end time
  timeLog "s"
  echo "task:xfmCombine,${timeStamp},xfmCombine_TIMEEND" >> ${subject_log}

  #First check for existence of final output xfm directory
  xfmDir=${researcher}/${project}/derivatives/xfm/sub-${subject}/ses-${session}
  if [[ ! -d $xfmDir ]]; then
    mkdir -p $xfmDir
  fi

  #half Avg template to standard/atlas
    #Anatomical to standard/atlas
    #blip Target to anatomical
    #half_Avg to blip Target
  if [[ $unwrapProc -eq 0 ]]; then  #No fieldMap or blip data to use
    $ANTSPATH/antsApplyTransforms -d 3 \
    -i ${motionCorrDir}/${epiBase}_half_Avg.nii.gz \
    -r ${motionCorrDir}/${atlasName}_${atlasSize}_res_to-${epiBase}.nii.gz \
    -o [${xfmDir}/sub-${subject}_ses-${session}_site-${site}_from-${epiBaseStub}+motCorAvg_to-${atlasName}+${atlasSize}_xfm-stack.nii.gz,1] \
    -n Linear \
    -t ${anatToAtlasXfm} \
    -t [${motionCorrDir}/${T2Base}_res_to-${epiBase}_stripped_to-${epiBase}_half_Avg_stripped_0GenericAffine.mat,1] \
    -t ${motionCorrDir}/${T2Base}_res_to-${epiBase}_stripped_to-${epiBase}_half_Avg_stripped_1InverseWarp.nii.gz
  else
    if [[ ${unwrapType} = "fieldmap" ]]; then  #fieldMap correction
      ####May need conditional for Siemens/GE down the road
      $ANTSPATH/antsApplyTransforms -d 3 \
      -i ${motionCorrDir}/${epiBase}_half_Avg.nii.gz \
      -r ${motionCorrDir}/${atlasName}_${atlasSize}_res_to-${epiBase}.nii.gz \
      -o [${xfmDir}/sub-${subject}_ses-${session}_site-${site}_from-${epiBaseStub}+motCorAvg_to-${atlasName}+${atlasSize}_xfm-stack.nii.gz,1] \
      -n Linear \
      -t ${anatToAtlasXfm} \
      -t [${fmapDir}/${T2Base}_res_to-${epiBase}_half_Avg_stripped_to_${epiBase}_half_Avg_unwrapped_stripped_0GenericAffine.mat,1] \
      -t ${fmapDir}/${T2Base}_res_to-${epiBase}_half_Avg_stripped_to_${epiBase}_half_Avg_unwrapped_stripped_1InverseWarp.nii.gz \
      -t ${motionCorrDir}/${epiBase}_half_Avg_stripped_to-${epiBase}_half_Avg_unwrapped_stripped_1Warp.nii.gz \
      -t ${motionCorrDir}/${epiBase}_half_Avg_stripped_to-${epiBase}_half_Avg_unwrapped_stripped_0GenericAffine.mat
    else  #Blip correction
        ####May need conditional for spin-echo down the road
      $ANTSPATH/antsApplyTransforms -d 3 \
      -i ${motionCorrDir}/${epiBase}_half_Avg.nii.gz \
      -r ${motionCorrDir}/${atlasName}_${atlasSize}_res_to-${epiBase}.nii.gz \
      -o [${xfmDir}/sub-${subject}_ses-${session}_site-${site}_from-${epiBaseStub}+motCorAvg_to-${atlasName}+${atlasSize}_xfm-stack.nii.gz,1] \
      -n Linear \
      -t ${anatToAtlasXfm} \
      -t [${blipDir}/${T2Base}_to_TopupTarget_0GenericAffine.mat,1] \
      -t ${blipDir}/${T2Base}_to_TopupTarget_1InverseWarp.nii.gz \
      -t ${motionCorrDir}/${epiBase}_half_Avg_stripped_to-Topup_corrected_stripped_1Warp.nii.gz \
      -t ${motionCorrDir}/${epiBase}_half_Avg_stripped_to-Topup_corrected_stripped_0GenericAffine.mat
    fi
  fi

  #Create a half Avg template to anat warp stack as well (in case one wants to use another standard/atlas space)
    #blip Target to anatomical
    #half_Avg to blip Target
  if [[ $unwrapProc -eq 0 ]]; then  #No fieldMap or blip data to use
    $ANTSPATH/antsApplyTransforms -d 3 \
    -i ${motionCorrDir}/${epiBase}_half_Avg.nii.gz \
    -r ${motionCorrDir}/sub-${subject}_ses-${session}_site-${site}_T1w_res_to-${epiBase}.nii.gz  \
    -o [${xfmDir}/sub-${subject}_ses-${session}_site-${site}_from-${epiBaseStub}+motCorAvg_to-T1w+rigid_xfm-stack.nii.gz,1] \
    -n Linear \
    -t [${motionCorrDir}/${T2Base}_res_to-${epiBase}_stripped_to-${epiBase}_half_Avg_stripped_0GenericAffine.mat,1] \
    -t ${motionCorrDir}/${T2Base}_res_to-${epiBase}_stripped_to-${epiBase}_half_Avg_stripped_1InverseWarp.nii.gz
  else
    if [[ ${unwrapType} = "fieldmap" ]]; then  #fieldMap correction
      ####May need conditional for Siemens/GE down the road
      $ANTSPATH/antsApplyTransforms -d 3 \
      -i ${motionCorrDir}/${epiBase}_half_Avg.nii.gz \
      -r ${motionCorrDir}/sub-${subject}_ses-${session}_site-${site}_T1w_res_to-${epiBase}.nii.gz  \
      -o [${xfmDir}/sub-${subject}_ses-${session}_site-${site}_from-${epiBaseStub}+motCorAvg_to-T1w+rigid_xfm-stack.nii.gz,1] \
      -n Linear \
      -t [${fmapDir}/${T2Base}_res_to-${epiBase}_half_Avg_stripped_to_${epiBase}_half_Avg_unwrapped_stripped_0GenericAffine.mat,1] \
      -t ${fmapDir}/${T2Base}_res_to-${epiBase}_half_Avg_stripped_to_${epiBase}_half_Avg_unwrapped_stripped_1InverseWarp.nii.gz \
      -t ${motionCorrDir}/${epiBase}_half_Avg_stripped_to-${epiBase}_half_Avg_unwrapped_stripped_1Warp.nii.gz \
      -t ${motionCorrDir}/${epiBase}_half_Avg_stripped_to-${epiBase}_half_Avg_unwrapped_stripped_0GenericAffine.mat
    else  #Blip correction
        ####May need conditional for spin-echo down the road
      $ANTSPATH/antsApplyTransforms -d 3 \
      -i ${motionCorrDir}/${epiBase}_half_Avg.nii.gz \
      -r ${motionCorrDir}/sub-${subject}_ses-${session}_site-${site}_T1w_res_to-${epiBase}.nii.gz  \
      -o [${xfmDir}/sub-${subject}_ses-${session}_site-${site}_from-${epiBaseStub}+motCorAvg_to-T1w+rigid_xfm-stack.nii.gz,1] \
      -n Linear \
      -t [${blipDir}/${T2Base}_to_TopupTarget_0GenericAffine.mat,1] \
      -t ${blipDir}/${T2Base}_to_TopupTarget_1InverseWarp.nii.gz \
      -t ${motionCorrDir}/${epiBase}_half_Avg_stripped_to-Topup_corrected_stripped_1Warp.nii.gz \
      -t ${motionCorrDir}/${epiBase}_half_Avg_stripped_to-Topup_corrected_stripped_0GenericAffine.mat
    fi
  fi

  #.mat files will remain in the motCor directory

    #Log the task end time
  timeLog "e"
  sed -i "s/xfmCombine_TIMEEND/${timeStamp}/g" ${subject_log}

  ########################################

    ####################
    #  epiMask         #
    ####################

    #Log the task start time, set placeholder for end time
  timeLog "s"
  echo "task:epiMask,${timeStamp},epiMask_TIMEEND" >> ${subject_log}

  #Create a temporary mask
    #average the warpd EPI, temp BET (binarize), add to MNI152 mask
  maskDir=${researcher}/${project}/derivatives/func/mask

  if [[ ! -d $maskDir ]]; then
    mkdir $maskDir
  fi

  #Create an average of the warped EPI
  $FSLDIR/bin/fslmaths ${finalEpiDir}/sub-${subject}_ses-${session}_site-${site}_reg-${atlasName}+${atlasSize}_${epiBaseStub}+motCor.nii.gz \
  -Tmean ${finalEpiDir}/sub-${subject}_ses-${session}_site-${site}_reg-${atlasName}+${atlasSize}_${epiBaseStub}+motCorAvg.nii.gz

  #Create a mask of the motion corrected EPI, now in standard/atlas space
  $FSLDIR/bin/bet ${finalEpiDir}/sub-${subject}_ses-${session}_site-${site}_reg-${atlasName}+${atlasSize}_${epiBaseStub}+motCorAvg.nii.gz \
  ${maskDir}/sub-${subject}_ses-${session}_site-${site}_reg-${atlasName}+${atlasSize}_${epiBaseStub}+motCor -m -n
  $FSLDIR/bin/fslmaths ${maskDir}/sub-${subject}_ses-${session}_site-${site}_reg-${atlasName}+${atlasSize}_${epiBaseStub}+motCor_mask.nii.gz \
  -bin ${maskDir}/sub-${subject}_ses-${session}_site-${site}_reg-${atlasName}+${atlasSize}_${epiBaseStub}+motCor_mask.nii.gz -odt char

    #Log the task end time
  timeLog "e"
  sed -i "s/epiMask_TIMEEND/${timeStamp}/g" ${subject_log}

  ########################################

    ####################
    #  mocoPar         #
    ####################

    #Log the task start time, set placeholder for end time
  timeLog "s"
  echo "task:mocoPar,${timeStamp},mocoPar_TIMEEND" >> ${subject_log}

  #Motion parameters to par files
    #Raw: Rotations=Rad, Translations=mm
  MOCO_to_par ${motionCorrDir}/${epiBase}_motCorr_Rigid_MOCOparams.csv

  #Log the task end time
  timeLog "e"
  sed -i "s/mocoPar_TIMEEND/${timeStamp}/g" ${subject_log}

  ########################################

    ####################
    #  tissueWarp      #
    ####################

    #Log the task start time, set placeholder for end time
  timeLog "s"
  echo "task:tissueWarp,${timeStamp},tissueWarp_TIMEEND" >> ${subject_log}

  #Apply warp to tissue class files to put in final EPI space (itself in standard/atlas space
  for Tissue in 'GM' 'WM' 'CSF';
    do

    $ANTSPATH/antsApplyTransforms -d 3 \
    -i ${tisDir}/sub-${subject}_ses-${session}_site-${site}_seg-${Tissue}.nii.gz \
    -r ${finalEpiDir}/sub-${subject}_ses-${session}_site-${site}_reg-${atlasName}+${atlasSize}_${epiBaseStub}+motCorAvg.nii.gz  \
    -o ${tisDir}/sub-${subject}_ses-${session}_site-${site}_${epiBaseStub}_seg-${Tissue}.nii.gz \
    -n NearestNeighbor \
    -t ${anatToAtlasXfm}
  done

    #Log the task end time
  timeLog "e"
  sed -i "s/tissueWarp_TIMEEND/${timeStamp}/g" ${subject_log}

  ########################################

    ####################
    #  cleanup         #
    ####################

  #Cleanup all temp files
  rm ${splitList} ${warpedList}

done

  #Log the task end time
timeLog "e"
sed -i "s/epiPrep1_TIMEEND/${timeStamp}/g" ${subject_log}

#########################################################################################################

#End logging
chgrp -R ${group} ${tisDir} > /dev/null 2>&1
chmod -R g+rw ${tisDir} > /dev/null 2>&1
chgrp -R ${group} ${motionCorrDir} > /dev/null 2>&1
chmod -R g+rw ${motionCorrDir} > /dev/null 2>&1
chgrp -R ${group} ${blipDir} > /dev/null 2>&1
chmod -R g+rw ${blipDir} > /dev/null 2>&1
chgrp -R ${group} ${fmapDir} > /dev/null 2>&1
chmod -R g+rw ${fmapDir} > /dev/null 2>&1
chgrp -R ${group} ${xfmDir} > /dev/null 2>&1
chmod -R g+rw ${xfmDir} > /dev/null 2>&1
chgrp -R ${group} ${maskDir} > /dev/null 2>&1
chmod -R g+rw ${maskDir} > /dev/null 2>&1
chgrp -R ${group} ${finalEpiDir} > /dev/null 2>&1
chmod -R g+rw ${finalEpiDir} > /dev/null 2>&1
chgrp ${group} ${subject_log} > /dev/null 2>&1
chmod g+rw ${subject_log} > /dev/null 2>&1
date +"end:%Y-%m-%dT%H:%M:%S%z" >> ${subject_log}
echo "#--------------------------------------------------------------------------------" >> ${subject_log}
echo "" >> ${subject_log}

