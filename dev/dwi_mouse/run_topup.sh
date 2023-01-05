#!/bin/bash
#Requirements: FSL
rawdata=../rawdata
derivatives=../derivatives
code=/media/zjpeters/Samsung_T5/inc/code/mousedwi/data

# subject=/Users/zjpeters/biomarkersOfECT/rawdata/sub-P001/session01/dti
# topup --imain=$subject/all_b0_z-1.nii.gz --datain=$subject/acqparams.txt --out=$subject/topupresults_column2 --config=$subject/b02b0_7t.cnf --fout=$subject/topupfield_column2 --iout=$subject/unwarpedimages_column2
while read participant_id; do
  [ "$participant_id" == participant_id ] && continue;  # skips the header
  while read session_id; do
    [ "$session_id" == session_id ] && continue;  # skips the header
    # set up input/output images
    echo "Running topup on $participant_id $session_id"
    all_b0=${rawdata}/${participant_id}/${session_id}/dti/${participant_id}_${session_id}_Ax_DTI_all_b0.nii.gz
    acqparams=${rawdata}/${participant_id}/${session_id}/dti/acqparams.txt
    topupfield=${derivatives}/${participant_id}/${participant_id}_${session_id}_Ax_DTI_topupfield.nii.gz
    unwarped=${derivatives}/${participant_id}/${participant_id}_${session_id}_Ax_DTI_unwarped.nii.gz
    topupresults=${derivatives}/${participant_id}/${participant_id}_${session_id}_Ax_DTI_topup_results.nii.gz
    # need to crop nodif_brain_mask.nii.gz to match the size of the dti image
    # need to create index.txt file to work as input to index option, n of idx is equal to dim4
    topup --imain=$all_b0 --datain=$acqparams --out=$topupresults --config=$code/b02b0Mouse.cnf --fout=$topupfield --iout=$unwarped &
    nDTI=$(fslval $all_b0 dim4)
    idx=""
    for ((i=1; i<=$nDTI; i+=1)); do idx="$idx 1"; done
    echo $idx > index.txt
    eddy_openmp --imain=sub-107_ses-20200623142658_dti.nii.gz --mask=nodif_brain_mask_trunc.nii.gz --acqp=acqparams.txt --index=index.txt --bvecs=sub-107_ses-20200623142658_DTI_8-Shot_-4_nex-_scan_1.bvec --bvals=sub-107_ses-20200623142658_DTI_8-Shot_-4_nex-_scan_1.bval --topup=topupresults --out=eddycorrected
  done < ${rawdata}/${participant_id}/sessions.tsv
done < ${rawdata}/participants.tsv
topup --imain=scan1_b0.nii.gz --datain=acqparams.txt --out=topupresults --config=/media/zjpeters/Samsung_T5/inc/code/mousedwi/data/b02b0Mouse.cnf --fout=topupfield --iout=unwarped

eddy_openmp --imain=data --mask=my_hifi_b0_brain_mask --acqp=acqparams.txt --index=index.txt --bvecs=bvecs --bvals=bvals --topup=topupresults --out=eddy_corrected_data
