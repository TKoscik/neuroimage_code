#!/bin/bash

####################

ver=1.0.0
verDate=5/15/19

####################


# Using FSL to:
#  1a) fsl_prepare_fieldmap (Siemens only) to create a fieldMap (rad/s) from an input phase/magnitude set
#      epi_reg to unwrap the motCorAvg EPI input
#  1b) Convert Phase to rad/s; truncate Magnitude to a finite intensity range and use to drive registraiton to motCorMean.
#      Apply registration to Phase/Mag, use epi_reg to unwrap the motCorAvg EPI input
#  2)  Co-register unwrapped EPI to anat target (T2)
#
# Output consisists of:
#
#  1) Unwrapped EPI
#  2) Instruction set to get from unwrapped EPI to anat space

# by Joel Bruss (joel-bruss@uiowa.edu)

#########################################################################################################

scriptName="functionalFmapUnwrapping.sh"
scriptDir=/Shared/nopoulos/nimg_core
source $scriptDir/sourcePack.sh

#Source versions of programs used:
VER_afni=${VER_afni}
VER_ants=${VER_ants}
VER_fsl=${VER_fsl}

#########################################################################################################

printCommandLine() {
  echo ""
  echo "Usage: functionalFmapUnwrapping.sh --phase=phase --magnitude=magnitude --fmapType=fmapType --T1=T1 --T2=T2 --anatMask=anatMask --epiAvg=epiAvg --deltaTE=deltaTE --peDir=peDIR --fmapDir=fmapDir --subject=sub"
  echo "       --session=ses --site=site --researcher=researcher --project=project  --researchGroup=researchGroup"
  echo ""
  echo "   where:"
  echo "     --phase:  Phase image"
  echo "     --magnitude:  Magnitude file (pos. phase encoding direction)"
  echo "        *Can be AP/PA or LR/RL pairs"
  echo "     --fmapType:  siemens -OR- ge"
  echo "     --T1:  T1 (with skull)"
  echo "     --T2:  T2 (with skull)"
  echo "     --anatMask:  Anatomcial mask used to aid in registration"
  echo "     --epiAvg:  motCorAvg (motion-corrected half-TR target EPI average)"
  echo "     --deltaTE:  Also referred to as Effective Echo Spacing, in seconds, derived from EPI"
  echo "        *Common values are Siemens=0.00056, GE=0.00064"
  echo "     --peDir:  Phase encoding direction of EPI"
  echo "        *Either x/-x (for RR/LR) or y/-y (for PA/AP)"
  echo "        *If negative, sign can be in front or behind the direction (e.g. -x or x-)"
  echo "     --fmapDir:  fmapDir (location to write fieldMap processing files to)"
  echo ""
  echo "    Project-specific variables:"
  echo "     --subject:  Subject"
  echo "     --session:  Session"
  echo "     --site:  Site"
  echo "     --researcher:  Researcher"
  echo "     --project:  Project"
  echo "     --researchGroup:  Permissions group"
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

if [ $# -lt 16 ] ; then printCommandLine; exit 0; fi
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
    --phase)  #Phase image
        phase=$(get_arg1 "$1");
        export phase
        if [[ "${phase}" == "" ]]; then
          echo "Error: The input '--phase' is required"
          exit 1
        fi
        if [[ ! -e $phase ]]; then
          echo "Error Nonexistent or improper phase image specified.  Please check and try again with '--phase'"
          exit 1
        fi
          shift;;
    --magnitude) #Magnitude IMage
        magnitude=$(get_arg1 "$1");
        export magnitude
        if [[ "${magnitude}" == "" ]]; then
          echo "Error: The input '--magnitude' is required"
          exit 1
        fi
        if [[ ! -e $magnitude ]]; then
          echo "Error Nonexistent or improper magnitude image specified.  Please check and try again with '--magnitude'"
          exit 1
        fi
          shift;;
    --fmapType) #siemens -OR- ge
        fmapType=$(get_arg1 "$1");
        export fmapType
        if [[ "${fmapType}" != "siemens" && "${fmapType}" != "ge" ]]; then
            echo "Error: The input '--fmapType' is required (either 'siemens' or 'ge')"
            exit 1
        fi
          shift;;
    --T1) #T1 (with skull), target for fmap unwrapping.  Must be in the same space as T2 and anatMask.  Used with fsl_prepare_fieldmap.
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
    --T2) #T2 (with skull).  Must be in the same space as T1 and anatMask.  Used for co-registration to unwrapped EPI.
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
          shift;;
    --anatMask) #Anatomical mask, same space as anatTarget (e.g. /Shared/nopoulos/sca_pilot/derivatives/anat/mask/sub-231_ses-328zk16wb6_site-00201_mask-brain.nii.gz)
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
    --epiAvg) #Motion-corrected half-TR target EPI avg. to unwrap
        epiAvg=$(get_arg1 "$1");
        export epiAvg
        if [[ "${epiAvg}" == "" ]]; then
          echo "Error: The input '--epiAvg' is required"
          exit 1
        fi
        if [[ ! -e $epiAvg ]]; then
          echo "Error Nonexistent or improper motCorAvg EPI file specified.  Please check and try again with '--epiAvg'"
          exit 1
        fi
          shift;;
    --dwellTime) #Also referred to as Effective Echo Spacing, derived from EPI file; in seconds
        dwellTime=$(get_arg1 "$1");
        export dwellTime
        if [[ "${dwellTime}" == "" ]]; then
          echo "Error: The input '--dwellTime' is required"
          exit 1
        fi
          shift;;
    --peDir) #Phase encoding direction of the EPI (x/-x/y/-y).  Negative sign can be on either side of direction (e.g. -x or x-)
        peDir=$(get_arg1 "$1");
        export peDir
        if [[ "${dwellTime}" == "" ]]; then
          echo "Error: The input '--peDir' is required (one of x/-x/x-/y/-y/y-)"
          exit 1
        fi
        if [[ "${peDir}" != "x" && "${peDir}" != "-x" && "${peDir}" != "x-" && "${peDir}" != "y" && "${peDir}" != "-y" && "${peDir}" != "y-" ]]; then
          echo "Error: The input '--peDir' is required (one of x/-x/x-/y/-y/y-)"
          exit 1
        fi
          shift;;
    --fmapDir) #Place to write intermediate files (e.g. /Shared/nopoulos/sca_pilot/derivatives/func/prep/sub-231_ses-328zk16wb6/fmap)
        fmapDir=$(get_arg1 "$1");
        export fmapDir
        if [[ "${fmapDir}" == "" ]]; then
          echo "Error: The input '--fmapDir' is required"
          exit 1
        else
          if [[ ! -d $fmapDir ]]; then
            mkdir -p $fmapDir
          fi
        fi
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

