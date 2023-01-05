#!/bin/bash

## Basic version check ##
this_ants_source_ver="2018070501"
master_ants_source_ver=$(grep this_ants_source_ver "/Shared/pinc/sharedopt/apps/sourcefiles/ants_source.sh"  | head -n+1 | tail -n-1 | awk -F\" '{print $2}')
echo " "
if [ $master_ants_source_ver -gt $this_ants_source_ver ]; then
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

## What version do we want to use? ##
selected_ants_ver="2.3.1"

## Make sure that ANTs isn't already set.  If it is, tell the user what version ##
## is currently configured.  Otherwise, set up ANTs.                            ##
if [ -z "$ANTSPATH" ]; then
  ANTSPATH=/Shared/pinc/sharedopt/apps/ants/${kernel}/${hardware}/${selected_ants_ver}/bin
  PATH=${PATH}:${ANTSPATH}
  export PATH
  export ANTSPATH
  echo "You should now be set up to use ANTs v${selected_ants_ver}"
else
  current_ants_ver=$(awk -F/ '{ print $9}' <<<"${ANTSPATH}")
  echo "ANTs has already been configured.  The version is v${current_ants_ver}"
fi
