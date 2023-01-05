#!/bin/bash

## Basic version check ##
this_convert3D_source_ver="2018043001"
master_convert3D_source_ver=$(grep this_convert3D_source_ver "/Shared/pinc/sharedopt/apps/sourcefiles/convert3d_source.sh"  | head -n+1 | tail -n-1 | awk -F\" '{print $2}')
echo " "
if [ $master_convert3D_source_ver -gt $this_convert3D_source_ver ]; then
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
selected__convert3D_ver="1.0.0"

## The Actual command ##
export PATH="$PATH:/Shared/pinc/sharedopt/apps/convert3D/$kernel/$hardware/$selected__convert3D_ver/bin"