echo '  #--------------------------------------------------------------------------------' >> ${subject_log}
echo "  ParentTask:functionalFmapUnwrapping" >> ${subject_log}
echo "  script:${scriptDir}/${scriptName}" >> ${subject_log}
echo "  software:AFNI,version:${VER_afni}" >> ${subject_log}
echo "  software:ANTs,version:${VER_ants}" >> ${subject_log}
echo "  software:fsl,version:${VER_fsl}" >> ${subject_log}
tmpDate=`date +"start:%Y-%m-%dT%H:%M:%S%z"`
echo "  ${tmpDate}" >> ${subject_log}

#########################################################################################################

########################################

#Mask Creation
maskPrep()
{
  input=$1
  inBase=`basename $input | awk -F"." '{print $1}'`
  inDir=`dirname $input`

  $AFNIDIR/3dSkullStrip -input $input -mask_vol -prefix $inDir/${inBase}_mask.nii.gz
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

 #Source the directory for tissue class data
tisDir=${researcher}/${project}/derivatives/anat/segmentation
 #Source the basename of the input epiAvg
epiAvgBase=`basename ${epiAvg} | awk -F"." '{print $1}'`

  ##################
  #  anat_prep     #
  ##################

  #Log the task start time, set placeholder for end time
timeLog "s"
echo "  task:anat_Prep,${timeStamp},anatPrep_TIMEEND" >> ${subject_log}

#Determine sampling dimensions from epiAvg
origSpacing=`${ANTSPATH}/PrintHeader ${epiAvg} 1`

#Resample the anatomical and mask to match the EPI
resampleFile ${T1} ${fmapDir} T1 ${origSpacing} ${epiAvg} 0
resampleFile ${anatMask} ${fmapDir} T1_mask ${origSpacing} ${epiAvg} 1

#Strip the anatomical
$FSLDIR/bin/fslmaths ${fmapDir}/T1_res_to-${epiAvgBase}.nii.gz -mas ${fmapDir}/T1_mask_res_to-${epiAvgBase}.nii.gz ${fmapDir}/T1_res_to-${epiAvgBase}_stripped.nii.gz

#Create a wmSeg file, resampled to epiAvg
$FSLDIR/bin/fslmaths ${tisDir}/sub-${subject}_ses-${session}_site-${site}_seg-WM.nii.gz \
-thr 0.5 -bin ${fmapDir}/T1_wmseg.nii.gz -odt char
resampleFile ${fmapDir}/T1_wmseg.nii.gz ${fmapDir} T1_wmseg ${origSpacing} ${epiAvg} 1
fslmaths ${fmapDir}/T1_wmseg_res_to-${epiAvgBase}.nii.gz -bin ${fmapDir}/T1_wmseg_res_to-${epiAvgBase}.nii.gz -odt char

#Resample the T2 to match the epiMotCor file
T2Base=`basename ${T2} | awk -F"." '{print $1}'`
resampleFile ${T2} ${fmapDir} ${T2Base} ${origSpacing} ${epiAvg} 0

#Skull-strip the resampled T2
$FSLDIR/bin/fslmaths ${fmapDir}/${T2Base}_res_to-${epiAvgBase}.nii.gz -mas ${fmapDir}/T1_mask_res_to-${epiAvgBase}.nii.gz \
${fmapDir}/${T2Base}_res_to-${epiAvgBase}_stripped.nii.gz

  #Log the task end time
timeLog "e"
sed -i "s/anatPrep_TIMEEND/${timeStamp}/g" ${subject_log}

########################################


if [[ "${fmapType}" == "siemens" ]]; then  #Siemens fieldMap

  #Going with tried and true deltaTE value for Siemens.  This value *could* be different and would need to be derived from DICOM data
  deltaTE=2.46

    ####################
    #  magnitude_prep  #
    ####################

    #Log the task start time, set placeholder for end time
  timeLog "s"
  echo "  task:magnitude_Prep,${timeStamp},magnitudePrep_TIMEEND" >> ${subject_log}

  #Create a magnitude mask, erode mask, strip magnitude
  $FSLDIR/bin/bet ${magnitude} ${fmapDir}/Magnitude -m -n
  fslmaths ${fmapDir}/Magnitude_mask.nii.gz -ero -bin ${fmapDir}/Magnitude_mask_eroded.nii.gz -odt char
  fslmaths ${magnitude} -mas ${fmapDir}/Magnitude_mask_eroded.nii.gz ${fmapDir}/Magnitude_stripped.nii.gz

    #Log the task end time
  timeLog "e"
  sed -i "s/magnitudePrep_TIMEEND/${timeStamp}/g" ${subject_log}

  ########################################

    ##################
    #  fmap_prep     #
    ##################

  #Check to see if fieldMap has already been created (don't need to do for every EPI)
  if [[ ! -e ${fmapDir}/fieldmap_prepped.nii.gz ]]; then

      #Log the task start time, set placeholder for end time
    timeLog "s"
    echo "  task:fmap_Prep,${timeStamp},fmapPrep_TIMEEND" >> ${subject_log}

    #Create the prepped fieldMap, rad/s (input deltaTE in ms)
    $FSLDIR/bin/fsl_prepare_fieldmap SIEMENS ${phase} ${fmapDir}/Magnitude_stripped.nii.gz ${fmapDir}/fieldmap_prepped ${deltaTE}

      #Log the task end time
    timeLog "e"
    sed -i "s/fmapPrep_TIMEEND/${timeStamp}/g" ${subject_log}
  fi

  ########################################

    ####################
    #  fmap_Unwrap     #
    ####################

    #Log the task start time, set placeholder for end time
  timeLog "s"
  echo "  task:fmap_unwrap,${timeStamp},fmapUnwrap_TIMEEND" >> ${subject_log}

  $FSLDIR/bin/epi_reg --echospacing=${dwellTime} --wmseg=${fmapDir}/T1_wmseg_res_to-${epiAvgBase}.nii.gz \
  --fmap=${fmapDir}/fieldmap_prepped.nii.gz --fmapmag=${magnitude} \
  --fmapmagbrain=${fmapDir}/Magnitude_stripped.nii.gz --pedir="${peDir}" \
  --epi=${epiAvg} --t1=${fmapDir}/T1_res_to-${epiAvgBase}.nii.gz \
  --t1brain=${fmapDir}/T1_res_to-${epiAvgBase}_stripped.nii.gz --out=${fmapDir}/${epiAvgBase}_unwrapped

    #Log the task end time
  timeLog "e"
  sed -i "s/fmapUnwrap_TIMEEND/${timeStamp}/g" ${subject_log}

  ########################################

else  #GE fieldMap

    ##################
    #  fmap_prep     #
    ##################

  #Check to see if fieldMap has already been created (will need to do for every EPI since GE's don't match by defualt)
  if [[ ! -e ${fmapDir}/fieldmap_prepped.nii.gz ]]; then

      #Log the task start time, set placeholder for end time
    timeLog "s"
    echo "  task:fmap_Prep,${timeStamp},fmapPrep_TIMEEND" >> ${subject_log}

    #Convert Phase to rad/s (2pi)
    $FSLDIR/bin/fslmaths $phase -mul 6.28 ${fmapDir}/raw_phase_to_${epiAvgBase}_rads.nii.gz

    #Strip the phase_rads file, regularize (use the eroded motCorAvg mask), create the fieldmap_prepped file
    $FSLDIR/bin/fslmaths ${fmapDir}/raw_phase_to_${epiAvgBase}_rads.nii.gz -mas ${fmapDir}/${epiAvgBase}_mask_eroded.nii.gz \
    ${fmapDir}/${epiAvgBase}_fieldmap_prepped.nii.gz
    $FSLDIR/bin/fugue --loadfmap=${fmapDir}/${epiAvgBase}_fieldmap_prepped.nii.gz -s 1 --savefmap=${fmapDir}/${epiAvgBase}_fieldmap_prepped.nii.gz
    $FSLDIR/bin/fugue --loadfmap=${fmapDir}/${epiAvgBase}_fieldmap_prepped.nii.gz --despike --savefmap=${fmapDir}/${epiAvgBase}_fieldmap_prepped.nii.gz
    $FSLDIR/bin/fugue --loadfmap=${fmapDir}/${epiAvgBase}_fieldmap_prepped.nii.gz -m --savefmap=${fmapDir}/${epiAvgBase}_fieldmap_prepped.nii.gz

    #strip the magnitude image
    $FSLDIR/bin/fslmaths $magnitude -mas ${fmapDir}/${epiAvgBase}_mask_eroded.nii.gz \
    ${fmapDir}/raw_magnitude_to_${epiAvgBase}_stripped.nii.gz

      #Log the task end time
    timeLog "e"
    sed -i "s/fmapPrep_TIMEEND/${timeStamp}/g" ${subject_log}
  fi

  ########################################

    ####################
    #  fmap_Unwrap     #
    ####################

    #Log the task start time, set placeholder for end time
  timeLog "s"
  echo "  task:fmap_unwrap,${timeStamp},fmapUnwrap_TIMEEND" >> ${subject_log}

  $FSLDIR/bin/epi_reg --echospacing=${dwellTime} --wmseg=${fmapDir}/T1_wmseg_res_to-${epiAvgBase}.nii.gz \
  --fmap=${fmapDir}/${epiAvgBase}_fieldmap_prepped.nii.gz --fmapmag=${magnitude} \
  --fmapmagbrain=${fmapDir}/raw_magnitude_to_${epiAvgBase}_stripped.nii.gz --pedir="${peDir}" \
  --epi=${epiAvg} --t1=${fmapDir}/T1_res_to-${epiAvgBase}.nii.gz \
  --t1brain=${fmapDir}/T1_res_to-${epiAvgBase}_stripped.nii.gz --out=${fmapDir}/${epiAvgBase}_unwrapped

    #Log the task end time
  timeLog "e"
  sed -i "s/fmapUnwrap_TIMEEND/${timeStamp}/g" ${subject_log}

  ########################################
fi

  ####################
  #  unwrap_Mask     #
  ####################

  #Log the task start time, set placeholder for end time
timeLog "s"
echo "  task:unwrap_Mask,${timeStamp},unwrapMask_TIMEEND" >> ${subject_log}

#Create a mask of the unwrapped b0
maskPrep ${fmapDir}/${epiAvgBase}_unwrapped.nii.gz

  #Log the task end time
timeLog "e"
sed -i "s/unWrapMask_TIMEEND/${timeStamp}/g" ${subject_log}

########################################

  ####################
  #  unwrap_Strip    #
  ####################

  #Log the task start time, set placeholder for end time
timeLog "s"
echo "  task:unwrap_Strip,${timeStamp},unwrapStrip_TIMEEND" >> ${subject_log}

#Skull-strip the Topup-corrected data
3dcalc -a ${fmapDir}/${epiAvgBase}_unwrapped.nii.gz -b ${fmapDir}/${epiAvgBase}_unwrapped_mask.nii.gz -expr 'a*step(b)' \
-prefix ${fmapDir}/${epiAvgBase}_unwrapped_stripped.nii.gz

  #Log the task end time
timeLog "e"
sed -i "s/unwrapStrip_TIMEEND/${timeStamp}/g" ${subject_log}

########################################

  ####################
  #  unwrap_toAnat   #
  ####################

  #Log the task start time, set placeholder for end time
timeLog "s"
echo "  task:unwrap_toAnat,${timeStamp},unwrapToAnat_TIMEEND" >> ${subject_log}

#Perform registration, anat to unwrapped EPI
  #Co-register the resampled, stripped T2, to epiMotCor
blipTarget=${fmapDir}/${epiAvgBase}_unwrapped_stripped.nii.gz
blipTargetBase=`basename $blipTarget | awk -F"." '{print $1}'`
anatStrippedBase=`basename ${fmapDir}/${T2Base}_res_to-${epiAvgBase}_stripped.nii.gz | awk -F"." '{print $1}'`

  #Changed the intitial moving transform to 0 (geometric center) from 1 (image intensities)

$ANTSPATH/antsRegistration -d 3 --float 0 \
--output ${fmapDir}/${anatStrippedBase}_to_${blipTargetBase}_ \
--interpolation Linear \
--winsorize-image-intensities [0.005,0.995] \
--use-histogram-matching 0 \
--initial-moving-transform [${blipTarget},${fmapDir}/${anatStrippedBase}.nii.gz,1] \
--transform Rigid[0.1] \
--metric MI[${blipTarget},${fmapDir}/${anatStrippedBase}.nii.gz,1,32,Regular,0.25] \
--convergence [1000x500x250x100,1e-6,10] \
--shrink-factors 8x4x2x1 \
--smoothing-sigmas 3x2x1x0vox \
--transform Affine[0.1] \
--metric MI[${blipTarget},${fmapDir}/${anatStrippedBase}.nii.gz,1,32,Regular,0.25] \
--convergence [1000x500x250x100,1e-6,10] \
--shrink-factors 8x4x2x1 \
--smoothing-sigmas 3x2x1x0vox \
--transform SyN[0.1,3,0] \
--metric CC[${blipTarget},${fmapDir}/${anatStrippedBase}.nii.gz,1,4] \
--convergence [100x70x50x20,1e-6,10] \
--shrink-factors 8x4x2x1 \
--smoothing-sigmas 3x2x1x0vox

  #Log the task end time
timeLog "e"
sed -i "s/unwrapToAnat_TIMEEND/${timeStamp}/g" ${subject_log}

########################################

#########################################################################################################

#End logging
chgrp -R ${fmapDir} > /dev/null 2>&1
chmod -R g+rw ${fmapDir} > /dev/null 2>&1
chgrp ${group} ${subject_log} > /dev/null 2>&1
chmod g+rw ${subject_log} > /dev/null 2>&1
tmpDate=`date +"end:%Y-%m-%dT%H:%M:%S%z"`
echo "  ${tmpDate}" >> ${subject_log}
echo "  #--------------------------------------------------------------------------------" >> ${subject_log}

