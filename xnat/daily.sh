#!/bin/bash

#===============================================================================
# XNAT Daily Script
# Author: Steve Slevinski
# Date: 2020-10-20
# Example: ./daily.sh -i projects_sslevinski.tsv -d yesterday
#===============================================================================

INPUT=unset
DATE=unset
EMAIL=unset
OPERATOR=$(whoami)
cd /Dedicated/inc_scratch/xnat/

usage()
{
  echo "Usage: download 
      [ -i | --input-file INPUT]    - XNAT project name to project directory
      [ -d | --date DATE ] - date to process, YYYY-MM-DD or 'today' or 'yesterday'
      [ -e | --email EMAIL ] - optional email address for daily report"
  exit 2
}

OPTS=$(getopt -a --name download -o i:d:e: --long input:,date:,email: -- "$@")
if [ $? != 0 ]; then
  usage
fi

eval set -- "$OPTS"
while :
do
  case "$1" in
    -i | --input-file)  INPUT="$2"  ; shift 2 ;;
    -d | --date) DATE="$2" ; shift 2 ;;
    -e | --email) EMAIL="$2" ; shift 2 ;;
    --) shift; break ;;
  esac
done

if [ "$INPUT" == "unset" ] || [ "$DATE" == "unset" ]; then
  usage
fi

if [[ ! $DATE =~ ^20[0-9]{2}-[0-9]{2}-[0-9]{2}$ ]]; then
  DATE=$(date --date="$DATE" +%Y-%m-%d) || exit 5
fi

ALLLOG=$OPERATOR"_"$DATE".log"
cat <<EOM >$ALLLOG
cd /Dedicated/inc_scratch/xnat
./daily.sh -i ${INPUT} -d $DATE

-------------------
XNAT Daily Download
-------------------

EOM

ALLERR=$OPERATOR"_"$DATE".err"
echo "" > $ALLERR

mkdir -p $OPERATOR"_"$DATE

while IFS=$'\t' read -r -a LINE
do
  if [[ ${LINE[1]} == *\/* ]]; then
    LOG=$OPERATOR"_"$DATE"/"${LINE[0]}".log"
    ERR=$OPERATOR"_"$DATE"/"${LINE[0]}".err"
    SUBS=$OPERATOR"_"$DATE"/"${LINE[0]}".subs"
    EXPS=$OPERATOR"_"$DATE"/"${LINE[0]}".exps"

    ./download.sh -p ${LINE[0]} -d $DATE -o ${LINE[1]} 1> $LOG 2> >(tee >&1 $ERR)
    find ./${OPERATOR}_${DATE}/${LINE[0]}* -type f -empty -delete

    if [ -f $ERR ]; then
      cat $ERR >> $ALLERR
    fi
    if [ -f $LOG ]; then
      cat $LOG >> $ALLLOG
    fi
    if [ -f $SUBS ]; then
      echo "New subjects: $(paste -s -d '' $SUBS)" >> $ALLLOG
    fi
    if [ -f $EXPS ]; then
      echo "New experiments: $(paste -s -d '' $EXPS)" >> $ALLLOG
    fi

    for FILE in ${OPERATOR}_${DATE}/${LINE[0]}_${DATE}_*.zip; do
      [[ -e $FILE ]] || continue
      SIZE=$(du -h "$FILE")
      echo "" >> $ALLLOG
      echo "Experiment: "$SIZE >> $ALLLOG
    done

  fi

done < $INPUT

if [ $EMAIL != "unset" ]; then
  cat $ALLLOG | mailx -v -s "XNAT ${DATE} Report" \
  -S smtp-use-starttls \
  -S ssl-verify=ignore \
  -S smtp-auth=login \
  -S smtp=smtp://smtp.gmail.com:587 \
  -S from="ianimgcore@gmail.com" \
  -S smtp-auth-user="ianimgcore@gmail.com" \
  -S smtp-auth-password="we process brains for you" \
  -S ssl-verify=ignore \
  -S nss-config-dir=/etc/pki/nssdb/ \
  ${EMAIL}
fi

