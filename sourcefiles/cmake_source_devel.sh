#!/bin/bash

####################################
##  This script should not need   ##
##  to be edited. It should be    ##
## completely self-sufficient.    ##
####################################

## Set up some variables for version and location checking ##
this_cmake_source_ver="2021061601"
thisScriptLocation="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
master_fsl_source_ver=$(grep this_cmake_source_ver "/Shared/pinc/sharedopt/apps/sourcefiles/cmake_source.sh"  | head -n+1 | tail -n-1 | awk -F\" '{print $2}')

## Version and script location check ##
if [ "${thisScriptLocation}" != "/Shared/pinc/sharedopt/apps/sourcefiles" ]; then
  echo "WARNING: You are not running this script from the expected location."
  echo "We expected you to run this script from /Shared/pinc/sharedopt/apps/sourcefiles."
  echo "You are running it from ${thisScriptLocation}."
  echo "It is recommended that you run the latest version of this script from the Shared location."
  echo " "
  echo "Will now run a version check on this script.."
  echo " "
  if [ "${this_fsl_source_ver}" != "${master_fsl_source_ver}" ]; then
    echo "This script is a different version from the supported version."
    echo "It is recommended that if you need to run this script from a different location"
    echo "that you update to the latest version by copying the latest supported version"
    echo "from /Shared/pinc/sharedopt/apps/sourcefiles."
    echo " "
    echo " "
  else
    :
  fi
else
  :
fi

## Set some basic Variables ##
kernel="$(uname -s)"
hardware="$(uname -m)"
hostname="$(hostnamectl | awk -F : 'NR==1{ print $2}')"
isPsychiatry="$(hostnamectl | awk -F : 'NR==1{ print $2}' | awk -F . '{ print $2}')"
CMAKEVER="3.13.3"
FORCEOVERRIDE="N"
QUITSCRIPT="0"

###################################
## Function to display help menu ##
###################################
usage () {
  echo "Usage: cmake_source [ -h | --help                     => Displays this message                                            ]
                  [ --cmakever <version.number>       => Sets desired CMake version   (Default version 3.13.3)     ]
                  [ -f | --force                    => forces settings and script will not propmt for changing versions ]";
  QUITSCRIPT="1";
}

####################################################################################
## Function to make sure that we are running on a Psychiatry managed workstation  ##
####################################################################################
not_on_argon () {
  if [ "${isPsychiatry}" == "psychiatry" ]; then
    good_to_go="yes"
  else
    echo "This script is designed to run on UI Psychiatry machines."
    echo "It does not appear that this machine is a Psychiatry managed machine."
    echo "This script will now exit."
    echo " "
    echo "If you are attempting to run this script from Argon, please run"
    echo "module spider cmake to find what verions you can configure there."
    echo " "
    echo "If you believe this message is in error, please contact"
    echo "Jason Evans,  jason-evans@uiowa.edu for assistance."
    return 1
  fi
}

#######################################################
## Function to actually set CMake in the user's path ##
#######################################################
configure_cmake () {
  current_cmake_path="$(command -v cmake)"
  current_cmake_ver="$(cmake --version | awk -F'[ ]'  '{print $3}')"
  if [ "${current_cmake_ver}" == ${CMAKEVER} ]; then
    echo "CMake version ${CMAKEVER} is already configured."
  elif [ -z "${current_cmake_ver}" ]; then
    if [ ${kernel} == "Darwin" ]; then
      CMAKEDIR=/Shared/pinc/sharedopt/apps/cmake/${kernel}/${hardware}/${CMAKEVER}/CMake.app/Contents/bin
    else
      CMAKEDIR=/Shared/pinc/sharedopt/apps/cmake/${kernel}/${hardware}/${CMAKEVER}/bin
    fi
    PATH=${CMAKEDIR}:${PATH}
    export PATH
    echo "You should now be set up to use CMake v${CMAKEVER}"
  else
    if [ "${FORCEOVERRIDE}" == "Y" ]; then
      newPath=$(echo "${PATH}" | sed "s,/Shared/pinc/sharedopt/apps/cmake/$kernel/$hardware/$current_cmake_ver/bin,/Shared/pinc/sharedopt/apps/cmake/$kernel/$hardware/$CMAKEVER/bin,")
      export PATH=$newPath
    fi
  fi
}

PARSED_ARGUMENTS=$(getopt -n cmake_source -o hf --long help,force,cmakever: -- "$@")
VALID_ARGUMENTS=$?
if [ "$VALID_ARGUMENTS" != "0" ]; then
  usage
fi

eval set -- "$PARSED_ARGUMENTS"
while :
do
  case "$1" in
    -h | --help)   usage             ; break   ;;
    --cmakever)      CMAKEVER="$2"   ; shift 2 ;;
    -f | --force) FORCEOVERRIDE="Y"  ; shift   ;;
    --)            shift             ; break   ;;
    *) echo "Unexpected option: $1 - this should not happen."
       usage ;;
  esac
done

if [ "$QUITSCRIPT" == "1" ]; then
  return 1
fi
not_on_argon
configure_cmake

## Just to let the user know that we believe we have everything configured now ##
if [ -z "$FSLWISH" ]; then
  echo " "
  echo "Something went wrong.  Please contact Jason Evans (jason-evans@uiowa.edu)"
elif [ -z "${newPath}" ]; then
  echo " "
  echo " "
fi
