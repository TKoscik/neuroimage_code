#!/bin/bash

## Basic version check ##
this_metamap_source_ver="2018042001"
master_metamap_source_ver=$(grep this_metamap_source_ver "/Shared/pinc/sharedopt/apps/sourcefiles/metamap_source.sh"  | head -n+1 | tail -n-1 | awk -F\" '{print $2}')
echo " "
if [ $master_metamap_source_ver -gt $this_metamap_source_ver ]; then
  echo "There is a newer version of this source file in /Shared/pinc/sharedopt/apps/sourcefiles/"
  echo "You might want to consider updating to it."
  echo "If you have questions, feel free to contact Jason Evans (jason-evans@uiowa.edu)"
  echo " "
else
 :
fi

kernel="$(uname -s)"
javaloc="$(which java)"

if [ "$1" != "start" ] && [ "$1" != "stop" ]; then
  echo "This script requires either a start or stop argument ONLY"
  return
fi

if [ $kernel == "Linux" ]
  then
    METAMAPDIR=/Shared/pinc/sharedopt/apps/metamap/Linux/x86_64/2016v2/bin
    PATH=${PATH}:${METAMAPDIR}
    JAVA_HOME=${javaloc}
    export PATH
    export JAVA_HOME
elif [ $kernel == "Darwin" ]
  then
    METAMAPDIR=/Shared/pinc/sharedopt/apps/metamap/Darwin/x86_64/2016v2/bin
    PATH=${PATH}:${METAMAPDIR}
    JAVA_HOME=${javaloc}
    export PATH
    export JAVA_HOME
else
  echo "I can't determine the OS so I can set the appropriate MetaMap setup."
  return
fi

## Have to create a different location for log files for this because it insists on ##
## saving logs to it's app directory.                                               ##
taggerLogsDir=/scratch/metamap/logs/Tagger_server/log
wsdLogsDir=/scratch/metamap/logs/WSD_Server/log
if [ "$1" == "start" ]; then
  if [ ! -d /scratch/metamap/logs ]; then
    mkdir -p ${taggerLogsDir}
    mkdir -p ${wsdLogsDir}

    if [ ! -f ${taggerLogsDir}/errors ]; then
      touch ${taggerLogsDir}/errors
      chmod 777 ${taggerLogsDir}/errors
    fi
    if [ ! -f ${taggerLogsDir}/log ]; then
      touch ${taggerLogsDir}/log
      chmod 777 ${taggerLogsDir}/log
    fi
    if [ ! -f ${taggerLogsDir}/pid ]; then
      touch ${taggerLogsDir}/pid
      chmod 777 ${taggerLogsDir}/pid
    fi			

    if [ ! -f ${wsdLogsDir}/pid ]; then
      touch ${wsdLogsDir}/pid
      chmod 777 ${wsdLogsDir}/pid
    fi
    if [ ! -f ${wsdLogsDir}/WSD_Server.log ]; then
      touch ${wsdLogsDir}/WSD_Server.log
      chmod 777 ${wsdLogsDir}/WSD_Server.log
    fi
  fi
elif [ "$1" == "stop" ]; then
  rm -rf /scratch/metamap
else
  echo "Incorrect argument.  Please use start|stop for this script to run porperly."
fi

## These start/stop the "server" processes that are required for the app to run properly. ##
${METAMAPDIR}/skrmedpostctl $1
${METAMAPDIR}/wsdserverctl $1

sleep 5

#if [ $1 == "stop" ]; then
#  skrmedRUNNING="$(ps aux | grep java | grep taggerServer | awk '{print $2}')"
#  wsdRUNNING="$(ps aux | grep java | grep wsd.server | awk '{print $2}')"
#  if [ -z "$skrmedRUNNING" ]; then
#    kill -9 $skrmedRUNNING
#  fi
#  if [ -z "$wsdRUNNING" ]; then
#    kill -9 $wsdRUNNING
#  fi
#fi

