#!/bin/bash

####################

ver=1.0.0
verDate=9/11/19

####################

#A script to take raw t1rho (short and long spin-lock) files and process:
#
#  1) Co-register secondary T1rho image(s) to primary (bfc corrected, skull-stripped); apply transform to raw secondar image(s)
#  2) Co-register primary T1rho to anatomical; create warp stack from T1rho to standard
#  3) Create T1rhoMap (native space); apply transforms to anat, standard space
#
# by Joel Bruss (joel-bruss@uiowa.edu)

#########################################################################################################

scriptName="T1rhoProcess.sh"
scriptDir=/Shared/nopoulos/nimg_core
atlasDir=/Shared/nopoulos/nimg_core/templates_human
userID=`whoami`
source $scriptDir/sourcePack.sh

t1rhoImages=""
spinLockTimes=""

#Source versions of programs used:
VER_afni=${VER_afni}
VER_ants=${VER_ants}
VER_fsl=${VER_fsl}
VER_t1rho=${VER_t1rho}

#########################################################################################################

printCommandLine() {
  echo ""
  echo "Usage: Usage: T1rhoProcess.sh --anatImage=AnatomicalImage --t1rhoImages=T1rhoImage1,T1rhoImage2,...T1rhoImageN --spinLockTimes=spinLockTime1,spinLockTime2,...spinLockTimeN --anatToAtlasXfm=anatToAtlasTransformStack --subject=sub --session=ses --site=site --researcher=researcher --project=project --researchGroup=researchGroup"
  echo ""
  echo "   where:"
  echo "     --anatImage:  Skull-stripped (preferably T2) anatomical.  This file must already have a corresponding warp to atlas"
  echo "     --t1rhoImages:  A comma-separated list of raw input T1rho.  This MUST be in the same order as the spin-lock times."
  echo "            *NOTE: The first T1rhoImage listed will be the 'target' that all other T1rho data will be co-registered to."
  echo "                   Further, this file will be co-registered to the anatomical."
  echo "            *NOTE2:  It's preferable to use low spin-lock image when co-registering to T2, high spin-lock if using T1."
  echo "     --spinLockTimes:  A comma-seperated list of spin-lock times, corresponding to input T1rho data."
  echo "     --anatToAtlasXfm:  Anatomical to standard/atlas transform stack"
  echo "            *Instruction set to get from T1/T2 to standard/atlas space"
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
    --t1rhoImages) #Input T1rho data to process
        t1rhoImages=$(get_arg1 "$1");
        export t1rhoImages
        if [[ "${t1rhoImages}" == "" ]]; then
          echo "Error: The input '--t1rhoImages' is required"
          exit 1
        fi
          shift;;
    --spinLockTimes) #Input T1rho spin-lock times (ms)
        spinLockTimes=$(get_arg1 "$1");
        export spinLockTimes
        if [[ "${spinLockTimes}" == "" ]]; then
          echo "Error: The input '--spinLockTimes' is required"
          exit 1
        fi
          shift;;
    --anatImage) #skull-stripped (preferably T2) anatomical, used as target for registration with first t1rhoImage.  This must correspond to the warp to atlas file.
        anatImage=$(get_arg1 "$1");
        export anatImage
        if [[ "${anatImage}" == "" ]]; then
          echo "Error: The input '--anatImage' is required"
          exit 1
        fi
        if [[ ! -e ${anatImage} ]]; then
          echo "Error Nonexistent or improper anatomical target specified.  Please check and try again with '--anatImage'"
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

subject_log=${researcher}/${project}/log/${subject}_${session}_${site}.log

echo '#--------------------------------------------------------------------------------' >> ${subject_log}
echo "ParentTask:T1rhoProcess" >> ${subject_log}
echo "script:${scriptDir}/${scriptName}" >> ${subject_log}
echo "software:AFNI,version:${VER_afni}" >> ${subject_log}
echo "software:ANTs,version:${VER_ants}" >> ${subject_log}
echo "software:FSL,version:${VER_fsl}" >> ${subject_log}
echo "software:T1rho,version:${VER_t1rho}" >> ${subject_log}
echo "owner: ${userID}" >> ${subject_log} >> ${subject_log}
date +"start:%Y-%m-%dT%H:%M:%S%z" >> ${subject_log} >> ${subject_log}

