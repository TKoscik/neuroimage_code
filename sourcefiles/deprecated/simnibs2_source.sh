#!/bin/bash

####################################
##  This script should not need   ##
##  to be edited. It should be    ##
## completely self-sufficient.    ##
####################################

## Set up some variables for version and location checking ##
this_simnibs_source_ver="2021021601"
thisScriptLocation="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
master_simnibs_source_ver=$(grep this_simnibs_source_ver "/Shared/pinc/sharedopt/apps/sourcefiles/simnibs2_source.sh"  | head -n+1 | tail -n-1 | awk -F\" '{print $2}')

## Version and script location check ##
if [ "${thisScriptLocation}" != "/Shared/pinc/sharedopt/apps/sourcefiles" ]; then
  echo "WARNING: You are not running this script from the expect location."
  echo "We expected you to run this script from /Shared/pinc/sharedopt/apps/sourcefiles."
  echo "You are running it from ${thisScriptLocation}."
  echo "It is recommended that you run the latest version of this script from the Shared location."
  echo " "
  echo "Will now run a version check on this script.."
  echo " "
  if [ "${this_simnibs_source_ver}" != "${master_simnibs_source_ver}" ]; then
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
SIMNIBSVER="3.2.2"
FSLVER="6.0.1_multicore"
FREESURFERVER="6.0.0"
ANACONDAVER="2020.11"
MATLABVER="R2020a"
FORCEOVERRIDE="N"
QUITSCRIPT="0"

## Function to display help menu ##
usage () {
  echo "Usage: simnibs_source                                                                                                       
                       -h | --help                      => Displays this message                                            
                       -f | --force                     => forces settings and script will not propmt for changing versions 
                       --simnibsver <version.number>    => Sets desired SimNIBS version   (Default is 3.2.2)                
                                                           NOTE: If you select a previous version of SimNIBS the default    
                                                                 FSL and Anaconda versions may change automatically because 
                                                                 of version dependancies of SimNIBS.                        
                       --fslver <version.number>        => Sets desired FSL version   (Default version 6.0.1_multicore)     
                       --freesurferver <version.number> => Sets desired FreeSurfer version (Default version 6.0.0)          
                       --matlabver <version.number>     => Sets desired Matlab version (Default R2020a)
                       --anacondaver <version.number>   => Sets desired Anaconda3 version  (Default version 2020.11)        
                                                                                                                            
                   *** NOTES:  Please be aware this script changes system settings for Python, FSL, & FreeSurfer to make    
                               your environment fully compatible with SimNIBS.  This may adversly effect some other programs
                               that you are running or may want to run in this terminal session.                            
                               If you need these settings to go back to your default, please just open a new session.       ";
  QUITSCRIPT="1";
}

preconfig_filechecks () {
  anaconda="/Shared/pinc/sharedopt/apps/sourcefiles/anaconda3_source.sh"
  fsl="/Shared/pinc/sharedopt/apps/sourcefiles/fsl_source.sh"
  matlab="/Shared/pinc/sharedopt/apps/sourcefiles/matlab_source.sh"
  freesurfer="/Shared/pinc/sharedopt/apps/sourcefiles/freesurfer_source.sh"
  if [ -f "${anaconda}" ]; then
    if [ -f "${fsl}" ]; then
      if [ -f "${matlab}" ]; then
        if [ -f "${fresurfer}" ]; then
          :
        else
          echo "The freesurfer_source script is inaccessible or missing.  please resolve this before we can continue."
          QUITSCRIPT="1";
        fi
      else
        echo "The matlab_source script is inaccessible or missing.  please resolve this before we can continue."
        QUITSCRIPT="1";
      fi
    else
      echo "The fsl_source script is inaccessible or missing.  please resolve this before we can continue."
      QUITSCRIPT="1";
    fi
  else
    echo "The anaconda3_source script is inaccessible or missing.  please resolve this before we can continue."
    QUITSCRIPT="1";
  fi
}

configure_anaconda3 () {
  case $SIMNIBSVER in
    2.0.1h|3.0.0)
      echo "This version requires Anaconda3 verison 2019.07"
      echo "Verifying no override was set..."
      if [ "${ANACONDAVER}" != "2019.07" ]; then
        ## This if statement is just a catch to show users that we are not using the expected version of Anaconda. ##
        echo "override set, configuring with non-standard version of Anaconda3"
        source /Shared/pinc/sharedopt/apps/sourcefiles/anaconda3_source.sh ${ANACONDAVER}
      else
        source /Shared/pinc/sharedopt/apps/sourcefiles/anaconda3_source.sh ${ANACONDAVER}
      fi ;;
    *)
      source /Shared/pinc/sharedopt/apps/sourcefiles/anaconda3_source.sh ${ANACONDAVER} ;;
  esac
}

