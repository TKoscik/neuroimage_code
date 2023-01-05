#!/bin/bash
#Requirements: FSL, ants, RATS_MM

# currently set to run from code folder of BIDS formatted project, will eventually
# be set up as a function so that the input will be the project directory containing
# the rawdata/derivatives folder, without the need for updating syntax
# expects a 'participants.tsv' file inside of the rawdata folder as defined by bids

rawdata=../rawdata
derivatives=../derivatives

run_dtifit(){
  echo "Extract b0 images"
  dtiDir=$rawdata/${participant_id}/dti
  outputDir=$derivatives/${participant_id}
  # below assume 2 b0 images

  fslroi ${dtiDir}/${participant_id}_dti.nii.gz ${dtiDir}/${participant_id}_b0 0 2
  fslmaths ${dtiDir}/${participant_id}_b0.nii.gz -Tmean ${dtiDir}/${participant_id}_b0_mean
  echo "Run bias field correction"
  N4BiasFieldCorrection -d 3 -i ${dtiDir}/${participant_id}_b0_mean.nii.gz -o [${dtiDir}/${participant_id}_b0_bf_corr.nii.gz,${dtiDir}/${participant_id}_b0_bfwarp.nii.gz]
  fslmaths ${dtiDir}/${participant_id}_dti.nii.gz -div ${dtiDir}/${participant_id}_b0_bfwarp.nii.gz ${dtiDir}/${participant_id}_bf_corr.nii.gz
  echo "Extracting brain mask for $participant_id"
  RATS_MM -t 2500 -v 350 -k 4 ${dtiDir}/${participant_id}_b0_mean.nii.gz ${dtiDir}/${participant_id}_b0_mean_mask.nii.gz
  echo "Resample input to isotropic"
  3dresample -dxyz 0.2 0.2 0.2 -prefix ${dtiDir}/${participant_id}_200um.nii.gz -input ${dtiDir}/${participant_id}_bf_corr.nii.gz
  3dresample -dxyz 0.2 0.2 0.2 -prefix ${dtiDir}/nodif_brain_mask_200um.nii.gz -input ${dtiDir}/nodif_brain_mask.nii.gz
  # i use brainsuite to make my masks by hand, so this next line is my fix for the flipped view dimensions
  # fslswapdim ${dtiDir}/nodif_brain_mask_200um.nii.gz -x y z ${dtiDir}/nodif_brain_mask_200um.nii.gz

  # fslchpixdim ${dtiDir}/${participant_id}_200um.nii.gz 1 1 1 ${dtiDir}/${participant_id}_1mm.nii.gz
  # fslchpixdim ${dtiDir}/nodif_brain_mask_200um.nii.gz 1 1 1 ${dtiDir}/nodif_brain_mask_1mm.nii.gz
  # fslswapdim ${dtiDir}/nodif_brain_mask_200um.nii.gz -x y z ${dtiDir}/nodif_brain_mask_1mm.nii.gz
  echo "Running eddy current correction and DTIFit on $participant_id"
  eddy_correct ${dtiDir}/${participant_id}_200um.nii.gz ${dtiDir}/${participant_id}_200um 0
  dtifit -k ${dtiDir}/${participant_id}_200um -o ${outputDir}/${participant_id}_dti -m ${dtiDir}/nodif_brain_mask_200um.nii.gz -r ${dtiDir}/bvecs -b ${dtiDir}/bvals #names files based on first seven characters of the original filename, this can be adjusted by changing "${dti:0:7} to the length of characters you want
}
# section that reads the appropriate subjects to be analyzed from the participants.tsv file
# have a version that includes sessions as well, but want to make it optional
while read participant_id age sex genotype; do
  [ "$participant_id" == participant_id ] && continue;  # skips the header
    if [ ! -d ${rawdata}/${participant_id}/dti ]; then
      echo "No DTI data for $participant_id"
      continue
    fi
    if [ ! -d $derivatives/$participant_id ]; then
      mkdir ${derivatives}/${participant_id}
    fi
    if [ -f $derivatives/${participant_id}/${participant_id}_dti_FA.nii.gz ]; then
      echo "DTIFit has already been run for $participant_id"
      continue
    fi
    echo $participant_id $age $sex $genotype; # prints the current subject info
    run_dtifit &
done < $rawdata/participants.tsv
