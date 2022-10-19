#!/bin/bash

## Basic version check ##
this_anaconda2_source_ver="2018042001"
master_anaconda2_source_ver=$(grep this_anaconda2_source_ver "/Shared/pinc/sharedopt/apps/sourcefiles/anaconda2_source.sh"  | head -n+1 | tail -n-1 | awk -F\" '{print $2}')
echo " "
if [ $master_anaconda2_source_ver -gt $this_anaconda2_source_ver ]; then
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

## What version of Anaconda2 do we want to run? ##
selected_ver="5.3.0"

## The actual work ##
export PATH="/Shared/pinc/sharedopt/apps/anaconda2/$kernel/$hardware/$selected_ver/bin:$PATH"
