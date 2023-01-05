#!/bin/bash

####################################
##  This script should not need   ##
##  to be edited. It should be    ##
## completely self-sufficient.    ##
####################################

## Set up some variables for version and location checking ##
this_fsl_source_ver="2020062301"
thisScriptLocation="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
master_fsl_source_ver=$(grep this_fsl_source_ver "/Shared/pinc/sharedopt/apps/sourcefiles/fsl_source.sh"  | head -n+1 | tail -n-1 | awk -F\" '{print $2}')

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
FSLVER="6.0.1_multicore"
ANACONDAVER="5.3.0"
FORCEOVERRIDE="N"
QUITSCRIPT="0"

## Function to display help menu ##
usage () {
  echo "Usage: fsl_source [ -h | --help                     => Displays this message                                            ]
                  [ --fslver <version.number>       => Sets desired FSL version   (Default version 6.0.1_multicore)     ]
                  [ --anacondaver <version.number>  => Sets desired Anaconda3 version  (Default version 5.3.0)          ]
                  [ -f | --force                    => forces settings and script will not propmt for changing versions ]";
  QUITSCRIPT="1";
}

configure_anaconda3 () {
  case $FSLVER in
    5.0.2.2|5.0.8|5.0.8_multicore|5.0.9|5.0.9_multicore)
      echo "This version does not require a special version of Python. Moving on." ;;
    *)
      echo "Configuring Python"
      source /Shared/pinc/sharedopt/apps/sourcefiles/anaconda3_source.sh ${ANACONDAVER} ;;
  esac
}

configure_fsl () {
  current_fslwish_path="$(command -v fslwish)"
  current_fsl_ver="$(echo "${current_fslwish_path}" | awk -F/ '{ print $9}')"
  if [ "${current_fsl_ver}" == ${FSLVER} ]; then
    echo "FSL version ${current_fsl_ver} is already configured."
    return
  elif [ -z "${current_fsl_ver}" ]; then
    export FSLDIR="/Shared/pinc/sharedopt/apps/fsl/${kernel}/${hardware}/${FSLVER}"
    . ${FSLDIR}/etc/fslconf/fsl.sh
    export PATH=${PATH}:${FSLDIR}/bin
    echo "FSL version ${FSLVER} is now configured and ready to be used."
  else
    if [ "${FORCEOVERRIDE}" == "Y" ]; then
      newPath=$(echo "${PATH}" | sed "s,/Shared/pinc/sharedopt/apps/fsl/$kernel/$hardware/$current_fsl_ver/bin,/Shared/pinc/sharedopt/apps/fsl/$kernel/$hardware/$FSLVER/bin,")
      export PATH=$newPath
      echo "You have changed your current version of FSL to version ${FSLVER}"
    else
      echo " "
      echo "FSL is already configured to ${current_fsl_ver}."
      echo "Do you want to reconfigure FSL to version ${FSLVER}?"
      select yn in "Yes" "No"; do
        case $yn in
            Yes ) change_fsl_ver="y"; break;;
            No ) change_fsl_ver="n"; break;;
        esac
      done
      if [ ${change_fsl_ver} == "y" ]; then
        newPath=$(echo "${PATH}" | sed "s,/Shared/pinc/sharedopt/apps/fsl/$kernel/$hardware/$current_fsl_ver/bin,/Shared/pinc/sharedopt/apps/fsl/$kernel/$hardware/$FSLVER/bin,")
        export PATH=$newPath
        echo " "
        echo "You have changed your current version of FSL to version ${FSLVER}"
      elif [ ${change_fsl_ver} == "n" ]; then
        echo "Alright, you will continue to use ${current_fsl_ver}"
      fi
    fi
  fi
}


PARSED_ARGUMENTS=$(getopt -n fsl_source -o hf --long help,force,fslver:,anacondaver: -- "$@")
VALID_ARGUMENTS=$?
if [ "$VALID_ARGUMENTS" != "0" ]; then
  usage
fi

eval set -- "$PARSED_ARGUMENTS"
while :
do
  case "$1" in
    -h | --help)   usage             ; break   ;;
    --fslver)      FSLVER="$2"       ; shift 2 ;;
    --anacondaver) ANACONDAVER="$2"  ; shift 2 ;;
    -f | --force) FORCEOVERRIDE="Y"  ; shift   ;;
    --)            shift             ; break   ;;
    *) echo "Unexpected option: $1 - this should not happen."
       usage ;;
  esac
done

if [ "$QUITSCRIPT" == "1" ]; then
  return 1
fi
configure_anaconda3
configure_fsl

## Just to let the user know that we believe we have everything configured now ##
if [ -z "$FSLWISH" ]; then
  echo " "
  echo "Something went wrong.  Please contact Jason Evans (jason-evans@uiowa.edu)"
elif [ -z "${newPath}" ]; then
  echo " "
  echo " "
fi
