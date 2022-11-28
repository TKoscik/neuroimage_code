#!/bin/bash
#Requirements: FSL
rawdata=../rawdata
derivatives=../derivatives

# subject=/Users/zjpeters/biomarkersOfECT/rawdata/sub-P001/session01/dti
# topup --imain=$subject/all_b0_z-1.nii.gz --datain=$subject/acqparams.txt --out=$subject/topupresults_column2 --config=$subject/b02b0_7t.cnf --fout=$subject/topupfield_column2 --iout=$subject/unwarpedimages_column2
while read participant_id; do
  [ "$participant_id" == participant_id ] && continue;  # skips the header
  while read session_id; do
    [ "$session_id" == session_id ] && continue;  # skips the header
    # set up input/output images
    jsonFile=${rawdata}/${participant_id}/${session_id}/dti/${participant_id}_${session_id}_*.json
    dti=${rawdata}/${participant_id}/${session_id}/dti/${participant_id}_${session_id}_*DTI.nii.gz
    # need to go through and fix the naming for "DTI_-_Rev"
    croppedDti=${rawdata}/${participant_id}/${session_id}/dti/${participant_id}_${session_id}_DTI_cropped.nii.gz
    b0=${rawdata}/${participant_id}/${session_id}/dti/${participant_id}_${session_id}_DTI_b0.nii.gz
    xDim=$(fslval $dti dim1)
    yDim=$(fslval $dti dim2)
    zDim=$(fslval $dti dim3)
    tDim=$(fslval $dti dim4)
    bvals=$(cat ${rawdata}/${participant_id}/${session_id}/dti/${participant_id}_${session_id}_*.bval)
    nb0s=0
    for i in $bvals; do
      if [ $i == 0 ]; then
        ((nb0s++))
      fi
    done
    # need to first check if image has even number of slices in each direction
    if [ $((xDim%2)) != 0 ]; then
      ((xDim--))
    fi
    if [ $((yDim%2)) != 0 ]; then
      ((yDim--))
    fi
    if [ $((zDim%2)) != 0 ]; then
      ((zDim--))
    fi
    # shouldn't need an if statement, since it's a good idea to make sure they all go through the same process anyway
#    if [ $((xDim%2)) != 0 ] || [ $((yDim%2)) != 0 ] || [ $((zDim%2)) != 0 ]; then
    fslroi $dti $croppedDti 0 $xDim 0 $yDim 0 $zDim 0 $tDim
    fslroi $croppedDti $b0For 0 $xDim 0 $yDim 0 $zDim 0 $nb0s
    # we only need the b0 of images from the reverse image, don't need to crop twice
    fslroi $dtiRev $b0Rev 0 $xDim 0 $yDim 0 $zDim 0 $nb0s
    # create the b0
    fslmerge -t $all_b0 $b0For $b0Rev

    ped=$(jq '.PhaseEncodingDirection' $jsonFile)
    trt=$(jq '.TotalReadoutTime' $jsonFile)
    echo "Phase encoding direction: $ped"
    echo "Total readout time: $trt"

    echo "Creating new acqparams file for $participant_id $session_id"
    acqparams=${rawdata}/${participant_id}/${session_id}/dti/acqparams.txt
    if [ ! -f $acqparams ]; then
      touch $acqparams
    else
      rm $acqparams
      touch $acqparams
    fi
    will now write acqparams files that have one row for each b0
    if [ $ped == "\"j\"" ]; then
      for i in $(seq 1 $nb0s); do
        printf "0 1 0 $trt\n" >> $acqparams
      done
      for i in $(seq 1 $nb0s); do
        printf -- "0 -1 0 $trt\n" >> $acqparams
      done
    elif [ $ped == "\"j-\"" ]; then
      for i in $(seq 1 $nb0s); do
        printf "0 -1 0 $trt\n" >> $acqparams
      done
      for i in $(seq 1 $nb0s); do
        printf -- "0 1 0 $trt\n" >> $acqparams
      done
    elif [ $ped == "\"i\"" ]; then
      for i in $(seq 1 $nb0s); do
        printf "1 0 0 $trt\n" >> $acqparams
      done
      for i in $(seq 1 $nb0s); do
        printf -- "-1 0 0 $trt\n" >> $acqparams
      done
    elif [ $ped == "\"i-\"" ]; then
      for i in $(seq 1 $nb0s); do
        printf "-1 0 0 $trt\n" >> $acqparams
      done
      for i in $(seq 1 $nb0s); do
        printf -- "1 0 0 $trt\n" >> $acqparams
      done
    fi
    # if [ $ped == "\"COL\"" ]; then
    #   for i in $(seq 1 $nb0s); do
    #     printf "0 1 0 $trt\n" >> $acqparams
    #   done
    #   for i in $(seq 1 $nb0s); do
    #     printf -- "0 -1 0 $trt\n" >> $acqparams
    #   done
    # elif [ $ped == "\"ROW\"" ]; then
    #   for i in $(seq 1 $nb0s); do
    #     printf "1 0 0 $trt\n" >> $acqparams
    #   done
    #   for i in $(seq 1 $nb0s); do
    #     printf -- "-1 0 0 $trt\n" >> $acqparams
    #   done
    # fi
    cat $acqParams
  done < ${rawdata}/${participant_id}/sessions.tsv
done < ${rawdata}/participants.tsv
