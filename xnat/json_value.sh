#!/bin/bash

#===============================================================================
# JSON Value script
#   bash scripts that uses REGEX to capture a string or numberic value for a key
#   The program "jq" should replace this hack, but it isn't available yet.
# Author: Steve Slevinski
# Version: 1.1.0
# Date: 2020-10-15
#
# Todo: handle escaped double quotes
# Todo: support for boolean, arrays, and objects
# Todo: add flag to return multiple results if a key appears multiple times
#===============================================================================

json_value() {
  JSON=$(cat)
  REGEX_STR="\"$1\": ?\"([^\".]+)\""
  REGEX_NUM="\"$1\": ?(\-?[0-9]+(\.[0-9]+)?)"
  if [[ $JSON =~ $REGEX_STR ]]; then
    VALUE="${BASH_REMATCH[1]}"
    echo $VALUE 
  elif [[ $JSON =~ $REGEX_NUM ]]; then
    VALUE="${BASH_REMATCH[1]}"
    echo $VALUE 
  fi
}

if [ `basename "$0"` == "json_value.sh" ]; then
  json_value $1
fi

