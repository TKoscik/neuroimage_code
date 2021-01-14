#!/bin/bash

#===============================================================================
# XNAT Download Script
# Author: Steve Slevinski
# Date: 2020-10-15
# Example: ./download.sh -p TK_BLACK -d 2020-06-29 1> out.log 2> out.err
#===============================================================================

source json_value.sh #until JQ is available

PROJ=unset
DATE=unset
OUTPUT=unset
OPERATOR=$(whoami)

usage()
{
  echo "Usage: download 
      [ -p | --project PROJ]    - XNAT project name
      [ -d | --date DATE ] - date for download, YYYY-MM-DD or 'today' or 'yesterday'
      [ -o | --output OUTPUT ] - output directory" 1>&2
  exit 2
}

OPTS=$(getopt -a --name download -o p:d:o: --long project:,date:,output: -- "$@")
VALID_ARGUMENTS=$?
if [ "$VALID_ARGUMENTS" != "0" ]; then
  usage
fi
eval set -- "$OPTS"
while :
do
  case "$1" in
    -p | --project)  PROJ="$2"  ; shift 2 ;;
    -d | --date) DATE="$2" ; shift 2 ;;
    -o | --output) OUTPUT="$2" ; shift 2 ;;
    --) shift; break ;;
  esac
done

if [ "$PROJ" == "unset" ] || [ "$DATE" == "unset" ] || [ "$OUTPUT" == "unset" ]; then
  usage
fi

[[ "$PROJ" =~ ^(TK_BLACK|OTHER)$ ]] && COMBO=true || COMBO=false

if [[ ! $DATE =~ ^20[0-9]{2}-[0-9]{2}-[0-9]{2}$ ]]; then
  DATE=$(date --date="$DATE" +%Y-%m-%d) || exit 5
fi

UP=`cat ~/.xnatUP`

if [ -z "$UP" ]; then
  read -p "Username: " USER
  read -s -p "Password: " PASS
  echo ""
  UP=$USER":"$PASS
fi

echo "== "$PROJ" =="

URL="https://rpacs.iibi.uiowa.edu/xnat/data/projects/"$PROJ"/subjects?format=csv"
echo "URL: "$URL
curl -X GET -u $UP $URL --fail --silent --show-error | awk -F "\"*,\"*" '{ print $3"\t"$4 }' | grep $DATE | cut -f1 > $OPERATOR"_"$DATE"/"$PROJ".subs"

URL="https://rpacs.iibi.uiowa.edu/xnat/data/projects/"$PROJ"/experiments?format=csv"
echo "URL: "$URL
curl -X GET -u $UP $URL --fail --silent --show-error | awk -F "\"*,\"*" '{ print $2"\t"$7 }' | grep $DATE | cut -f1 > $OPERATOR"_"$DATE"/"$PROJ".exps"
#curl -X GET -u $UP $URL --fail --silent --show-error > $OPERATOR"_"$DATE"/"$PROJ"_all.exps"

while read EXP; do
  URL="https://rpacs.iibi.uiowa.edu/xnat/data/experiments/"$EXP"/scans/ALL/files?format=zip"
  echo "URL: "$URL
###  curl -X GET -u $UP $URL --fail --silent --show-error > $OPERATOR"_"$DATE"/"$PROJ"_"$EXP".zip"
done < $OPERATOR"_"$DATE"/"$PROJ".exps"
echo ""

if $COMBO; then
  while read EXP; do
    URL="https://rpacs.iibi.uiowa.edu/xnat/data/experiments/"$EXP"?format=json"
    echo "URL: "$URL
    curl -X GET -u $UP $URL --fail --silent --show-error | json_value dcmPatientName | sed -e "s/$/\t$EXP/" > $OPERATOR"_"$DATE"/"$PROJ"_"$EXP".sub"
  done < $OPERATOR"_"$DATE"/"$PROJ".exps"

  XREF=$OPERATOR"_"$DATE"/"$PROJ".xref"
  cat ${OPERATOR}_${DATE}/${PROJ}_*sub > $XREF
  rm -f ${OPERATOR}_${DATE}/${PROJ}_*.exps
  while IFS=$'\t' read -r -a LINE; do
    SUB=$OPERATOR"_"$DATE"/"$PROJ"_"${LINE[0]}".exps"
    echo ${LINE[1]} >> $SUB
  done < $XREF

  TEMP=$OPERATOR"_temp/"
  TEMP0=$TEMP"0/"
  TEMP1=$TEMP"0/"
  for SUB in ${OPERATOR}_${DATE}/${PROJ}_*.exps; do
    mapfile -t EXPS < $SUB
    if [ ${#EXPS[@]} = 2 ]; then
      rm -rf $TEMP
      mkdir $TEMP
      FILE=$OPERATOR"_"$DATE"/"$PROJ"_"${EXPS[0]}".zip"
      unzip -q $FILE -d $TEMP0
      FILE=$OPERATOR"_"$DATE"/"$PROJ"_"${EXPS[1]}".zip"
      unzip -q $FILE -d $TEMP1
      /Shared/inc_scratch/code/dicom/dicom_conversion.sh --dir-project $OUTPUT --dicom-zip $TEMP --dicom-depth 11
      rm -rf $TEMP
    else
      FILE=$OPERATOR"_"$DATE"/"$PROJ"_"${EXP[0]}".zip"
      if [[ -f $FILE ]]; then
        /Shared/inc_scratch/code/dicom/dicom_conversion.sh --dir-project $OUTPUT --dicom-zip $FILE --dicom-depth 10
      else
        echo "MISSING: "$FILE 1>&2
      fi
    fi
  done
else
  for FILE in ${OPERATOR}_${DATE}/${PROJ}_*.zip; do
    if [[ -f $FILE ]]; then
      /Shared/inc_scratch/code/dicom/dicom_conversion.sh --dir-project $OUTPUT --dicom-zip $FILE --dicom-depth 10
    fi
  done
fi

