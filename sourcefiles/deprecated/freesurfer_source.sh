#!/bin/bash

## Basic version check ##
this_freesurfer_source_ver="2018042001"
master_freesurfer_source_ver=$(grep this_freesurfer_source_ver "/Shared/pinc/sharedopt/apps/sourcefiles/freesurfer_source.sh"  | head -n+1 | tail -n-1 | awk -F\" '{print $2}')
echo " "
if [ $master_freesurfer_source_ver -gt $this_freesurfer_source_ver ]; then
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
selected_freesurfer_ver="$1"

## What version of FreeSurfer do we want to run? ##
base_freesurfer_ver="6.0.0"

## Was there input to set the version from outside this script ##
if [ -z "${selected_freesurfer_ver}" ]; then
  selected_freesurfer_ver="${base_freesurfer_ver}"
fi

## Do we want to config FSL??? Use: yes/no ##
CONFIG_CUSTOM_FSL="yes"

## Do we want to set the SUBJECTS_DIR now??? If no, leave blank.##
SUBJECTS_DIR=""
if [ -z "$SUBJECTS_DIR" ]; then
  :
else
  export SUBJECTS_DIR
fi

## FreeSurfer requires FSL.  If FSL is not in your path already, FreeSurfer ##
## will use it's built-in version of FSL.  In some cases, this may cause    ##
## issues with processing.  This allows for FSL to be set before FreeSurfer ##
if [ $CONFIG_CUSTOM_FSL == "yes" ]; then
  if [ "${selected_freesurfer_ver}" == "6.0.0" ]; then
    echo "using built in version of FSL."
  else
    echo " "
    echo "You have chosen to use a custom version of FSL."
#  if [ -z "$FSLDIR" ]; then
#   echo "Pulling from your FSL source file in your home directory."
#    if [ ! -f ~/sourcefiles/fsl_source.sh ]; then
#      echo ".......Can not find your FSL source file in your home directory."
#      echo "       Falling back to using Freesurfer built-in version."
#      echo "       Please contact Jason Evans (jason-evans@uiowa.edu)"
#      echo " "
#    else
    source /Shared/pinc/sharedopt/apps/sourcefiles/fsl_source.sh
  fi
#  else
#    :
  fi
#elif [ -z "$FSLDIR" ]; then
#  echo " "
#  echo "FSL is not currently configured.  Freesurfer will use it's built-in version."
#  echo "If you want to customize what version of FSL Freesurfer uses, please edit"
#  echo "this script, log out and back in. Then run this script again."
#  echo " "
#fi

## The actual commands for setting up FreeSurfer ##
FREESURFER_HOME=/Shared/pinc/sharedopt/apps/freesurfer/${kernel}/${hardware}/${selected_freesurfer_ver}
. ${FREESURFER_HOME}/SetUpFreeSurfer.sh

## Just to let the user know that we believe we have everything configured now ##
if [ -z "$MNI_DIR" ]; then
  echo " "
  echo "Something went wrong.  Please contact Jason Evans (jason-evans@uiowa.edu)"
else
  echo " "
  echo "You should now be set up to run FreeSurfer v${selected_freesurfer_ver}"
fi