configure_fsl () {
  case $FSLVER in
    5.0.2.2|5.0.8|5.0.8_multicore|5.0.9|5.0.9_multicore|6.0.0|6.0.0_multicore|6.0.1|6.0.3|6.0.4)
      if [ "${SIMNIBSVER}" == "2.0.1h" ]; then
        if [ "${FSLVER}" != "5.0.9_multicore" ]; then
          ## This if statement is just a catch to show users that we are not using the expected version of FSL for this version of SimNIBS. ##
          echo "This version of FSL is not the default version for this version of SimNIBS."
          source /Shared/pinc/sharedopt/apps/sourcefiles/fsl_source.sh --force --fslver ${FSLVER} --anacondaver ${ANACONDAVER}
        else
          source /Shared/pinc/sharedopt/apps/sourcefiles/fsl_source.sh --force --fslver ${FSLVER} --anacondaver ${ANACONDAVER}
        fi
      else
        echo "This version of FSL is not the default version for this version of SimNIBS."
        source /Shared/pinc/sharedopt/apps/sourcefiles/fsl_source.sh --force --fslver ${FSLVER} --anacondaver ${ANACONDAVER}
      fi ;;
    *)
      source /Shared/pinc/sharedopt/apps/sourcefiles/fsl_source.sh --force --fslver ${FSLVER} --anacondaver ${ANACONDAVER}
  esac
}

configure_freesurfer () {
  case $FREESURFERVER in
    4.5.0|5.0.0|5.3.0|7.1.0|7.1.1)
      if [ "${FREESURFERVER}" == "4.5.0" ]; then
        echo " "
        echo "ATTENTION!!!"
        echo "Some functions of SimNIBS will not work with this version of Freesurfer."
        source /Shared/pinc/sharedopt/apps/sourcefiles/freesurfer_source.sh ${FREESURFERVER}
      elif [ "${FREESURFERVER}" == "5.0.0" ]; then
        echo " "
        echo "ATTENTION!!!"
        echo "Some functions of SimNIBS will not work with this version of Freesurfer."
        source /Shared/pinc/sharedopt/apps/sourcefiles/freesurfer_source.sh ${FREESURFERVER} 
      else
        echo "This is not the expected version of FreeSurfer but it should work."
        source /Shared/pinc/sharedopt/apps/sourcefiles/freesurfer_source.sh ${FREESURFERVER}
      fi ;;
    *)
      if [ "${FREESURFERVER}" == "6.0.0" ]; then
        source /Shared/pinc/sharedopt/apps/sourcefiles/freesurfer_source.sh ${FREESURFERVER}
      else
        echo "This version of of FreeSurfer is not supported by the department of Psychiatry"
        echo "or doesn't exist on the system."
        echo "SimNIBS may still function without support for FreeSurfer but may be limited."
        echo "Please contact Jason Evans (jason-evans@uiowa.edu) if you are having troubles."
      fi
  esac
}

configure_matlab () {
  case $MATLABVER in
    R2015b|R2016a|R2017a|R2019a|R2020a)
      if [ "${MATLABVER}" == "R2020a" ]; then
        source /Shared/pinc/sharedopt/apps/sourcefiles/matlab_source.sh --matlabver ${MATLABVER}
      else
        echo "The version you chose is not the latest supported version of Matlab. Trying to use."
        source /Shared/pinc/sharedopt/apps/sourcefiles/matlab_source.sh --matlabver ${MATLABVER}
      fi ;;
  *)
    echo "This version of of Matlab is not supported by SimNIBS or doesn't exist on the system."
    echo "Please contact Jason Evans (jason-evans@uiowa.edu) if you are having troubles."
  esac
}

#configure_simnibs () {
#
#}

