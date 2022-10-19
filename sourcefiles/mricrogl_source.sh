#!/bin/bash

## Basic version check ##
this_MRIcroGL_source_ver="2018071601"
master_MRIcroGL_source_ver=$(grep this_MRIcroGL_source_ver "/Shared/pinc/sharedopt/apps/sourcefiles/mricrogl_source.sh"  | head -n+1 | tail -n-1 | awk -F\" '{print $2}')
echo " "
if [ $master_MRIcroGL_source_ver -gt $this_MRIcroGL_source_ver ]; then
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
mricrogl_selected_ver="20180614"

## Figuring out if we need extra configurations or not. ##
if [ $mricrogl_selected_ver = "20180614" ]; then
  echo "This version wants to use FSL so we are going to attemp to configure FSL before MRIcroGL."
  if [ ! -f "~/sourcefiles/fsl_source.sh" ]; then
    echo "using user's source file"
    source ~/sourcefiles/fsl_source.sh
  else
    echo "using system source file"
    source /Shared/pinc/sharedopt/apps/sourcefiles/fsl_source.sh
  fi
  if [ -z "$FSLDIR" ]; then
    echo "Something went wrong configuring FSL. We will attempt to configure MRIcroGL without FSL."
  fi
fi

## The Actual command ##
export PATH="/Shared/pinc/sharedopt/apps/MRIcroGL/$kernel/$hardware/$mricrogl_selected_ver:$PATH"

## Verify that everything worked ##
path_updated_with_mricrogl=$(echo $PATH | awk -F: '{ for (i = 1; i <= NF; ++i ) print $i }' | grep MRIcroGL)
if [ -z "$path_updated_with_mricrogl" ]; then
  echo "Something went wrong.  Please contact Jason Evans. jason-evans@uiowa.edu"
else
  echo "You should now be set up to use MRIcroGL v${mricrogl_selected_ver}"
fi
