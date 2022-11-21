#!/bin/bash

if [[ ( $@ == "--help") ||  $@ == "-h" ]]; then
	echo "Usage: $0 /path/to/experiment"
	echo "Attempts to organize rawdata folder based on filenames"
  echo "Input should be the bids formatted experiment folder"
  exit 0
fi

workingDir=$1
if [ ${workingDir:-1} == '/' ]; then
  workingDir=${workingDir::-1}
fi
sourcedata=${workingDir}/sourcedata
rawdata=${workingDir}/rawdata
derivatives=${workingDir}/derivatives

# since dicom_to_nifti outputs directly into rawdata, should be lots of niftis
# assumes that there will be no underscores within the session ID
for actImage in $rawdata/*.nii.gz; do
	subID=${actImage#*/rawdata/}
	subID=${subID%_ses*}
	sesID=${actImage#*${subID}_}
	sesID=${sesID%%_*}
	echo $subID $sesID
	if [ ! -d $rawdata/$subID ]; then
		mkdir $rawdata/$subID
	fi
	if [ ! -d $rawdata/$subID/$sesID ]; then
		mkdir $rawdata/$subID/$sesID
	fi
	mv ${actImage%nii.gz}*  $rawdata/$subID/$sesID/
done
