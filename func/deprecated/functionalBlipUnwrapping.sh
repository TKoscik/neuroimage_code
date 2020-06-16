#!/bin/bash

####################

ver=1.0.0
verDate=5/15/19

####################


# Using FSL to:
#  1a) topup/applytopup to unwrap a pair of blips (phase-encode-reversed pairs (Gradient Echo))
#  to create a b0 target (and mask) that ANTs will use to co-register to (constraining to non-linear
#  registration in the phase-encoding direction)
#  1b)   ###Placeholder for Spin Echo EPI
#  2)  Co-register b0 target to anat target (T2)
#
# Output consisists of:
#
#  1) Unwrapped EPI
#  2) Instruction set to get from unwrapped EPI to anat space

# by Joel Bruss (joel-bruss@uiowa.edu)

#########################################################################################################

scriptName="functionalBlipUnwrapping.sh"
scriptDir=/Shared/nopoulos/nimg_core
source $scriptDir/sourcePack.sh

#Source versions of programs used:
VER_afni=${VER_afni}
VER_ants=${VER_ants}
VER_fsl=${VER_fsl}

#########################################################################################################

printCommandLine() {
  echo ""
  echo "Usage: functionalBlipUnwrapping.sh --blipUp=blipUp --blipDown=blipDown --blipType=blipType --T2=T2 --anatMask=anatMask --outDir=outdir"
  echo "       --subject=sub --session=ses --site=site --researcher=researcher --project=project  --researchGroup=researchGroup"
  echo ""
  echo "   where:"
  echo "     --blipUp:  blipUp file (neg. phase encoding direction)"
  echo "     --blipDown:  blipDown file (pos. phase encoding direction)"
  echo "        *Can be AP/PA or LR/RL pairs"
  echo "     --blipType:  gradientecho -OR- spinecho"
  echo "     --T2:  T2 to register unwrapped b0 to"
  echo "     --anatMask:  Anatomcial mask used to aid in registration"
  echo "     --outDir:  outDir (location to write Topup processing files to)"
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

if [ $# -lt 12 ] ; then printCommandLine; exit 0; fi
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
    --blipUp)  #Neg. phase encoding file
        blipUp=$(get_arg1 "$1");
        export blipUp
        if [[ "${blipUp}" == "" ]]; then
          echo "Error: The input '--blipUp' is required"
          exit 1
        fi
        if [[ ! -e $blipUp ]]; then
          echo "Error Nonexistent or improper blipUp file specified.  Please check and try again with '--blipUp'"
          exit 1
        fi
          shift;;
    --blipDown) #Pos. phase encoding file
        blipDown=$(get_arg1 "$1");
        export blipDown
        if [[ "${blipDown}" == "" ]]; then
          echo "Error: The input '--blipDown' is required"
          exit 1
        fi
        if [[ ! -e $blipDown ]]; then
          echo "Error Nonexistent or improper blipDown file specified.  Please check and try again with '--blipDown'"
          exit 1
        fi
          shift;;
    --blipType) #gradientecho -OR- spinecho
        blipType=$(get_arg1 "$1");
        export blipType
        if [[ "${blipType}" != "gradientecho" && "${blipType}" != "spinecho" ]]; then
            echo "Error: The input '--blipType' is required (either 'gradientecho' or 'spinecho')"
            exit 1
        fi
          shift;;
    --T2) #T2 (with skull) (e.g. /Shared/nopoulos/sca_pilot/derivatives/anat/native/sub-231_ses-328zk16wb6_site-00201_T2w_brain.nii.gz).  Must be in the same space as anatMask.
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
          shift;;
    --anatMask) #Anatomical mask, same space as T2 (e.g. /Shared/nopoulos/sca_pilot/derivatives/anat/mask/sub-231_ses-328zk16wb6_site-00201_mask-brain.nii.gz)
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
    --outDir) #Place to write intermediate files (e.g. /Shared/nopoulos/sca_pilot/derivatives/func/prep/sub-231_ses-328zk16wb6/blipDir)
        outDir=$(get_arg1 "$1");
        export outDir
        if [[ "${outDir}" == "" ]]; then
          echo "Error: The input '--outDir' is required"
          exit 1
        else
          if [[ ! -d $outDir ]]; then
            mkdir -p $outDir
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
echo "  ParentTask:functionalBlipUnwrapping" >> ${subject_log}
echo "  script:${scriptDir}/${scriptName}" >> ${subject_log}
echo "  software:AFNI,version:${VER_afni}" >> ${subject_log}
echo "  software:ANTs,version:${VER_ants}" >> ${subject_log}
echo "  software:fsl,version:${VER_fsl}" >> ${subject_log}
tmpDate=`date +"start:%Y-%m-%dT%H:%M:%S%z"`
echo "  ${tmpDate}" >> ${subject_log}

