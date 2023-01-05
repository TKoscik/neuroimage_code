#!/bin/bash

## Basic version check ##
this_anaconda3_source_ver="2018103101"
master_anaconda3_source_ver=$(grep this_anaconda3_source_ver "/Shared/pinc/sharedopt/apps/sourcefiles/anaconda3_source.sh"  | head -n+1 | tail -n-1 | awk -F\" '{print $2}')
echo " "
if [ $master_anaconda3_source_ver -gt $this_anaconda3_source_ver ]; then
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
selected_ver="$1"

## What version of Anaconda3 do we want to run? ##
base_selected_ver="5.3.0"
## Was there input to set the version from outside this script ##
if [ -z "$selected_ver" ]; then
  selected_ver="$base_selected_ver"
fi

## Checking to see if Anaconda is already configured ##
current_anaconda_path="$(which python)"
current_anaconda_major="$(echo "${current_anaconda_path}"| awk -F/ '{ print $6}' | sed 's/anaconda//')"
if [ "${current_anaconda_major}" == "3" ]; then
  current_anaconda3_ver="$(echo "${current_anaconda_path}" | awk -F/ '{ print $9}')"
  if [ "${current_anaconda3_ver}" == ${selected_ver} ]; then
    echo "Anaconda 3 version ${current_anaconda3_ver} is already configured."
    return
  fi
else
  current_anaconda3_ver=""
fi

## The actual commands ##
  ## Configure Anaconda3 ##
if [ -z "${current_anaconda3_ver}" ]; then
  export PATH="/Shared/pinc/sharedopt/apps/anaconda3/$kernel/$hardware/$selected_ver/bin:$PATH"
  newAnacondaPath="$(which python)"
  newAnaconda3Ver="$(echo "${newAnacondaPath}" | awk -F/ '{ print $9}')"
  if [ "${newAnaconda3Ver}" == ${selected_ver} ]; then
    echo "Anaconda 3 version ${newAnaconda3Ver} is now configured for use."
  else
    echo "Something went wrong.  Please contact Jason Evans (jason-evans@uiowa.edu)"
  fi
else
  echo " "
  echo "Anaconda 3 is already configured to ${current_anaconda3_ver}."
  echo "Do you want to reconfigure Anaconda 3 to version ${selected_ver}?"
  select yn in "Yes" "No"; do
    case $yn in
        Yes ) change_anaconda_ver="y"; break;;
        No ) change_anaconda_ver="n"; break;;
    esac
  done
  if [ ${change_anaconda_ver} == "y" ]; then
    newPath=$(echo "${PATH}" | sed "s,/Shared/pinc/sharedopt/apps/anaconda3/$kernel/$hardware/\([0-9\.]*\)/bin,/Shared/pinc/sharedopt/apps/anaconda3/$kernel/$hardware/$selected_ver/bin,")
    export PATH=$newPath
    echo " "
    echo "You have changed your current version of Anaconda 3 to version ${selected_ver}"
  elif [ ${change_anaconda_ver} == "n" ]; then
    echo "Alright, you will continue to use ${current_anaconda3_ver}"
  fi
fi
