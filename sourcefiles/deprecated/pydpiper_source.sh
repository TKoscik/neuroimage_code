#!/bin/bash

## Basic version check ##
this_pydpiper_source_ver="2019011502"
master_pydpiper_source_ver=$(grep this_pydpiper_source_ver "/Shared/pinc/sharedopt/apps/sourcefiles/pydpiper_source.sh"  | head -n+1 | tail -n-1 | awk -F\" '{print $2}')
echo " "
if [ $master_pydpiper_source_ver -gt $this_pydpiper_source_ver ]; then
  echo "There is a newer version of this source file in /Shared/pinc/sharedopt/apps/sourcefiles/"
  echo "You might want to consider updating to it."
  echo "If you have questions, feel free to contact Jason Evans (jason-evans@uiowa.edu)"
  echo " "
else
 :
fi

## Set some base system variables ##
kernel="$(uname -s)"
hardware="$(uname -m)"

##########################################
## Set the variables for this software  ##
## These are the variables you can edit ##
##########################################
pydpiper_expected_ver="2.0.13"
pydpiper_anaconda3_ver="5.3.0"
pydpiper_mincToolbox_ver="1.9.17"
pydpiper_mincStuffs_ver="0.1.23"
pydpiper_minc2Simple_ver="2.1"

##########################################
## From here on you shouldn't need to   ##
## edit anything in this script         ##
##########################################

## We need to check for dependancy applications and see if they are installed/configured##
## MINC Toolbox ##
current_pydpiper_mincToolbox_path="$(command -v ABC_MINC)"
if [ -z "${current_pydpiper_mincToolbox_path}" ]; then
  mincToolbox_already_cofigured="no"
else
  is_minc_in_opt="$(echo "${current_pydpiper_mincToolbox_path}" | awk -F/ '{ print $2}')"
  if [ "${is_minc_in_opt}" == "opt" ]; then
    current_pydpiper_mincToolbox_ver="$(echo "${current_pydpiper_mincToolbox_path}" | awk -F/ '{ print $4}')"
  else
    current_pydpiper_mincToolbox_ver="$(echo "${current_pydpiper_mincToolbox_path}" | awk -F/ '{ print $9}')"
  fi
fi

## MINC Stuffs ##
current_pydpiper_mincStuffs_path="$(command -v minc_displacement)"
current_pydpiper_mincStuffs_ver="$(echo "${current_pydpiper_mincStuffs_path}" | awk -F/ '{ print $9}')"

## minc2-simple ##
current_pydpiper_minc2Simple_path="$(command -v xfmavg_scipy.py)"
current_pydpiper_minc2Simple_ver="$(echo "${current_pydpiper_minc2Simple_path}" | awk -F/ '{ print $9}')"

## Note to user about pydpiper##
echo " "
echo "Pydpiper is a group of python scripts that rely on several other packages."
echo "In this source file you can configure the versions of these other packages."
echo "The currennt version of pydpiper that has been installed is version 2.0.13"
echo "***If you need a different version of pydpiper, please contact Jason Evans (jason-evans@uiowa.edu)"
echo " "

## The actual commands ##
  ## Configure Anaconda3 ##
  echo "Configuring Python"
  if [ -f "${HOME}/sourcefiles/anaconda3_source.sh" ]; then
    echo "using user's source file" 
    source ~/sourcefiles/anaconda3_source.sh ${pydpiper_anaconda3_ver}
  else
    echo "using system source file"
    source /Shared/pinc/sharedopt/apps/sourcefiles/anaconda3_source.sh ${pydpiper_anaconda3_ver}
  fi

  ## Configure MINC Toolbox ##
  if [ -z ${current_pydpiper_mincToolbox_ver} ]; then
    echo " "
    echo "Configuring MINC Toolbox"
    if [ -d /opt/minc ]; then
      local_mincToolbox_latest_ver="$(ls -1 /opt/minc | tail -1)"
    fi
    if [ -z "$local_mincToolbox_latest_ver" ]; then
      source /Shared/pinc/sharedopt/apps/minc/${kernel}/${hardware}/${pydpiper_mincToolbox_ver}/minc-toolkit-config.sh
      echo "MINC Toolbox, version ${pydpiper_mincStuffs_ver} is now configured."
    else
      source /opt/minc/${local_mincToolbox_latest_ver}/minc-toolkit-config.sh
      echo "MINC Toolbox, version ${local_mincToolbox_latest_ver} is now configured."
    fi
  elif [ "${current_pydpiper_mincToolbox_ver}" != "${pydpiper_mincToolbox_ver}" ]; then
    echo " "
    echo "MINC Toolbox is already configured to ${current_pydpiper_mincToolbox_ver}."
    echo "We'll try to use that version. Moving on to the next step."
  elif [ "${current_pydpiper_mincToolbox_ver}" ==  ${pydpiper_mincToolbox_ver} ]; then
    echo "MINC Toolbox is already configured to version ${current_pydpiper_mincToolbox_ver}. Continuing..."
  else
    echo "Something went wrong during the configuration of MINC Toolbox.  Please contact Jason Evans (jason-evans@uiowa.edu)"
  fi

  ## Configure MINC Stuffs ##
  if [ -z ${current_pydpiper_mincStuffs_ver} ]; then
    echo " "
    echo "Configuring MINC Stuffs"
    export MINC_STUFFS="/Shared/pinc/sharedopt/apps/minc-stuffs/${kernel}/${hardware}/${pydpiper_mincStuffs_ver}"
    export PATH="${PATH}:${MINC_STUFFS}/bin"
    export LD_LIBRARY_PATH="${MINC_STUFFS}/lib:${LD_LIBRARY_PATH}"
    echo "MINC Stuffs, version ${pydpiper_mincStuffs_ver} is now configured."
  elif [ "${current_pydpiper_mincStuffs_ver}" != "${pydpiper_mincStuffs_ver}" ]; then
    echo " "
    echo "MINC Stuffs is already configured to ${current_pydpiper_mincStuffs_ver}."
    echo "We'll try to use that version. Moving on to the next step."
  elif [ "${current_pydpiper_mincStuffs_ver}" ==  ${pydpiper_mincStuffs_ver} ]; then
    echo " "
    echo "MINC Stuffs is already configured to version ${current_pydpiper_mincStuffs_ver}. Continuing..."
  else
    echo "Something went wrong during the configuration of MINC Stuffs.  Please contact Jason Evans (jason-evans@uiowa.edu)"
  fi

  ## Configure minc2-simple ##
  if [ -z ${current_pydpiper_minc2Simple_ver} ]; then
    echo " "
    echo "Configuring minc2-Simple"
    export MINC2_SIMPLE="/Shared/pinc/sharedopt/apps/minc2-simple/${kernel}/${hardware}/${pydpiper_minc2Simple_ver}"
    export PATH="${PATH}:${MINC2_SIMPLE}/scripts-3.7"
    export LD_LIBRARY_PATH="${MINC2_SIMPLE}/lib:${LD_LIBRARY_PATH}"
    echo "minc2-Simple, version ${pydpiper_minc2Simple_ver} is now configured."
  elif [ "${current_pydpiper_minc2Simple_ver}" != "${pydpiper_minc2Simple_ver}" ]; then
    echo " "
    echo "minc2-Simple is already configured to ${current_pydpiper_minc2Simple_ver}."
    echo "We'll try to use that version. Moving on to the next step."
  elif [ "${current_pydpiper_minc2Simple_ver}" ==  ${pydpiper_minc2Simple_ver} ]; then
    echo " "
    echo "minc2-Simple is already configured to version ${current_pydpiper_minc2Simple_ver}. Continuing..."
  else
    echo "Something went wrong during the configuration of minc2-Simple.  Please contact Jason Evans (jason-evans@uiowa.edu)"
  fi

  ## Verifying that Pydpiper is now ready ##
  pydpiper_ver="$(conda list | grep pydpiper | awk '{ print $2}')"
  if [ -z ${pydpiper_ver} ]; then
    echo " "
    echo "There doesn't appear to be a version of PydPiper installed."
    echo "Please contact Jason Evans (jason-evans@uiowa.edu) for assistance."
  elif [ "${pydpiper_expected_ver}" != "${pydpiper_ver}" ]; then
    echo " "
    echo "PydPiper is not configured to the expected version."
    echo "The expected version is ${pydpiper_expected_ver}."
    echo "The version that is currently configured is ${pydpiper_ver}."
    echo "If you believe this is an issue, please contact Jason Evans. (jason-evans@uiowa.edu)"
  else
    echo " "
    echo "You should now be ready to use Pydpiper version ${pydpiper_expected_ver}."
  fi