#########################################################################################################

########################################

#Blip motion correction, averaging, parameter logging, merging
blipPrep()
{
  bu=$1
  bd=$2

  #motion correct, average
  $AFNIDIR/3dvolreg -verbose -tshift 0 -Fourier -zpad 4 -prefix $outDir/blipUp_motCor.nii.gz -base 1 $bu
  $FSLDIR/bin/fslmaths $outDir/blipUp_motCor.nii.gz -Tmean $outDir/blipUp_motCorMean.nii.gz

  $AFNIDIR/3dvolreg -verbose -tshift 0 -Fourier -zpad 4 -prefix $outDir/blipDown_motCor.nii.gz -base 1 $bd
  $FSLDIR/bin/fslmaths $outDir/blipDown_motCor.nii.gz -Tmean $outDir/blipDown_motCorMean.nii.gz

  #Merge the blips
  $FSLDIR/bin/fslmerge -t $outDir/mergedMeanB0.nii.gz $outDir/blipUp_motCorMean.nii.gz $outDir/blipDown_motCorMean.nii.gz

  #Populate a file with mock readout times, phase encoding direction
  echo "0 -1 0 1" >> $outDir/acqParams.txt
  echo "0 1 0 1" >> $outDir/acqParams.txt
}

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
########################################

  ####################
  #  blip_Unwrap     #
  ####################