postconfig_versionchecks () {
  ## Verifying Which version of Python we are running. ##
  CURRENT_PYTHON_PATH="$(which python)"
  CURRENT_ANACODA_MAJOR="$(echo "${CURRENT_PYTHON_PATH}"| awk -F/ '{ print $6}' | sed 's/anaconda//')"
  if [ "${CURRENT_ANACODA_MAJOR}" == "3" ]; then
    CURRENT_ANACODA3_VER="$(echo "${CURRENT_PYTHON_PATH}" | awk -F/ '{ print $9}')"
    if [ "${CURRENT_ANACODA3_VER}" == ${ANACONDAVER} ]; then
      PYTHON_CORRECTLY_SET="YES"
    else
      PYTHON_CORRECTLY_SET="NO"
    fi
  elif [ "${CURRENT_ANACODA_MAJOR}" == "2" ]; then
    PYTHON_CORRECTLY_SET="NO-2"
  else
    PYTHON_CORRECTLY_SET="NO-NO_ANACONDA"
  fi
  if [ "${PYTHON_CORRECTLY_SET}" == "NO-2" ]; then
    echo "For some reason Anaconda was not configured properly."
    echo "Please contact Jason Evans (jason-evans@uiowa.edu) for support."
  elif [ "${PYTHON_CORRECTLY_SET}" == "NO" ]; then
    echo "Anaconda was configured correctly but with the wrong version."
    echo "SimNIBS should still work. But may have issues."
    echo "Please contact Jason Evans (jason-evans@uiowa.edu) for support."
  elif [ "${PYTHON_CORRECTLY_SET}" == "NO-NO_ANACONDA" ]; then
    echo "Anaconda was not configured at all.  Something seriously went wrong."
    echo "Please contact Jason Evans (jason-evans@uiowa.edu) for support."
  elif [ "${PYTHON_CORRECTLY_SET}" == "YES" ]; then
    :
  else
    echo "This error should NEVER be seen. Something is seriously wrong with"
    echo "this machine.  Please contact Jason Evans (jason-evans@uiowa.edu)"
    echo "immediately.  It is probably not wise to use this machine currently."
  fi
  
  ## Verifying which version of FSL we are running. ##
  CURRENT_FSLWISH_PATH="$(command -v fslwish)"
  CURRENT_FSL_VER="$(echo "${CURRENT_FSLWISH_PATH}" | awk -F/ '{ print $9}')"
  if [ "${CURRENT_FSL_VER}" == ${FSLVER} ]; then
    FSL_CORRECTLY_SET="YES"
  else
    FSL_CORRECTLY_SET="NO"
  fi

  ## Verifying which version of FreeSurfer we are running. ##
  CURRENT_FREESURFER_VER="$(echo "${FREESURFER_HOME}" | awk -F/ '{ print $9}')"
  if [ "${CURRENT_FREESURFER_VER}" == ${FREESURFERVER} ]; then
    FREESURFER_CORRECTLY_SET="YES"
  else
    FREESURFER_CORRECTLY_SET="NO"
  fi

  ## Verify which version of Matlab we are running. ##
  IS_MATLAB_ALIAS="$(which matlab | awk 'NR <=1 { print $1}')"
  CURRENT_MATLAB_VER="$(which matlab | awk -F/ 'NR >= 2 { print $9}')"
  if [ "${IS_MATLAB_ALIAS}" == "alias" ]; then
    echo "Matlab is currently set up in your bashrc file as an alias."
    echo "This script can not modify your bashrc."
    echo "However, SimNIBS should be able to use the alias, but if you have problems"
    echo "please remove the alias from your bashrc file, log out and back in"
    echo "then run this script again to configure Matlab the way this script"
    echo "expects.  If you have questions please contact Jason Evans"
    echo "(jason-evans@uiowa.edu) for assistance."
    MATLAB_CORRECTLY_SET="YES-ALIAS"
  elif [ "${CURRENT_MATLAB_VER}" == ${MATLABVER} ]; then
    MATLAB_CORRECTLY_SET="YES"
  else
    MATLAB_CORRECTLY_SET="NO"
  fi


  ## Spit out something to the user to verify what has happened or been configured. ##
  if [ "${PYTHON_CORRECTLY_SET}" == "YES" ]; then
    if [ "${SIMNIBS_CORRECTLY_SET}" == "YES" ]; then
      if [ "${FSL_CORRECTLY_SET}" == "YES" ]; then
        if [ "${FREESURFER_CORRECTLY_SET}" == "YES" ]; then
          echo "Every has been configured and you are ready to use SimNIBS."
          echo "To Start the program type: simnibs_gui and press enter."
        else
          echo "FreeSurfer was not configured correctly.  SimNIBS may"
          echo "still operate.  However it may have some limited functions."
        fi
      else
        echo "FSL was not configured correctly.  SimNIBS may"
        echo "still operate.  However it may have some limited functions."
      fi
    else
      echo "SimNIBS did not appear to load correctly.  Please contact"
      echo "Jason Evans (jason-evans@uiowa.edu) for assistance."
    fi
  else
    return 1
  fi
}

PARSED_ARGUMENTS=$(getopt -n simnimbs2_source -o hf --long help,force,fslver:,simnibsver:,matlabver:,freesurferver:,anacondaver: -- "$@")
VALID_ARGUMENTS=$?
if [ "$VALID_ARGUMENTS" != "0" ]; then
  usage
fi

eval set -- "$PARSED_ARGUMENTS"
while :
do
  case "$1" in
    -h | --help)   usage                ; break   ;;
    --fslver)      FSLVER="$2"          ; shift 2 ;;
    --freesurferver) FREESURFERVER="$2" ; shift 2 ;;
    --anacondaver) ANACONDAVER="$2"     ; shift 2 ;;
    --simibsver)   SIMNIBSVER="$2"      ; shift 2 ;;
    --matlabver)  MATLABVER="$2"        ; shift 2 ;;
    -f | --force) FORCEOVERRIDE="Y"     ; shift   ;;
    --)            shift                ; break   ;;
    *) echo "Unexpected option: $1 - this should not happen."
       usage ;;
  esac
done

if [ "$QUITSCRIPT" == "1" ]; then
  return 1
fi
preconfig_filechecks
if [ "$QUITSCRIPT" == "1" ]; then
  return 1
fi
configure_anaconda3
configure_fsl
configure_freesurfer
configure_matlab
#configure_simnibs
postconfig_versionchecks
