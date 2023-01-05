#!/bin/bash

## Basic version check ##
this_simnibs_source_ver="2019101001"
master_simnibs_source_ver=$(grep this_simnibs_source_ver "/Shared/pinc/sharedopt/apps/sourcefiles/simnibs_source.sh"  | head -n+1 | tail -n-1 |
 awk -F\" '{print $2}')
echo " "
if [ $master_simnibs_source_ver -gt $this_simnibs_source_ver ]; then
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
selected_simnibs_ver="$1"
anaconda3_ver="2019.07"
fsl_ver="5.0.9_multicore"
freesurfer_ver="6.0.0"
###  What version of SimNIBS we want to run ###
base_simnibs_selected_ver="3.0.8"

############################################################
### You should not need to edit anything below this line ###
############################################################


## Was there input to set the version from outside this script ##
if [ -z "$selected_simnibs_ver" ]; then
  selected_simnibs_ver="$base_simnibs_selected_ver"
fi

if [ $selected_simnibs_ver == "2.0.1h" ]; then
  ## We need to set up FSL so that parts of SimNIBS runs correctly. ##
  ## NOTE:  SimNIBS requires FSl verison 5.0.5 or higher ##
  echo " "
  echo "SimNIBS requires FSL to function properly.  Checking for FSL installation..."
  if [ -z "$FSLWISH" ]; then
    echo " "
    echo "No version of FSL found. Attempting to pull from source file in user's"
    echo "home directoy....."
    if [ ! -f ~/sourcefiles/fsl_source.sh ]; then
      echo ".......Can not find your FSL source file in your home directory."
      echo "attempting to fall back to using Freesurfer built-in version."
      echo " "
    else
      source ~/sourcefiles/fsl_source.sh 5.0.9_multicore
    fi
  else
    echo "FOUND"
  fi

  ## We also need to set up FreeSurfer so that parts of SimNIBS runs correctly. ##
  ## NOTE:  SimNIBS requires FreeSurfer verison 5.3.0 or higher ##
  echo " "
  echo "SimNIBS requires FreeSurfer to function properly.  Checking for Freesurfer installation..."
  if [ -z "$MNI_DIR" ]; then
    echo " "
    echo "No version of FreeSurfer found. Attempting to pull from source file in user's"
    echo "home directory....."
    if [ ! -f ~/sourcefiles/freesurfer_source.sh ]; then
      echo ".......Can not find your FreeSurfer source file in your home directory."
      if [ -z "$FSLWISH" ]; then
        echo "Can not find FSL or FreeSurfer installation or source files."
        echo "Will attempt to configure SimNIBS without them, but the application"
        echo "will probably not work correctly."
        echo " "
      else
        echo "Can not find FreeSurfer installation or source files."
        echo "Will attempt to configure SimNIBS without it, but the application"
        echo "will probably not work correctly."
        echo " "
      fi
    else
      source ~/sourcefiles/freesurfer_source.sh 6.0.0
    fi
  else
    echo "FOUND"
  fi

  ## The actual commands for SimNIBS##
  export SIMNIBSDIR="/Shared/pinc/sharedopt/apps/SimNIBS/$kernel/$hardware/$selected_simnibs_ver"
  source $SIMNIBSDIR/simnibs_conf.sh
  echo " "
  echo "You should now be set up to run SimNIBS v${selected_simnibs_ver}"
else
  ## We need Anaconda 3 to make newer versions of SimNIBS work. Sourcing Anaconda 3 files ##
  source /Shared/pinc/sharedopt/apps/sourcefiles/anaconda3_source.sh ${anaconda3_ver}

  ## We need to make sure that the user has run SimNIBS before ##
  if [ ! -d ${HOME}/SimNIBS ]; then
    echo " "
    echo "This is going to take a minute, it appears that you need some files copied to your home folder."
    mkdir -p ${HOME}/SimNIBS
    postinstall_simnibs --setup-links --no-add-to-path --no-copy-gmsh-options --no-associate-files --no-extra-coils --silent -d $HOME/SimNIBS
    rsync -a /Shared/pinc/sharedopt/apps/sourcefiles/support_files/SimNIBS/matlab ~/SimNIBS/
  else
    :
  fi
  echo " "
  echo "SimNIBS ${selected_simnibs_ver} is now configured and ready to use."
  echo "To use the software you can type simnibs_gui at a command prompt."
fi
