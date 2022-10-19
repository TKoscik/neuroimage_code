#!/bin/bash

## Basic version check ##
this_afni_source_ver="2018071001"
master_afni_source_ver=$(grep this_afni_source_ver "/Shared/pinc/sharedopt/apps/sourcefiles/afni_source.sh"  | head -n+1 | tail -n-1 | awk -F\" '{print $2}')
echo " "
if [ $master_afni_source_ver -gt $this_afni_source_ver ]; then
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

selected_afni_ver="18.2.04"


## Make sure that AFNI isn't already set.  If it is, tell the user what version ##
## is currently configured.  Otherwise, set up AFNI.                            ##
if [ -z "$AFNIDIR" ]; then
  AFNIDIR=/Shared/pinc/sharedopt/apps/afni/${kernel}/${hardware}/${selected_afni_ver}
  DYLD_FALLBACK_LIBRARY_PATH=${AFNIDIR}
  PATH=${PATH}:${AFNIDIR}
  export PATH
  export AFNIDIR
  export DYLD_FALLBACK_LIBRARY_PATH
  echo "You should now be set up to use AFNI v${selected_afni_ver}"
else
  current_afni_ver=$(awk -F/ '{ print $9}' <<<"${AFNIDIR}")
  echo "AFNI has already been configured.  The version is v${current_afni_ver}"
fi