#########################################################################################################

#Data dependencies:
  #Final place for T1rho in standard/atlas, anat space
finalAtlasT1rhoDir=${researcher}/${project}/derivatives/anat/reg_${atlasName}_${atlasSize}
  if [[ ! -d ${finalAtlasT1rhoDir} ]]; then
    mkdir -p ${finalAtlasT1rhoDir}
  fi
finalNativeT1rhoDir=${researcher}/${project}/derivatives/anat/native
  if [[ ! -d ${finalNativeT1rhoDir} ]]; then
    mkdir -p ${finalNativeT1rhoDir}
  fi
  #T1rho prep directory
prepDir=${researcher}/${project}/derivatives/anat/prep/${subject}/${session}/t1rho
  if [[ ! -d ${prepDir} ]]; then
    mkdir -p ${prepDir}
  fi
  #Transform directory
xfmDir=${researcher}/${project}/derivatives/xfm/${subject}/${session}
  if [[ ! -d ${xfmDir} ]]; then
    mkdir -p ${xfmDir}
  fi
  #Check to make sure the number of T1rho inputs equals the number of spin-lock times given
t1rhoNum=`echo ${t1rhoImages} | awk -F"," '{print NF}'`
slNum=`echo ${spinLockTimes} | awk -F"," '{print NF}'`

if [[ ${t1rhoNum} -ne ${slNum} ]]; then
  echo "Error: The number of input T1rho files (${t1rhoNum}) does not match the number of input spin-lock times (${slNum})."
  exit 1
fi
  #Base name for anatImage
anatBase=`basename ${anatImage} | awk -F"." '{print $1}'`

########################################

#Affine Registration
affineReg()
{
  fixed=$1
  moving=$2
  outDir=$3

  fixedBase=`basename ${fixed} | awk -F"." '{print $1}'`
  movingBase=`basename ${moving} | awk -F"." '{print $1}'`

  $ANTSPATH/antsRegistration -d 3 --float 0 \
  --output [${outDir}/${movingBase}_to_${fixedBase}_,${outDir}/${movingBase}_to_${fixedBase}_Warped.nii.gz] \
  --interpolation BSpline[3] \
  --winsorize-image-intensities [0.005,0.995] \
  --use-histogram-matching 0 \
  --initial-moving-transform [${fixed},${moving},1] \
  --transform Rigid[0.1] \
  --metric MI[${fixed},${moving},1,32,Regular,0.25] \
  --convergence [1000x500x250x100,1e-6,10] \
  --shrink-factors 8x4x2x1 \
  --smoothing-sigmas 3x2x1x0vox \
  --transform Affine[0.1] \
  --metric MI[${fixed},${moving},1,32,Regular,0.25] \
  --convergence [1000x500x250x100,1e-6,10] \
  --shrink-factors 8x4x2x1 \
  --smoothing-sigmas 3x2x1x0vox
}

#N4 bias correction
biasCorrect()
{
  input=$1
  output=$2
  maskFlag=$3
  mask=$4

  if [[ ${maskFlag} -eq 0 ]]; then
    $ANTSPATH/N4BiasFieldCorrection -i ${input} -o ${output}
  else
    $ANTSPATH/N4BiasFieldCorrection -i ${input} -o ${output} -x ${mask}
  fi
}

