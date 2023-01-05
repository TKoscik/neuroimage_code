#!/bin/bash

## Basic version check ##
this_julia_source_ver="2018102901"
master_julia_source_ver=$(grep this_julia_source_ver "/Shared/pinc/sharedopt/apps/sourcefiles/julia_source.sh"  | head -n+1 | tail -n-1 | awk -F\" '{print $2}')
echo " "
if [ $master_julia_source_ver -gt $this_julia_source_ver ]; then
  echo "There is a newer version of this source file in /Shared/pinc/sharedopt/apps/sourcefiles/"
  echo "You might want to consider updating to it."
  echo "If you have questions, feel free to contact Jason Evans (jason-evans@uiowa.edu)"
  echo " "
else
 :
fi

## Set some basic variables ##
kernel="$(uname -s)"
hardware="$(uname -m)"
current_julia_path="$(command -v julia)"
current_cmake_path="$(which ccmake)"

##########################################
## Set the variables for this software  ##
## These are the variables you can edit ##
##########################################
selected_julia_ver="1.0.1"
julia_cmake_ver="3.11.4"

##########################################
## From here on you shouldn't need to   ##
## edit anything in this script         ##
##########################################

## We need to configure some dependancy variables first ##
  ## Setting up CMake.  This should be version 3.11.1 or greater ##
current_cmake_ver=$(echo "${current_cmake_path}" | awk -F/ '{ print $9}')
if [ "${current_cmake_ver}" == "${julia_cmake_ver}" ]; then
  echo "CMake is already configured for v${julia_cmake_ver}"
  echo "Moving on..."
elif [ ! -f "~/sourcefiles/cmake_source.sh" ]; then
  echo "Configuring CMake"
  echo "using user's source file"
  source ~/sourcefiles/cmake_source.sh ${julia_cmake_ver}
else
  echo "Configuring CMake"
  echo "using system source file"
  source /Shared/pinc/sharedopt/apps/sourcefiles/cmake_source.sh ${julia_cmake_ver}
fi

## Now we can configure Julia ##
selected_julia_path=/Shared/pinc/sharedopt/apps/julia/${kernel}/${hardware}/${selected_julia_ver}/bin
current_julia_ver=$(echo "${current_julia_path}" | awk -F/ '{ print $9}')
current_julia_is_older="$(versioncmp.sh ${current_julia_ver} ${selected_julia_ver})"
if [ "${current_julia_path}" == ${selected_julia_path} ]; then
  echo "Julia is already configured with version ${selected_julia_ver}"
elif [ ${current_julia_is_older} == ${selected_julia_ver} ]; then
  PATH=${selected_julia_path}:${PATH}
  export PATH
  echo "Julia has now been configured with version ${selected_julia_ver}."
else
  echo "Julia is already configured with a newer version."
  echo "Do you want to reconfigure to use version ${selected_julia_ver}?"
  select yn in "Yes" "No"; do
    case $yn in
        Yes ) change_julia_ver="y"; break;;
        No ) change_julia_ver="n"; break;;
    esac
  done
  if [ ${change_julia_ver} == "y" ]; then
    echo "Ok.  Changing to use Julia version ${selected_julia_ver}."
    newJuliaPath=$(echo "${PATH}" | sed "s,/Shared/pinc/sharedopt/apps/julia/$kernel/$hardware/\([0-9\.]*\)/bin,/Shared/pinc/sharedopt/apps/julia/$kernel/$hardware/$selected_ver/bin,")
    export PATH=$newJuliaPath
    echo " "
    echo "You have changed your current version of Julia to version ${selected_julia_ver}"
  elif [ ${change_julia_ver} == "n" ]; then
    echo "Alright, you will continue to use version ${current_julia_ver}"
  fi
fi
