#!/bin/bash

## Basic version check ##
this_cmake_source_ver="2018102901"
master_cmake_source_ver=$(grep this_cmake_source_ver "/Shared/pinc/sharedopt/apps/sourcefiles/cmake_source.sh"  | head -n+1 | tail -n-1 | awk -F\" '{print $2}')
echo " "
if [ $master_cmake_source_ver -gt $this_cmake_source_ver ]; then
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
current_cmake_path="$(command -v cmake)"
selected_cmake_ver=$1

##########################################
## Set the variables for this software  ##
## These are the variables you can edit ##
##########################################
base_cmake_ver="3.11.4"

##########################################
## From here on you shouldn't need to   ##
## edit anything in this script         ##
##########################################

## Was there input to set the version from outside this script ##
if [ -z "$selected_cmake_ver" ]; then
  selected_cmake_ver="$base_cmake_ver"
fi

## Set up where cmake is located ##
if [ ${kernel} == "Darwin" ]; then
  selected_cmake_path="/Shared/pinc/sharedopt/apps/cmake/${kernel}/${hardware}/${selected_cmake_ver}/CMake.app/Contents/bin/cmake"
else
  selected_cmake_path="/Shared/pinc/sharedopt/apps/cmake/${kernel}/${hardware}/${selected_cmake_ver}/bin/cmake"
fi

## Make sure that this version of CMAKE isn't already set.  If it is, tell the user what version ##
## is currently configured.  Otherwise, set up CMAKE.                            ##
if [ ${current_cmake_path} != ${selected_cmake_path} ]; then
  current_cmake_ver="$(cmake --version | sed 's,cmake version ,,' | sed '1!d')"
  current_cmake_is_older="$(versioncmp.sh ${current_cmake_ver} ${selected_cmake_ver})"
  if [ ${current_cmake_is_older} == ${selected_cmake_ver} ]; then
    if [ ${kernel} == "Darwin" ]; then
      CMAKEDIR=/Shared/pinc/sharedopt/apps/cmake/${kernel}/${hardware}/${selected_cmake_ver}/CMake.app/Contents/bin
    else
      CMAKEDIR=/Shared/pinc/sharedopt/apps/cmake/${kernel}/${hardware}/${selected_cmake_ver}/bin
    fi
    PATH=${CMAKEDIR}:${PATH}
    export PATH
    echo "You should now be set up to use CMAKE v${selected_cmake_ver}"
  else
    echo "The current configured version of cmake (v${current_cmake_ver}) is newer than the selected version."
    echo "Would you like to try to continue with the newer version or downgrade to the older? (v${selected_cmake_ver})"
    select conDown in "Continue" "Downgrade"; do
      case $conDown in
        Continue ) changeCmakeVer="continue"; break ;;
        Downgrade ) changeCmakeVer="downgrade"; break;;
      esac
    done
    if [ ${changeCmakeVer} == "downgrade" ]; then
      newPath=$(echo "${PATH}" | sed "s,/Shared/pinc/sharedopt/apps/cmake/$kernel/$hardware/\([0-9\.]*\)/bin,/Shared/pinc/sharedopt/apps/cmake/$kernel/$hardware/$selected_cmake_ver/bin,")
      PATH=${newPath}
      export PATH
      echo "You should now be set up to use CMAKE v${selected_cmake_ver}"
    elif [ ${changeCmakeVer} == "continue" ]; then
      echo "OK.  We will use CMake version ${current_cmake_ver}."
    else
      echo "Did not understand your input.  Please ONLY type continue or downgrade and press enter."
      echo "Quitting.  Please run this script again."
    fi
  fi
else
  current_cmake_ver=$(awk -F/ '{ print $9}' <<<"${CMAKEDIR}")
  echo "CMAKE has already been configured to the selected version v${current_cmake_ver}"
fi





hostnamectl | awk -F : 'NR==1{ print $2}' | awk -F . '{ print $2}'