#Check for Gradient Echo or Spin Echo EPI
if [[ "${blipType}" == "gradientecho" ]]; then  #Gradient Echo EPI

    #Log the task start time, set placeholder for end time
  timeLog "s"
  echo "  task:blip_unwrap(g),${timeStamp},blipUnwrap_g_TIMEEND" >> ${subject_log}

  #Prepare the blips
  blipPrep $blipUp $blipDown $outDir

  #Run topup, apply to create a non-distorted target
  $FSLDIR/bin/topup --imain=${outDir}/mergedMeanB0.nii.gz \
  --datain=${outDir}/acqParams.txt \
  --config=${FSLDIR}/etc/flirtsch/b02b0.cnf \
  --out=${outDir}/Coefficients_Mean \
  --iout=${outDir}/Magnitudes_Mean \
  --fout=${outDir}/TopupField_Mean \
  --logout=${outDir}/Topup_log_Mean

  $FSLDIR/bin/applytopup --imain=${outDir}/blipUp_motCorMean.nii.gz,${outDir}/blipDown_motCorMean.nii.gz \
  --datain=${outDir}/acqParams.txt \
  --inindex=1,2 \
  --topup=${outDir}/Coefficients_Mean \
  --out=${outDir}/Topup_corrected

    #Log the task end time
  timeLog "e"
  sed -i "s/blipUnwrap_g_TIMEEND/${timeStamp}/g" ${subject_log}

  ########################################

    ####################
    #  blip_Mask       #
    ####################

    #Log the task start time, set placeholder for end time
  timeLog "s"
  echo "  task:blip_Mask,${timeStamp},blipMask_TIMEEND" >> ${subject_log}

  #Create a mask of the unwrapped b0
  maskPrep ${outDir}/Topup_corrected.nii.gz

    #Log the task end time
  timeLog "e"
  sed -i "s/blipMask_TIMEEND/${timeStamp}/g" ${subject_log}

  ########################################

    ####################
    #  blip_Strip     #
    ####################

    #Log the task start time, set placeholder for end time
  timeLog "s"
  echo "  task:blip_Strip,${timeStamp},blipStrip_TIMEEND" >> ${subject_log}

  #Skull-strip the Topup-corrected data
  3dcalc -a ${outDir}/Topup_corrected.nii.gz -b ${outDir}/Topup_corrected_mask.nii.gz -expr 'a*step(b)' \
  -prefix ${outDir}/Topup_corrected_stripped.nii.gz

  #Log the task end time
  timeLog "e"
  sed -i "s/blipStrip_TIMEEND/${timeStamp}/g" ${subject_log}

  ########################################

    ##################
    #  anat_prep     #
    ##################

    #Log the task start time, set placeholder for end time
  timeLog "s"
  echo "  task:anat_Prep,${timeStamp},anatPrep_TIMEEND" >> ${subject_log}

  #Determine sampling dimensions from epiAvg
  origSpacing=`${ANTSPATH}/PrintHeader ${outDir}/Topup_corrected.nii.gz 1`

  #Resample the T2 and mask to match the EPI
  resampleFile ${T2} ${outDir} T2 ${origSpacing} ${outDir}/Topup_corrected.nii.gz 0
  resampleFile ${anatMask} ${outDir} T2_mask ${origSpacing} ${outDir}/Topup_corrected.nii.gz 1

  #Strip the T2
  $FSLDIR/bin/fslmaths ${outDir}/T2_res_to-Topup_corrected.nii.gz -mas ${outDir}/T2_mask_res_to-Topup_corrected.nii.gz \
  ${outDir}/T2_res_to-Topup_corrected_stripped.nii.gz

    #Log the task end time
  timeLog "e"
  sed -i "s/anatPrep_TIMEEND/${timeStamp}/g" ${subject_log}

  ########################################

    ####################
    #  blip_toAnat     #
    ####################

    #Log the task start time, set placeholder for end time
  timeLog "s"
  echo "  task:blip_toAnat,${timeStamp},blipToAnat_TIMEEND" >> ${subject_log}

  #Co-register the unwrapped b0 with the anatomical target (higher resolution (anat) to lower resolution (b0))
  $ANTSPATH/antsRegistration --dimensionality 3 --float 0 \
  --output [${outDir}/${T2Base}_to_TopupTarget_,${outDir}/${T2Base}_to_TopupTarget_Warped.nii.gz] \
  --interpolation Linear \
  --winsorize-image-intensities [0.005,0.995] \
  --use-histogram-matching 0 \
  --initial-moving-transform [${outDir}/Topup_corrected.nii.gz,${outDir}/T2_res_to-Topup_corrected_stripped.nii.gz,0] \
  --transform Rigid[0.1] \
  --metric MI[${outDir}/Topup_corrected.nii.gz,${outDir}/T2_res_to-Topup_corrected_stripped.nii.gz,1,32,Regular,0.25] \
  --convergence [1000x500x250x100,1e-6,10] \
  --shrink-factors 8x4x2x1 \
  --smoothing-sigmas 3x2x1x0vox \
  --transform Affine[0.1] \
  --metric MI[${outDir}/Topup_corrected.nii.gz,${outDir}/T2_res_to-Topup_corrected_stripped.nii.gz,1,32,Regular,0.25] \
  --convergence [1000x500x250x100,1e-6,10] \
  --shrink-factors 8x4x2x1 \
  --smoothing-sigmas 3x2x1x0vox \
  --transform SyN[0.1,3,0] \
  --metric CC[${outDir}/Topup_corrected.nii.gz,${outDir}/T2_res_to-Topup_corrected_stripped.nii.gz,1,4] \
  --convergence [100x70x50x20,1e-6,10] \
  --shrink-factors 8x4x2x1 \
  --smoothing-sigmas 3x2x1x0vox

    #Log the task end time
  timeLog "e"
  sed -i "s/blipToAnat_TIMEEND/${timeStamp}/g" ${subject_log}

  ########################################

else #Spin Echo EPI

   echo "Haven't incorported spinecho yet.  Sorry"

fi

#########################################################################################################

#End logging
chgrp -R ${group} ${outDir} > /dev/null 2>&1
chmod -R ${outDir} > /dev/null 2>&1
chgrp -R ${group} ${outDir} > /dev/null 2>&1
chmod -R ${outDir} > /dev/null 2>&1
chgrp ${group} ${subject_log} > /dev/null 2>&1
chmod g+rw ${subject_log} > /dev/null 2>&1
tmpDate=`date +"end:%Y-%m-%dT%H:%M:%S%z"`
echo "  ${tmpDate}" >> ${subject_log}
echo "  #--------------------------------------------------------------------------------" >> ${subject_log}

