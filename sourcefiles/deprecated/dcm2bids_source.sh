#!/bin/bash

## Basic version check ##
this_dcm2bids_source_ver="2018042001"
master_dcm2bids_source_ver=$(grep this_dcm2bids_source_ver "/Shared/pinc/sharedopt/apps/sourcefiles/dcm2bids_source.sh"  | head -n+1 | tail -n-1 | awk -F\" '{print $2}')
echo " "
if [ $master_dcm2bids_source_ver -gt $this_dcm2bids_source_ver ]; then
  echo "There is a newer version of this source file in /Shared/pinc/sharedopt/apps/sourcefiles/"
  echo "You might want to consider updating to it."
  echo "If you have questions, feel free to contact Jason Evans (jason-evans@uiowa.edu)"
  echo " "
else
 :
fi

kernel="$(uname -s)"
alreadyset="$(echo "$PATH" | grep -o anaconda3)"

if [ $kernel == "Linux" ]; then
  if [ "$alreadyset" == "anaconda3" ]; then
    export PATH="$PATH:/Shared/pinc/sharedopt/apps/MRIcroGL/Linux/x86_64/1.0.20170808"
  else
    export PATH="/Shared/pinc/sharedopt/apps/MRIcroGL/Linux/x86_64/1.0.20170808:/Shared/pinc/sharedopt/apps/anaconda3/Linux/x86_64/4.4.0/bin:$PATH"
  fi

elif [ $kernel == "Darwin" ]; then
  if [ "$alreadyset" == "anaconda3" ]; then
    export PATH="$PATH:/Shared/pinc/sharedopt/apps/MRIcroGL/Darwin/x86_64/20170808"
  else
    export PATH="/Shared/pinc/sharedopt/apps/MRIcroGL/Darwin/x86_64/20170808:/Shared/pinc/sharedopt/apps/anaconda3/Darwin/x86_64/4.4.0/bin:$PATH"
  fi

else
  echo "I can't determine the OS so I can set the appropriate Anaconda3 setup."
fi
