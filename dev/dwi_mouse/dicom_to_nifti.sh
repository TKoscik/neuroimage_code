#!/bin/bash

if [[ ( $@ == "--help") ||  $@ == "-h" ]]; then
	echo "Usage: $0 -e /path/to/experiment"
	echo "Runs dicom to nifti conversion on an entire dataset using dcm2niix"
  echo "Input should be the bids formatted experiment folder"
  echo "Dicoms to be converted should be inside the sourcedata folder"
  echo "If rawdata and derivatives folders don't exist, this script will create them"
	exit 0
fi

workingDir=$1
if [ ${workingDir:-1} == '/' ]; then
  workingDir=${workingDir::-1}
fi
sourcedata=${workingDir}/sourcedata
rawdata=${workingDir}/rawdata
derivatives=${workingDir}/derivatives

dicom_to_nifti(){
  # this will create a nifti with the format sub-{SubjectID}_ses-{DateOfCollection}_{ImageModality}.nii.gz
  dcm2niix -b y -z y -i y -o $rawdata -f sub-%n_ses-%t_%d $actDir
}

if [ -d $sourcedata ]; then
  if [ ! -d $rawdata ]; then
    mkdir $rawdata
  fi
  if [ ! -d $derivatives ]; then
    mkdir $derivatives
  fi
  for actDir in $sourcedata/*; do
    if [ -d $actDir ]; then
      dicom_to_nifti
    fi
  done
else
  echo "Unable to find sourcedata folder at $sourcedata"
  exit 1
fi
