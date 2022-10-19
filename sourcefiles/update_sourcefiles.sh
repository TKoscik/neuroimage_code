#!/bin/bash

clear
echo "This script is just a quick updater to update all of the source files in this directory"
echo "to your home directory. Do not run this as a source file.  It is just a bash script."
echo " "
echo "If you have any questions about the use of this file, please contact Jason Evans"
echo "jason-evans@uiowa.edu"
echo " "

rsync -av /Shared/pinc/sharedopt/apps/sourcefiles/ ~/sourcefiles/