#Creation of a binary mask
maskCreate()
{
  input=$1
  inBase=$2
  outDir=$3

  #Skullstrip
  $AFNIDIR/3dSkullStrip -input ${input} -prefix ${outDir}/${inBase}_mask.nii.gz

  #Binarize, conversion to float
  $AFNIDIR/3dcalc -a ${outDir}/${inBase}_mask.nii.gz -expr 'step(a)' -prefix ${outDir}/${inBase}_mask.nii.gz -overwrite -datum float

  #Slight smoothing to push mask past hard edges, then re-binarizing
  $AFNIDIR/3dmerge -1blur_fwhm 0.5 -doall -prefix ${outDir}/${inBase}_mask.nii.gz ${outDir}/${inBase}_mask.nii.gz -overwrite
  $AFNIDIR/3dcalc -a ${outDir}/${inBase}_mask.nii.gz -expr 'step(a)' -prefix ${outDir}/${inBase}_mask.nii.gz -overwrite -datum float

  #Some cases where the "origin" of the input and mask are off (e-06 values!) and N4 won't budge.  Force geometry on the mask
  $FSLDIR/bin/fslcpgeom ${input} ${outDir}/${inBase}_mask.nii.gz
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

#########################

  #Log the task start time, set placeholder for end time
  timeLog "s"
  echo "  task:Log T1rho data and spinlock times,start:${timeStamp},end:dataLog_TIMEEND" >> ${subject_log}

#Log the list of T1rho files and spin-lock times
echo ${spinLockTimes} >> ${prepDir}/_SLtimes
echo ${t1rhoImages} >> ${prepDir}/_SLfiles

  #Log the task end time
  timeLog "e"
  sed -i "s/dataLog_TIMEEND/${timeStamp}/g" ${subject_log}

#########################

#First spin-lock (0, 10, 30, 60, etc.) to Anatomical (e.g. T2_brain) - Affine
  #This will be the TSL file that all others are registered to (on their way to anat, standard)
baseT1rho=`echo ${t1rhoImages} | awk -F"," '{print $1}'`
basedir=`dirname ${baseT1rho}`
baseT1rhoName=`basename ${baseT1rho} | awk -F"." '{print $1}'`
baseTime=`echo ${spinLockTimes} | awk -F"," '{print $1}'`

  #Log the task start time, set placeholder for end time
  timeLog "s"
  echo "  task:base T1rho bias-correct,start:${timeStamp},end:baseBFC_TIMEEND" >> ${subject_log}

#Bias-field correct the target (preferably lower) spin-lock time
  #Temporary to get a file that is easier to skull-strip.  Feed this into 3dSkullstrip, create the mask, then redo N4 with the mask
biasCorrect ${baseT1rho} ${prepDir}/tmpT1rhoTarget_BFC.nii.gz 0

  #Log the task end time
  timeLog "e"
  sed -i "s/baseBFC_TIMEEND/${timeStamp}/g" ${subject_log}

#Create a binary mask of first TSL file
echo "...Creating a mask for ${baseT1rho}"

  #Log the task start time, set placeholder for end time
  timeLog "s"
  echo "  task:base T1rho mask creation,start:${timeStamp},end:baseMask_TIMEEND" >> ${subject_log}

  #Steps to: Skullstrip, create a mask
maskCreate ${prepDir}/tmpT1rhoTarget_BFC.nii.gz ${baseT1rhoName} ${prepDir}

  #Log the task end time
  timeLog "e"
  sed -i "s/baseMask_TIMEEND/${timeStamp}/g" ${subject_log}

  #Log the task start time, set placeholder for end time
  timeLog "s"
  echo "  task:base T1rho bias-correct pt. II,start:${timeStamp},end:baseBFC2_TIMEEND" >> ${subject_log}

  #Use the mask with raw data to get a better bias-field corrected image
biasCorrect ${baseT1rho} ${prepDir}/${baseT1rhoName}_BFC.nii.gz 1 ${prepDir}/${baseT1rhoName}_mask.nii.gz

  #Log the task end time
  timeLog "e"
  sed -i "s/baseBFC2_TIMEEND/${timeStamp}/g" ${subject_log}

  #Log the task start time, set placeholder for end time
  timeLog "s"
  echo "  task:base T1rho skull-strip,start:${timeStamp},end:baseStrip_TIMEEND" >> ${subject_log}

  #Skull-strip the volume before co-registering
$AFNIDIR/3dcalc -a ${prepDir}/${baseT1rhoName}_BFC.nii.gz -b ${prepDir}/${baseT1rhoName}_mask.nii.gz -expr 'a*step(b)' -prefix ${prepDir}/${baseT1rhoName}_BFC_brain.nii.gz -datum short

  #Log the task end time
  timeLog "e"
  sed -i "s/baseStrip_TIMEEND/${timeStamp}/g" ${subject_log}

#####################

#Co-register base T1rho to Anatomical (skull-stripped T1rho to skull-sripped Anatomical (e.g. T2_brain))
echo "...Co-registering ${baseT1rhoName} to ${anatBase}."

  #Log the task start time, set placeholder for end time
  timeLog "s"
  echo "  task:base T1rho reg to anat,start:${timeStamp},end:baseAnatReg_TIMEEND" >> ${subject_log}

affineReg ${anatImage} ${prepDir}/${baseT1rhoName}_BFC_brain.nii.gz ${prepDir}

cp ${prepDir}/${baseT1rhoName}_BFC_brain_to_${anatBase}_0GenericAffine.mat \
${xfmDir}/${subject}_${session}_${site}_from-T1rho_to-T1w+rigid_xfm-affine.mat

  #Log the task end time
  timeLog "e"
  sed -i "s/baseAnatReg_TIMEEND/${timeStamp}/g" ${subject_log}

  #Log the task start time, set placeholder for end time
  timeLog "s"
  echo "  task:Transform stack T1rho to atlas,start:${timeStamp},end:baseStack_TIMEEND" >> ${subject_log}

#Create the T1rho to atlas transform stack
$ANTSPATH/antsApplyTransforms -d 3 \
-i ${baseT1rho} \
-r ${atlasDir}/${atlasName}/${atlasSize}/${atlasName}_${atlasSize}_T1w.nii.gz \
-o [${xfmDir}/${subject}_${session}_${site}_from-T1rho_to-${atlasName}+${atlasSize}_xfm-stack.nii.gz,1] \
-n Linear \
-t ${xfmDir}/${subject}_${session}_${site}_from-T1w+rigid_to-${atlasName}+${atlasSize}_xfm-stack.nii.gz \
-t ${xfmDir}/${subject}_${session}_${site}_from-T1rho_to-T1w+rigid_xfm-affine.mat

  #Log the task end time
  timeLog "e"
  sed -i "s/baseStack_TIMEEND/${timeStamp}/g" ${subject_log}

#Make a list of the final T1rho files (will be added to after other TSL files are processed)
newList=${baseT1rho}
newTime=${baseTime}

#########################

#Co-register the remaining spin-lock T1rho files to the base T1rho file
j=2
while [[ ${j} -le ${t1rhoNum} ]]
  do

  tmpT1rho=`echo ${t1rhoImages} | awk -F"," -v var=${j} '{print $var}'`
  tmpTime=`echo ${spinLockTimes} | awk -F"," -v var=${j} '{print $var}'`

  tmpT1rhoName=`basename ${tmpT1rho} | awk -F"." '{print $1}'`
  tmpT1rhodir=`dirname ${tmpT1rho}`

  echo "...Creating a mask for ${tmpT1rhoName}"

    #Log the task start time, set placeholder for end time
    timeLog "s"
    echo "  task:seconary T1rho bias-correct,start:${timeStamp},end:secondaryBFC_TIMEEND" >> ${subject_log}

  #Bias-field correct the longer spin-lock times
    #Temporary to get a file that is easier to skull-strip.  Feed this into 3dSkullstrip, create the mask, then redo N4 with the mask
  biasCorrect ${tmpT1rho} ${prepDir}/tmpT1rhoSecondary${i}_BFC.nii.gz 0

    #Log the task end time
    timeLog "e"
    sed -i "s/secondaryBFC_TIMEEND/${timeStamp}/g" ${subject_log}

    #Log the task start time, set placeholder for end time
    timeLog "s"
    echo "  task:secondary T1rho mask creation,start:${timeStamp},end:secondaryMask_TIMEEND" >> ${subject_log}

    #Steps to: Skullstrip, create a mask
  maskCreate ${prepDir}/tmpT1rhoSecondary${i}_BFC.nii.gz ${tmpT1rhoName} ${prepDir}

    #Log the task end time
    timeLog "e"
    sed -i "s/secondaryMask_TIMEEND/${timeStamp}/g" ${subject_log}

    #Log the task start time, set placeholder for end time
    timeLog "s"
    echo "  task:secondary T1rho bias-correct pt. II,start:${timeStamp},end:secondaryBFC2_TIMEEND" >> ${subject_log}

    #Use the mask with raw data to get a better bias-field corrected image
  biasCorrect ${tmpT1rho} ${prepDir}/${tmpT1rhoName}_BFC.nii.gz 1 ${prepDir}/${tmpT1rhoName}_mask.nii.gz

    #Log the task end time
    timeLog "e"
    sed -i "s/secondaryBFC2_TIMEEND/${timeStamp}/g" ${subject_log}

    #Log the task start time, set placeholder for end time
    timeLog "s"
    echo "  task:secondary T1rho skull-strip,start:${timeStamp},end:secondaryStrip_TIMEEND" >> ${subject_log}

    #Skull-strip the volume before co-registering but STILL use the mask
  3dcalc -a ${prepDir}/${tmpT1rhoName}_BFC.nii.gz -b ${prepDir}/${tmpT1rhoName}_mask.nii.gz -expr 'a*step(b)' -prefix ${prepDir}/${tmpT1rhoName}_BFC_brain.nii.gz -datum short

    #Log the task end time
    timeLog "e"
    sed -i "s/secondaryStrip_TIMEEND/${timeStamp}/g" ${subject_log}
  
  echo "...Co-registering ${tmpT1rhoName} to ${baseT1rhoName}"

    #Log the task start time, set placeholder for end time
    timeLog "s"
    echo "  task:seconary T1rho reg to base,start:${timeStamp},end:secondaryBaseReg_TIMEEND" >> ${subject_log}

  $ANTSPATH/antsRegistration -d 3 --float 1 --verbose 1 -u 1 -n BSpline[3] \
  -r [${prepDir}/${baseT1rhoName}_BFC_brain.nii.gz,${prepDir}/${tmpT1rhoName}_BFC_brain.nii.gz,1] \
  -t Rigid[0.1] \
  -m MI[${prepDir}/${baseT1rhoName}_BFC_brain.nii.gz,${prepDir}/${tmpT1rhoName}_BFC_brain.nii.gz,1,32,Regular,0.25] \
  -c [1000x500x250x100,1e-6,10] \
  -f 8x4x2x1 \
  -s 3x2x1x0vox \
  -t Affine[0.1] \
  -m MI[${prepDir}/${baseT1rhoName}_BFC_brain.nii.gz,${prepDir}/${tmpT1rhoName}_BFC_brain.nii.gz,1,32,Regular,0.25] \
  -c [1000x500x250x100,1e-6,10] \
  -f 8x4x2x1 \
  -s 3x2x1x0vox \
  -t SyN[0.1,3,0] \
  -m CC[${prepDir}/${baseT1rhoName}_BFC_brain.nii.gz,${prepDir}/${tmpT1rhoName}_BFC_brain.nii.gz,1,4] \
  -c [100x70x50x20,1e-6,10] \
  -f 8x4x2x1 \
  -s 3x2x1x0vox \
  -o [${prepDir}/${tmpT1rhoName}_BFC_to_${baseT1rhoName}_,${prepDir}/${tmpT1rhoName}_BFC_to_${baseT1rhoName}_Warped.nii.gz]

    #Log the task end time
    timeLog "e"
    sed -i "s/secondaryBaseReg_TIMEEND/${timeStamp}/g" ${subject_log}

  echo "...Applying warps to raw ${tmpT1rhoName}."

    #Log the task start time, set placeholder for end time
    timeLog "s"
    echo "  task:apply transform to raw seconary T1rho,start:${timeStamp},end:secondaryWarped_TIMEEND" >> ${subject_log}

  $ANTSPATH/antsApplyTransforms -d 3 \
  -i ${tmpT1rho} \
  -r ${baseT1rho} \
  -o ${prepDir}/${tmpT1rhoName}_to_${baseT1rhoName}_Warped.nii.gz \
  -n BSpline[3] \
  -t ${prepDir}/${tmpT1rhoName}_BFC_to_${baseT1rhoName}_0GenericAffine.mat

  #Add to the new list of the final T1rho files
  newList="${newList} ${prepDir}/${tmpT1rhoName}_to_${baseT1rhoName}_Warped.nii.gz"
  newTime="${newTime} ${tmpTime}"

    #Log the task end time
    timeLog "e"
    sed -i "s/secondaryWarped_TIMEEND/${timeStamp}/g" ${subject_log}
  
  let j=j+1
done

#Reformat the final T1rho list/times to csv
t1rhoList=`echo $newList |sed 's/^ *//g' | sed -e 's/\ /,/g'`
t1rhoTimes=`echo $newTime |sed 's/^ *//g' | sed -e 's/\ /,/g'`

#########################

#Create the T1rhoMap

echo "...Creating the T1rhoMap"

  #Log the task start time, set placeholder for end time
  timeLog "s"
  echo "  task:T1rhoMap creation,start:${timeStamp},end:T1rhoMapCreate_TIMEEND" >> ${subject_log}

$T1RHOPATH/T1rhoMap \
--inputVolumes "${t1rhoList}" \
--t1rhoTimes "${t1rhoTimes}" \
--mappingAlgorithm Linear \
--maxTime 400.0 \
--threshold 50 \
--outputFilename ${prepDir}/T1rhoMap.nii.gz \
--outputExpConstFilename ${prepDir}/T1rhoMap_ExpConstant.nii.gz \
--outputConstFilename ${prepDir}/T1rhoMap_Constant.nii.gz \
--outputRSquaredFilename ${prepDir}/T1rhoMap_R2.nii.gz

  #Log the task end time
  timeLog "e"
  sed -i "s/T1rhoMapCreate_TIMEEND/${timeStamp}/g" ${subject_log}

#########################

#Warp T1rhoMap to native (anat) and atlas (e.g. MNI152)

echo "...Warping the T1rhoMap to anat, atlas space"

  #Log the task start time, set placeholder for end time
  timeLog "s"
  echo "  task:Warping T1rhoMap to anat and atlas,start:${timeStamp},end:T1rhoMapWarp_TIMEEND" >> ${subject_log}

for outSpace in 'native' 'atlas';
  do

  #Source the transform, output directory
  if [[ "${outSpace}" == "native" ]]; then
    xfmStack=${xfmDir}/${subject}_${session}_${site}_from-T1rho_to-T1w+rigid_xfm-affine.mat
    outFile=${finalNativeT1rhoDir}/${subject}_${session}_${site}_T1rho.nii.gz
    refFile=${anatImage}
  else
    xfmStack=${xfmDir}/${subject}_${session}_${site}_from-T1rho_to-${atlasName}+${atlasSize}_xfm-stack.nii.gz
    outFile=${finalAtlasT1rhoDir}/${subject}_${session}_${site}_reg-${atlasName}+${atlasSize}_T1rho.nii.gz
    refFile=${atlasDir}/${atlasName}/${atlasSize}/${atlasName}_${atlasSize}_T1w.nii.gz
  fi

  $ANTSPATH/antsApplyTransforms -d 3 \
  -i ${prepDir}/T1rhoMap.nii.gz \
  -r ${refFile} \
  -o ${outFile} \
  -n Linear \
  -t ${xfmStack}
done

  #Log the task end time
  timeLog "e"
  sed -i "s/T1rhoMapWarp_TIMEEND/${timeStamp}/g" ${subject_log}

#########################################################################################################

#End logging
chgrp -R ${group} ${prepDir} > /dev/null 2>&1
chmod -R g+rw ${prepDir} > /dev/null 2>&1
chgrp -R ${group} ${finalAtlasT1rhoDir} > /dev/null 2>&1
chmod -R g+rw ${finalAtlasT1rhoDir} > /dev/null 2>&1
chgrp -R ${group} ${finalNativeT1rhoDir} > /dev/null 2>&1
chmod -R g+rw ${finalNativeT1rhoDir} > /dev/null 2>&1
chgrp -R ${group} ${xfmDir} > /dev/null 2>&1
chmod -R g+rw ${xfmDir} > /dev/null 2>&1
chgrp ${group} ${subject_log} > /dev/null 2>&1
chmod g+rw ${subject_log} > /dev/null 2>&1
date +"end:%Y-%m-%dT%H:%M:%S%z" >> ${subject_log}
echo "#--------------------------------------------------------------------------------" >> ${subject_log}
echo "" >> ${subject_log}

