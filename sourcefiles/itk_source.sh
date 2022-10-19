#!/bin/bash

## Basic version check ##
this_itk_source_ver="2018091101"
master_itk_source_ver=$(grep this_itk_source_ver "/Shared/pinc/sharedopt/apps/sourcefiles/itk_source.sh"  | head -n+1 | tail -n-1 | awk -F\" '{print $2}')
echo " "
if [ $master_itk_source_ver -gt $this_itk_source_ver ]; then
  echo "There is a newer version of this source file in /Shared/pinc/sharedopt/apps/sourcefiles/"
  echo "You might want to consider updating to it."
  echo "If you have questions, feel free to contact Jason Evans (jason-evans@uiowa.edu)"
  echo " "
else
 :
fi

## Set some basic Variables ##
kernel="$(uname -s)"
hardware="$(uname -m)"

## What version of ITK do we want to use? ##
selected_itk_ver="4.13.1"

if [  -z "$ITKDIR" ]; then
  ## The actual commands for setting up FSL ## 
  export ITKDIR="/Shared/pinc/sharedopt/apps/itk/${kernel}/${hardware}/${selected_itk_ver}"
  export PATH=${PATH}:${ITKDIR}/bin
  export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${ITKDIR}/lib
  echo "ITK v${current_ITK_ver} should now be configured and ready for use."
else
  ## Check to see if ITK is already configured ##
  current_ITK_ver=$(awk -F/ '{ print $9}' <<<"${ITKDIR}")
  if [ -z "$current_ITK_ver" ]; then
    echo "Something went wrong.  Please conatact Jason Evans (jason-evans@uiowa.edu)"
  else
    echo "ITK has already been configured.  The version is v${current_ITK_ver}"
  fi
fi
