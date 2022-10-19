#!/bin/bash

## Basic version check ##
this_gdcm_source_ver="2018043001"
master_gdcm_source_ver=$(grep this_gdcm_source_ver "/Shared/pinc/sharedopt/apps/sourcefiles/gdcm_source.sh"  | head -n+1 | tail -n-1 | awk -F\" '{print $2}')
echo " "
if [ $master_gdcm_source_ver -gt $this_gdcm_source_ver ]; then
  echo "There is a newer version of this source file in /Shared/pinc/sharedopt/apps/sourcefiles/"
  echo "You might want to consider updating to it."
  echo "If you have questions, feel free to contact Jason Evans (jason-evans@uiowa.edu)"
  echo " "
else
 :
fi

kernel="$(uname -s)"
hardware="$(uname -m)"

## What version do we want to use? ##
selected__gdcm_ver="2.8.6"

## The Actual command ##
export LD_LIBRARY_PATH="/Shared/pinc/sharedopt/apps/gdcm/$kernel/$hardware/$selected__gdcm_ver/lib"
export PATH="$PATH:/Shared/pinc/sharedopt/apps/gdcm/$kernel/$hardware/$selected__gdcm_ver/bin"
