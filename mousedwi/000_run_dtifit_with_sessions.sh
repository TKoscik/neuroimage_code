#!/bin/bash
#Requirements: FSL, ants, RATS_MM

# currently set to run from code folder of BIDS formatted project, will eventually
# be set up as a function so that the input will be the project directory containing
# the rawdata/derivatives folder, without the need for updating syntax
# expects a 'participants.tsv' file inside of the rawdata folder as defined by bids

rawdata=../rawdata
derivatives=../derivatives

run_dtifit(){
  dtiDir=$rawdata/${participant_id}/${session_id}/dti
  outputDir=$derivatives/${participant_id}
  # below assume 2 b0 images

  echo "Extracting b0 images"
  fslroi ${dtiDir}/${participant_id}_${session_id}_dti.nii.gz ${outputDir}/${participant_id}_${session_id}_b0 0 2
  fslmaths ${outputDir}/${participant_id}_${session_id}_b0.nii.gz -Tmean ${outputDir}/${participant_id}_${session_id}_b0_mean
  echo "Runing bias field correction for $participant_id $ session_id"
  N4BiasFieldCorrection -d 3 -i ${outputDir}/${participant_id}_${session_id}_b0_mean.nii.gz -o [${outputDir}/${participant_id}_${session_id}_b0_bf_corr.nii.gz,${outputDir}/${participant_id}_${session_id}_b0_bfwarp.nii.gz]
  fslmaths ${dtiDir}/${participant_id}_${session_id}_dti.nii.gz -div ${outputDir}/${participant_id}_${session_id}_b0_bfwarp.nii.gz ${outputDir}/${participant_id}_${session_id}_bf_corr.nii.gz
  echo "Extracting brain mask for $participant_id $session_id"
  RATS_MM -t 2500 -v 350 -k 4 ${outputDir}/${participant_id}_${session_id}_b0_mean.nii.gz ${outputDir}/${participant_id}_${session_id}_b0_mean_mask.nii.gz
  echo "Resample $participant_id $ session_id input to isotropic space"
  3dresample -dxyz 0.2 0.2 0.2 -prefix ${outputDir}/${participant_id}_${session_id}_200um.nii.gz -input ${outputDir}/${participant_id}_${session_id}_bf_corr.nii.gz
  3dresample -dxyz 0.2 0.2 0.2 -prefix ${outputDir}/${participant_id}_${session_id}_nodif_brain_mask_200um.nii.gz -input ${dtiDir}/nodif_brain_mask.nii.gz
  # i use brainsuite to make my masks by hand, so this next line is my fix for the flipped view dimensions
  # fslswapdim ${dtiDir}/nodif_brain_mask_200um.nii.gz -x y z ${dtiDir}/nodif_brain_mask_200um.nii.gz

  # fslchpixdim ${dtiDir}/${participant_id}_200um.nii.gz 1 1 1 ${dtiDir}/${participant_id}_1mm.nii.gz
  # fslchpixdim ${dtiDir}/nodif_brain_mask_200um.nii.gz 1 1 1 ${dtiDir}/nodif_brain_mask_1mm.nii.gz
  # fslswapdim ${dtiDir}/nodif_brain_mask_200um.nii.gz -x y z ${dtiDir}/nodif_brain_mask_1mm.nii.gz
  echo "Running eddy current correction and DTIFit on $participant_id $ session_id"
  eddy_correct ${outputDir}/${participant_id}_${session_id}_200um.nii.gz ${outputDir}/${participant_id}_${session_id}_200um 0
  dtifit -k ${outputDir}/${participant_id}_${session_id}_200um -o ${outputDir}/dtifit/${participant_id}_${session_id}_dti -m ${outputDir}/${participant_id}_${session_id}_nodif_brain_mask_200um.nii.gz -r ${dtiDir}/bvecs -b ${dtiDir}/bvals #names files based on first seven characters of the original filename, this can be adjusted by changing "${dti:0:7} to the length of characters you want
}
# section that reads the appropriate subjects to be analyzed from the participants.tsv file
# have a version that includes sessions as well, but want to make it optional
while read participant_id age sex genotype; do
  [ "$participant_id" == participant_id ] && continue;  # skips the header
    if [ ! -f $rawdata/${participant_id}/sessions.tsv ]; then
      echo "No sessions file for $participant_id $ session_id!"
      continue
    else
      while read session_id acq_date; do
        [ "$session_id" == session_id ] && continue;
        #subRename=${participant_id}_${session_id}_dti
        if [ ! -d $rawdata/${participant_id}/${session_id}/dti ]; then
          echo "No DTI data for $participant_id $session_id"
          continue
        fi
        if [ ! -f $rawdata/${participant_id}/${session_id}/dti/nodif_brain_mask.nii.gz ]; then
          echo "No brain mask for $participant_id $session_id"
          continue
        fi
        if [ -f $derivatives/${participant_id}/${participant_id}_${session_id}_FA.nii.gz ]; then
          echo "DTIFit has already been run for $participant_id"
          continue
        fi
        if [ ! -d $derivatives/$participant_id ]; then
          mkdir ${derivatives}/${participant_id}
        fi
        if [ ! -d ${derivatives}/${participant_id}/dtifit ]; then
          mkdir ${derivatives}/${participant_id}/dtifit
        fi
        echo $participant_id $session_id; # prints the current subject info
        run_dtifit
      done < $rawdata/${participant_id}/sessions.tsv
    fi
done < $rawdata/participants.tsv
