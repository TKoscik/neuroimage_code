#!/bin/bash
#Requirements: FSL

rawdata=../rawdata
derivatives=../derivatives
experimental=threeGeneAnalysis  # will be the name of the experiment that then names the folder within derivatives folder

if [ ! -d $derivatives/$experimental ]; then
  mkdir $derivatives/$experimental
fi

# section that reads the appropriate subjects to be analyzed from the participants.tsv file
while read participant_id age sex genotype; do
  [ "$participant_id" == participant_id ] && continue;  # skips the header
  for i in $derivatives/${participant_id}/*_FA.nii.gz; do
    smooth=$derivatives/${participant_id}/${participant_id}_dti_FA_smooth.nii.gz
    fslmaths $i -s 0.2 $smooth
    denoise=${smooth//smooth/denoised}
    DenoiseImage -d 3 -i $smooth -o $denoise -v
    # min=`fslstats $denoise -R | awk '{print $1}'`
    # max=`fslstats $denoise -R | awk '{print $2}'`
    # scaling=`echo "scale=5; 1.0 / ( $max - $min )" | bc`
    # dataScaled=$derivatives/${experimental}/${filename%.nii.gz}_scaled
    # fslmaths $denoise -sub $min -mul $scaling $dataScaled
    cp $denoise ${derivatives}/${experimental}
  done
done < $rawdata/participants.tsv

cd ${derivatives}/${experimental}
tbss_1_preproc *.nii.gz
../../code/tbss_2_reg_mouse -n
../../code/tbss_3_postreg_mouse -S
#mkdir masks
#for i in *mask.nii.gz; do
#  mv $i ./masks/$i
#done



#$script_dir/tbss_2_reg_nonlin_mouse -n
#$script_dir/tbss_3_postreg_nonlin_mouse -S
#
# cd $tbss_dir
#
# tbss_1_preproc *.nii.gz
# $script_dir/tbss_2_reg_nonlin_mouse -n
# $script_dir/tbss_3_postreg_nonlin_mouse -S
#
# cd stats
# #fsleyes all_FA -b 0,0.8 mean_FA_skeleton -b 0.2,0.8 -l Green
# tbss_4_prestats 0.25
