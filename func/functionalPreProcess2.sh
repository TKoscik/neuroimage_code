#!/bin/bash

####################

ver=1.0.0
verDate=1/4/20

####################

# A giant wrapper script that will regress nuisance parameters from functional (task or rest) EPI data.  Optional settings are for low/high/bandpass filtering, smoothing.
# Possible nuisance regression may be one or more of the following (mix & match ONLY if you know what you are doing):
#  1) Friston24 (motion parameters + quadratics & derivatives)
#  2) compcor (wm, csf eigenvariates (3 eigenvariates per tissue class, 0 mean))
#  3) Spike regression (cumalative motion > 0.25 mm), one file per TR over the limit
#  4) ICA-AROMA
#  5) Global Signal Regression
#  6) lesion mask (leftover after accounting for wm, csf signal)
#
# by Joel Bruss (joel-bruss@uiowa.edu)

#########################################################################################################

scriptName="functionalPreProcess2.sh"
scriptDir=/Shared/nopoulos/nimg_core
atlasDir=${scriptDir}/templates_human

userID=`whoami`
source ${scriptDir}/sourcePack.sh

doAltScale=0
doAtlasResample=0
doCompCor=0
doDespike=0
doGlobalSignal=0
doHighPass=0
doIcaAroma=0
doLowPass=0
doMotionScrub=0
doSmooth=0
doSpikeRegression=0
do36p=0

#Source versions of programs used:
VER_afni=${VER_afni}
VER_ants=${VER_ants}
VER_fsl=${VER_fsl}
VER_matlab=${VER_matlab}

#########################################################################################################

printCommandLine() {
  echo ""
  echo "Usage: functionalProcessingStream2.sh --epiList=epiList --regressionBase=regresisonBase --atlasName=atlasName --despike --smoothSize=smoothSize --lowPass=lowPass --highPass=highPass --compCor --36p --icaAroma --spikeRegression --globalSignal --TR=TR --subject=sub --session=ses --site=site --researcher=researcher --project=project --researchGroup=researchGroup"
  echo ""
  echo "   where:"
  echo "     --epiList:  Input EPI (comma-separated list of input EPI to be processed(e.g. 'epi1,epi2')).  Motion-corrected (standard space) data from functionalProcessingStream1."
  echo "     --regressionBase:  base name for directory to store regression workup.  This allows different combos of regresison types to be run and saved in different directories (e.g. compcor, gsr, etc.)"
  echo "     --atlasName:  Atlas (space independent) used in functionalPreProcess1.sh"

  echo "     --smoothSize:  Size of smoothing kernel in mm (will be rescaled to Sigma for use with FSL's 'SUSAN'"
  echo "     --lowPass:  Frequency (Hz) at which high frequencies will be cut (e.g. 0.008)"
  echo "     --highPass:  Frequency (Hz) at which low frequencies will be cut (e.g. 0.08)"
  echo "             *If both lowPass and highPass are set, a bandpass filter (between highPass and lowPass) will be applied"
  echo ""
  echo "     **pre-canned regression styles.  Choose one or more of the following:"
  echo "     --compCor:  WM, CSF (eigenvectors)"
  echo "     --36p:  Friston-24/Volterra Expansion (+ quadratics and derivatives)"
  echo "       *If not set to 36p, will default to 6 rotations and translations"
  echo "     --icaAroma:  python based classifier for denoising"
  echo "     --spikeRegression:  Motion metric/threshold, per TR"
  echo "     --globalSignal:  TR to TR whole-brain signal change"
  echo "     --despike:  Perform Despiking on data before any other processing (do NOT use this in conjunction with spikeRegression)"
  echo ""
  echo "     --motionScrub:  Censoring of TRs for motion, via FD, DVARS thresholding"
  echo ""
  echo "     --TR:  TR of input EPI in seconds.  Set this if you wish to override AFNI's desire to read from the header.  Some preprocessing looks to round this value"
  echo ""
  echo "     --altScale:  Rather than sub mean, div sd, add 1000, just sub mean, add 1000"
  echo ""
  echo "     --resampleToAtlas:  Resample residual to be in true grid/voxel atlas space"
  echo "     --atlasSize:  Using 'atlasName' file, spacing (e.g. 2mm) to push data into.  If none give, default to 2mm."
  echo ""
  echo "    Project-specific variables:"
  echo "     --subject:  Subject"
  echo "     --session:  Session"
  echo "     --site:  Site"
  echo "     --researcher:  Researcher"
  echo "     --project:  Project"
  echo "     --researchGroup:  Permissions group"
  echo ""
  echo ""
  exit 1
}


get_opt1() {
  arg=$(echo "$1" | sed 's/=.*//')
  echo "$arg"
}

get_arg1() {
    if [ X"$(echo "$1" | grep '=')" = X ] ; then
      echo "Option $1 requires an argument" 1>&2
      exit 1
    else
      arg=$(echo "$1" | sed 's/.*=//')
      if [ X"$arg" = X ] ; then
          echo "Option $1 requires an argument" 1>&2
          exit 1
      fi
	    echo "$arg"
    fi
}


while [ $# -ge 1 ] ; do
    iarg=$(get_opt1 "$1");
    case "$iarg"
	in
    -h)
        PrintCommandLine;
        exit 0;;
    --researcher) #e.g. /Shared/nopolous
        researcher=$(get_arg1 "$1");
        export researcher
        if [[ "${researcher}" == "" ]]; then
          echo "Error: The input '--researcher' is required"
          exit 1
        fi
          shift;;
    --project) #e.g. sca_pilot
        project=$(get_arg1 "$1");
        export project
        if [[ "${project}" == "" ]]; then
          echo "Error: The input '--project' is required"
          exit 1
        fi
          shift;;
    --subject) #e.g. 231
        subject=$(get_arg1 "$1");
        export subject
        if [[ "${subject}" == "" ]]; then
          echo "Error: The input '--subject' is required"
          exit 1
        fi
          shift;;
    --session) #e.g. 328zk16wb6
        session=$(get_arg1 "$1");
        export session
        if [[ "${session}" == "" ]]; then
          echo "Error: The input '--session' is required"
          exit 1
        fi
          shift;;
    --site) #e.g. 00201
        site=$(get_arg1 "$1");
        export site
        if [[ "${site}" == "" ]]; then
          echo "Error: The input '--site' is required"
          exit 1
        fi
          shift;;
    --researchGroup) #e.g. 900031646
        researchGroup=$(get_arg1 "$1");
        export researchGroup
        if [[ "${researchGroup}" == "" ]]; then
          echo "Error: The input '--researchGroup' is required"
          exit 1
        fi
          shift;;
    --epiList) #Input EPI(s) to process
        epiList=$(get_arg1 "$1");
        export epiList
        if [[ "${epiList}" == "" ]]; then
          echo "Error: The input '--epiList' is required"
          exit 1
        fi
          shift;;
    --regressionBase) #Base name for regression directory (..../derivatives/func/resid/${regressionBase}/resid_${templateName}_native).
        regressionBase=$(get_arg1 "$1");
        export regressionBase
        if [[ "${regressionBase}" == "" ]]; then
          echo "Error: The input '--regressionBase' is required"
          exit 1
        fi
          shift;;
    --smoothSize) #Smoothing kernel (in mm) -- will be rescaled to FSL's sigma
        smoothSize=$(get_arg1 "$1");
        export smoothSize
        doSmooth=1
        export doSmooth
          shift;;
    --lowPass) #Cutoff frequency, Hz, for lowPass filter (e.g. 0.08)
        lowPass=$(get_arg1 "$1");
        export lowPass
        doLowPass=1
        export doLowPass
          shift;;
    --highPass) #Cutoff frequency, Hz, for highPass filter (e.g. 0.008)
        highPass=$(get_arg1 "$1");
        export highPass
        doHighPass=1
        export doHighPass
          shift;;
    --compCor) #Use 5 eigenvariates for WM, CSF for compCore regression
        doCompCor=1
        export doCompCor
          shift;;
    --icaAroma) #Run ICA-AROMA
        doIcaAroma=1
        export doIcaAroma
          shift;;
    --spikeRegression) #Run spike regresion (cumulative rms < 0.25 between TRs.  "1" for TR above threshold, 0 otherwise)
        doSpikeRegression=1
        export doSpikeRegression
          shift;;
    --36p) #6 motion, WM, CSF, Global regression (derivatives, quadratics, quadratics of derivatives)
        do36p=1
        export do36p
          shift;;
    --globalSignal) #Regress out mean global signal
        doGlobalSignal=1
        export doGlobalSignal
          shift;;
    --motionScrub) #Scrub out TR's with too much motion
        doMotionScrub=1
        export doMotionScrub
          shift;;
    --despike) #Run AFNI's 3dDespike, with the brain mask applied
        doDespike=1
        export doDespike
          shift;;
    --TR) #Use the supplied TR value (s) rather than relying on AFNI to read the header of input (which can be changed from previouis pre-processing)
        TR=$(get_arg1 "$1");
        export TR
          shift;;
    --atlasName) #Atlas space of motCor EPI (e.g. HCPMNI2009c)
        atlasName=$(get_arg1 "$1");
        export atlasName
          shift;;
    --altScale) #Alternate scaling option (subtract mean, add 1000)
        doAltScale=1
        export doAltScale
          shift;;
    --resampleToAtlas) #Resample residual to be in true grid/voxel atlas space
        doAtlasResample=1
        export doAtlasResample
          shift;;
    --atlasSize) #Atlas spacing (e.g. 2mm)
        atlasSize=$(get_arg1 "$1");
        export atlasSize
          shift;;
    ?)
      echo "ERROR: Invalid option"
      printCommandLine
      ;;
     esac
done

#########################################################################################################

#Begin Logging
if [[ ! -d ${researcher}/${project}/log ]]; then
  mkdir -p ${researcher}/${project}/log
fi

subject_log=${researcher}/${project}/log/sub-${subject}_ses-${session}_site-${site}.log

echo '#--------------------------------------------------------------------------------' >> ${subject_log}
echo "ParentTask:functionalPreProcessing2" >> ${subject_log}
echo "script:${scriptDir}/${scriptName}" >> ${subject_log}
echo "software:AFNI,version:${VER_afni}" >> ${subject_log}
echo "software:ANTs,version:${VER_ants}" >> ${subject_log}
echo "software:FSL,version:${VER_fsl}" >> ${subject_log}
echo "software:matlab,version:${VER_matlab}" >> ${subject_log}
echo "owner: ${userID}" >> ${subject_log} >> ${subject_log}
date +"start:%Y-%m-%dT%H:%M:%S%z" >> ${subject_log} >> ${subject_log}

#########################################################################################################

########################################

#Data dependencies:
 #EPI data
  #Motion Parameter directory
parDir=${researcher}/${project}/derivatives/func/prep/sub-${subject}/ses-${session}/motionCorr
  #Tissue class directory (in epi space)
tisDir=${researcher}/${project}/derivatives/func/segmentation
  #Base regression directory (temporary processing directory)
regressionDir=${researcher}/${project}/derivatives/func/prep/sub-${subject}/ses-${session}/regressDir/${regressionBase}
  if [[ ! -d $regressionDir ]]; then
    mkdir -p $regressionDir
  fi
  #Residual directory
residualDir=${researcher}/${project}/derivatives/func/resid/${regressionBase}
  if [[ ! -d $residualDir ]]; then
    mkdir -p $residualDir
  fi
  #EPI Mask directory
maskDir=${researcher}/${project}/derivatives/func/mask
  #Filter settings
if [[ $doLowPass -eq 0 && $doHighPass -eq 0 ]]; then  #allpass filter (removal of "0" & Nyquist frequency only)
    fbot=0
    ftop=99999
elif [[ $doLowPass -eq 0 && $doHighPass -eq 1 ]]; then #highpass filter (frequencies below $highPass will be filtered)
    fbot=${highPass}
    ftop=99999
elif [[ $doLowPass -eq 1 && $doHighPass -eq 0 ]]; then #lowpass filter (frequencies above $lowPass will be filtered)
    fbot=0
    ftop=${lowPass}
else  #bandpass filter (frequencies between $highPass and $lowPass will be filtered)
   fbot=${highPass}
   ftop=${lowPass}
fi
  #Atlas resampling space
if [[ ${doAtlasResample} ]]; then
  if [[ ${atlasSize} == "" ]]; then
    atlasSize="2mm"
  fi
fi

########################################

#Resample file to true atlas grid/voxel space
atlasResample()
{
  input=$1
  outDir=$2
  atlasSize=$3

  epiBaseRes=`basename $input | awk -F"." '{print $1}'`

  $ANTSPATH/antsApplyTransforms -d 3 -e 3 -i ${input} \
  -r ${atlasDir}/${atlasName}/${atlasSize}/${atlasName}_${atlasSize}_T1w.nii.gz \
  -o ${outDir}/${epiBaseRes}.nii.gz \
  -t identity -n NearestNeighbor
}

#Rescale data to a new mean value
dataScale()
{
  input=$1
  mask=$2
  outDir=$3
  scaleVal=$4

  #Scale the epi Mask by 1000 (in order to mean scale data to 1000)
  if [[ ! -e ${regressionDir}/tmpResid/${epiBase}_mask${scaleVal}.nii.gz ]]; then
    $FSLDIR/bin/fslmaths ${mask} -bin -mul ${scaleVal} ${regressionDir}/tmpResid/${epiBase}_mask${scaleVal}.nii.gz -odt short
  fi

    #Another option is to subtract mean, divide by sd, mul x100, add 1000

  #Normalize the data
  $FSLDIR/bin/fslmaths ${input} -Tmean ${regressionDir}/tmpResid/${epiBase}_res4d_tmean.nii.gz
  $FSLDIR/bin/fslmaths ${input} -Tstd ${regressionDir}/tmpResid/${epiBase}_res4d_std.nii.gz
  $FSLDIR/bin/fslmaths ${input} -sub ${regressionDir}/tmpResid/${epiBase}_res4d_tmean.nii.gz ${regressionDir}/tmpResid/${epiBase}_res4d_dmean.nii.gz
  $FSLDIR/bin/fslmaths ${regressionDir}/tmpResid/${epiBase}_res4d_dmean.nii.gz -div ${regressionDir}/tmpResid/${epiBase}_res4d_std.nii.gz \
  ${regressionDir}/tmpResid/${epiBase}_res4d_normed.nii.gz
  $FSLDIR/bin/fslmaths ${regressionDir}/tmpResid/${epiBase}_res4d_normed.nii.gz -add ${regressionDir}/tmpResid/${epiBase}_mask${scaleVal}.nii.gz \
  ${outDir}/${epiBase}.nii.gz -odt float
}

dataScale2()
{
  input=$1
  mask=$2
  outDir=$3
  scaleVal=$4

  #Scale the epi Mask by 1000 (in order to mean scale data to 1000)
  if [[ ! -e ${regressionDir}/tmpResid/${epiBase}_mask${scaleVal}.nii.gz ]]; then
    $FSLDIR/bin/fslmaths ${mask} -bin -mul ${scaleVal} ${regressionDir}/tmpResid/${epiBase}_mask${scaleVal}.nii.gz -odt short
  fi

  #Normalize the data
  $FSLDIR/bin/fslmaths ${input} -Tmean ${regressionDir}/tmpResid/${epiBase}_res4d_tmean.nii.gz
  $FSLDIR/bin/fslmaths ${input} -sub ${regressionDir}/tmpResid/${epiBase}_res4d_tmean.nii.gz -add ${regressionDir}/tmpResid/${epiBase}_mask${scaleVal}.nii.gz \
  ${outDir}/${epiBase}.nii.gz -odt float
}

#Calculate quadradics and derivatives of an input set of regressors (e.g. mcImg.par) -- Take from HCP pipeline and altered
deriveBackwards()
{
  i=$1
  in=$2
  outDir=$3

  #Var becomes a string of values from column $i in $in. Single space separated
  Var=`cat ${in} | sed s/"  "/" "/g | cut -d " " -f ${i}`
  Length=`echo ${Var} | wc -w`
  #TCS becomes an array of the values from column $i in $in (derived from $Var)
  TCS=($Var)

  #Cycle through our array of values from column $i
  j=0
  while [[ ${j} -lt ${Length} ]] ; do
    if [[ ${j} -eq 0 ]] ; then #First volume
      #Backward derivative of first volume is set to 0
      Answer=`echo "0"`
      AnswerSquared=`echo "0"`

      #Format numeric value (convert scientific notation to decimal) jth row of ith column in $in
      Forward=`echo ${TCS[$j]} | awk -F"E" 'BEGIN{OFMT="%10.10f"} {print $1 * (10 ^ $2)}'`

      #Quadratic of original parameter
      ForwardSquared=`echo "scale=10; ${Forward} * ${Forward}" | bc -l`
    else #Compute the backward derivative of non-first volumes
      #Format numeric value (convert scientific notation to decimal) jth row of ith column in $in
      Forward=`echo ${TCS[$j]} | awk -F"E" 'BEGIN{OFMT="%10.10f"} {print $1 * (10 ^ $2)}'`
    
      #Similarly format numeric value for previous row (j-1)
      Back=`echo ${TCS[$(($j-1))]} | awk -F"E" 'BEGIN{OFMT="%10.10f"} {print $1 * (10 ^ $2)}'`

      #Quadratic of original parameter
      ForwardSquared=`echo "scale=10; ${Forward} * ${Forward}" | bc -l`

      #Compute backward derivative as current minus previous
      Answer=`echo "scale=10; ${Forward} - ${Back}" | bc -l`

      #Quadratic of derivative
      AnswerSquared=`echo "scale=10; ${Answer} * ${Answer}" | bc -l`
    fi
    #0 prefix the resulting number(s)
    ForwardSquared=`echo ${ForwardSquared} | sed s/"^\."/"0."/g | sed s/"^-\."/"-0."/g`
    Answer=`echo ${Answer} | sed s/"^\."/"0."/g | sed s/"^-\."/"-0."/g`
    AnswerSquared=`echo ${AnswerSquared} | sed s/"^\."/"0."/g | sed s/"^-\."/"-0."/g`

    echo `printf "%10.6f" ${Answer}` >> ${outDir}/tmp1
    echo `printf "%10.6f" ${AnswerSquared}` >> ${outDir}/tmp2
    echo `printf "%10.6f" ${ForwardSquared}` >> ${outDir}/tmp3

    j=$(($j + 1))
  done

    #Need to push all 3 columns of each calculation (R^2, R`, (R`)^2) together as each iteration of "${i}" (column) creates three new tmp files
    if [ ${i} -eq 1 ] ; then
      mv ${outDir}/tmp1 ${outDir}/_tmp1
      mv ${outDir}/tmp2 ${outDir}/_tmp2
      mv ${outDir}/tmp3 ${outDir}/_tmp3
    else
      paste -d " " ${outDir}/_tmp1 ${outDir}/tmp1  > ${outDir}/_tmp1b
      mv ${outDir}/_tmp1b ${outDir}/_tmp1
      paste -d " " ${outDir}/_tmp2 ${outDir}/tmp2  > ${outDir}/_tmp2b
      mv ${outDir}/_tmp2b ${outDir}/_tmp2
      paste -d " " ${outDir}/_tmp3 ${outDir}/tmp3  > ${outDir}/_tmp3b
      mv ${outDir}/_tmp3b ${outDir}/_tmp3
      #Clean up temporary files
      rm ${outDir}/tmp1 ${outDir}/tmp2 ${outDir}/tmp3
    fi
}

#Calculate the mean time-series for an EPI within a masked region
  #Option for 5 output eigenvariates (0 mean) per input masked region
meanTS()
{
  input=$1
  output=$2
  inputMask=$3
  compCorFlag=$4

  if [[ ${compCorFlag} -eq 1 ]]; then
    $FSLDIR/bin/fslmeants -i ${input} -o ${output} -m ${inputMask} --eig --order=5
  else
    $FSLDIR/bin/fslmeants -i ${input} -o ${output} -m ${inputMask}
  fi
}

#Rescale data over median intensity, value 0f 10000
medianScale()
{
  infile=$1
  mask=$2
  outDir=$3

  medVal=`$FSLDIR/bin/fslstats ${infile} -k ${mask} -p 50`
  scaleVal=`echo "scale=16; 10000/${medVal}" | bc`
  $FSLDIR/bin/fslmaths ${infile} -mul ${scaleVal} ${outDir}/${epiBase}.nii.gz
}

#Motion scrub the TRs with too much motion
motionScrub()
{
  input=$1
  parfile=$2

cat > ${regressionDir}/tmpResid/motionScrub/${epiBase}_run_motionScrub.m << EOF
% It is matlab script
addpath(genpath('${scriptDir}'));
niftiScripts=['${scriptDir}','/matlabDependencies/nifti'];
addpath(genpath((niftiScripts));
motionscrub('${regressionDir}/tmpResid/motionScrub','${residualDir}/resid_${atlasName}_native/motionScrub','${epiBase}','${input}','${parfile}','${numVols}')
quit
EOF

  #Run the matlab script
  matlab -nodisplay -r "run ${regressionDir}/tmpResid/motionScrub/${epiBase}_run_motionScrub.m"

  #Summarize motion-scrubbing output
  echo "total_volumes,deleted_volumes,prop_deleted,resid_vols" > ${regressionDir}/tmpResid/motionScrub/${epiBase}_motion_scrubbing_info.txt


  delVols=`cat ${regressionDir}/tmpResid/motionScrub/deleted_vols.txt | wc | awk '{print $2}'`
  propDel=`echo ${numVols} ${delVols} | awk '{print ($2/$1)}'`
  residVols=`echo ${numVols} ${delVols} | awk '{print ($1-$2)}'`
  echo "${numVols},${delVols},${propDel},${residVols}" >> ${regressionDir}/tmpResid/motionScrub/${epiBase}_motion_scrubbing_info.txt

  gzip ${residualDir}/resid_${atlasName}_native/motionScrub/${epiBase}_motionscrubbed.nii
}

#Resample a file to a specified set of dimensions
resampleFile()
{
  input=$1
  outDir=$2
  outBase=$3
  resampDims=$4
  resampTarget=$5
  nnResample=$6

  resampDimsTrunc=`echo ${resampDims} | awk -F"x" '{OFS="x";print $1,$2,$3}' | sed 's/x/ /g'`
  targetBase=`basename ${resampTarget} | awk -F"." '{print $1}'`

  $ANTSPATH/ResampleImageBySpacing 3 ${input} ${outDir}/${outBase}_res_to-${targetBase}.nii.gz ${resampDimsTrunc} 0 0 ${nnResample}
}

# Simultaneously regress all regressor time series and filter
  # 3dTproject will demean (normalize) (need to add mean back in)
simultBandpassNuisanceReg()
{
  input=$1
  mask=$2
  regressorFile=$3
  trTrue=$4

  #Filter and regress (ALL nuisance time series) in one command
  $AFNIDIR/3dTproject -input ${input} -prefix ${regressionDir}/tmpResid/${epiBase}_tmp_bp.nii.gz -mask ${mask} -bandpass ${fbot} ${ftop} -ort ${regressorFile} -verb -TR ${trTrue}

  #Calculate, then add (original) mean back in (3dTproject demeans (normalizes))
  $AFNIDIR/3dTstat -mean -prefix ${regressionDir}/tmpResid/${epiBase}_orig_mean.nii.gz ${input}

  $AFNIDIR/3dcalc -a ${regressionDir}/tmpResid/${epiBase}_tmp_bp.nii.gz -b ${regressionDir}/tmpResid/${epiBase}_orig_mean.nii.gz \
  -expr "a+b" -prefix ${regressionDir}/tmpResid/${epiBase}_bp_res4d.nii.gz
}

#Calculate cumulative FD from TR to TR, if above 0.25mm, create a regression file (0 for all other TRs, 1 for TR above limit)
  #Will have one file TR that is above limit
  #sqrt((trN-(trN-1))^2)
spikeRegressionSetup()
{
  input=$1
  outBase=$2
  outDir=$3

  #Determine number of TRs total
  Length=`cat ${input} | wc -l`

  #Loop through the TRs
  i=2
  while [[ $i -le $Length ]];
    do

    #Set index for previous TR
    let j=i-1

    #Calculate cumulative motion for current TR, preceeding TR
    iSum=`cat $input | head -n+${i} | tail -n-1 | awk '{ for(y=1; y<=NF;y++) z+=$y; print z; z=0 }'`
    jSum=`cat $input | head -n+${j} | tail -n-1 | awk '{ for(y=1; y<=NF;y++) z+=$y; print z; z=0 }'`

    #Calculate rms of cumulative motion between TRs
    rmsVal=`echo ${iSum} ${jSum} | awk '{print sqrt(($1-$2)^2)}'`

    #If rms is >= 0.25, create a spike regression list (1 for current TR, 0 for all others)
    if (( $(echo "${rmsVal} >= 0.25" | bc -l) )); then
      let l=i+1

      #Empty TRs before spike TR
      pre=1
      while [[ ${pre} -lt ${i} ]];
        do
        echo "0" >> $outDir/${outBase}_spike_${i}.1D
        let pre=pre+1       
      done

      #Spike TR
      echo "1" >> $outDir/${outBase}_spike_${i}.1D

      #Empty TRs after spike TR
      post=${l}
      while [[ ${post} -le ${Length} ]];
        do
        echo "0" >> $outDir/${outBase}_spike_${i}.1D
        let post=post+1
      done

    fi

    let i=i+1
  done

  #Combine all spikes into one file
  paste -d " " `ls -1tv $outDir/${outBase}_spike_*.1D` > $outDir/${outBase}_spikes.1D
  rm $outDir/${outBase}_spike_*.1D
}

#Log the start/stop times
timeLog()
{
  input=$1

  if [[ ${input} == "s" ]]; then
    timeStamp=`date +"start:%Y-%m-%dT%H:%M:%S%z"`
  else
    timeStamp=`date +"end:%Y-%m-%dT%H:%M:%S%z"`
  fi
}

########################################


  ####################
  #  epiPrep_2       #
  ####################

#Process the EPI data
  #Log the task start time, set placeholder for end time
timeLog "s"
echo "task:epiPrep_2,${timeStamp},epiPrep2_TIMEEND" >> ${subject_log}

#March through EPI(s)
for epi in $(echo $epiList | sed "s/,/ /g");
  do

  #Round up some information about the input EPI
  epiBase=`basename $epi | awk -F"." '{print $1}'`
  epiPath=`dirname $epi`
  numVols=`$ANTSPATH/PrintHeader $epi 2 | awk -F"x" '{print $NF}'`
  trVal=`$ANTSPATH/PrintHeader $epi 1 | awk -F"x" '{print $NF}'`
  if [[ ${TR} == "" ]]; then
    TR=${trVal}
  else
    TR=${TR}
  fi

  #Motion parameters (all mm) for input EPI
  epiPar=${parDir}/${epiBase}_mcImg_mm.par

  #Mask for EPI
  epiMask=${maskDir}/${epiBase}_mask.nii.gz


    ####################
    #  epiDespike      #
    ####################

  if [[ ${doDespike} -eq 1 ]]; then

        #Log the task start time, set placeholder for end time
      timeLog "s"
      echo "task:epiDespike,${timeStamp},epiDespike_TIMEEND" >> ${subject_log}

    if [[ ! -d ${regressionDir}/despike ]]; then
      mkdir -p ${regressionDir}/despike
    fi

    $AFNIDIR/3dDespike -NEW -prefix ${regressionDir}/despike/${epiBase}.nii.gz ${epi}

    epi=${regressionDir}/despike/${epiBase}.nii.gz

        #Log the task end time
      timeLog "e"
      sed -i "s/epiDespike_TIMEEND/${timeStamp}/g" ${subject_log}
  fi

  ########################################

    ####################
    #  epiSmooth       #
    ####################

  if [[ ${doSmooth} -eq 1 ]]; then

        #Log the task start time, set placeholder for end time
      timeLog "s"
      echo "task:epiSmooth,${timeStamp},epiSmooth_TIMEEND" >> ${subject_log}

    if [[ ! -d ${regressionDir}/smooth ]]; then
      mkdir -p ${regressionDir}/smooth
    fi

    #Guassian smooth: mm to sigma
      #https://www.jiscmail.ac.uk/cgi-bin/webadmin?A2=FSL;d7249c17.1301
        #sigma=mm/sqrt(8*ln(2))=sigma*2.3548
    smoothSigma=`echo ${smoothSize} | awk '{print ($1/(sqrt(8*log(2))))}'`

    #Determine 50% intensity of data, thresholded at 75% (for all non-zero voxels)
    epiThreshVal=`$FSLDIR/bin/fslstats ${epi} -k ${epiMask} -P 50 | awk '{print ($1*0.75)}'`

    #SUSAN for smoothing
    $FSLDIR/bin/susan ${epi} ${epiThreshVal} ${smoothSigma} 3 1 0 ${regressionDir}/smooth/${epiBase}_s${smoothSize}

    epi=${regressionDir}/smooth/${epiBase}_s${smoothSize}

        #Log the task end time
      timeLog "e"
      sed -i "s/epiSmooth_TIMEEND/${timeStamp}/g" ${subject_log}
  fi

  ########################################

    ################
    #  epiStrip    #
    ################

        #Log the task start time, set placeholder for end time
      timeLog "s"
      echo "task:epiStrip,${timeStamp},epiStrip_TIMEEND" >> ${subject_log}

  if [[ ! -d ${regressionDir}/stripped ]]; then
    mkdir -p ${regressionDir}/stripped
  fi

  $FSLDIR/bin/fslmaths ${epi} -mas ${epiMask} ${regressionDir}/stripped/${epiBase}.nii.gz

  epiStripped=${regressionDir}/stripped/${epiBase}.nii.gz

        #Log the task end time
      timeLog "e"
      sed -i "s/epiStrip_TIMEEND/${timeStamp}/g" ${subject_log}

  ########################################

    ###############
    #  intNorm    #
    ###############

      #Log the task start time, set placeholder for end time
    timeLog "s"
    echo "task:intNorm,${timeStamp},intNorm_TIMEEND" >> ${subject_log}

  #Rescale data to mean value 10000
  if [[ ! -d ${regressionDir}/intNorm ]]; then
    mkdir -p ${regressionDir}/intNorm
  fi

  medianScale ${epiStripped} ${epiMask} ${regressionDir}/intNorm

      #Log the task end time
    timeLog "e"
    sed -i "s/intNorm_TIMEEND/${timeStamp}/g" ${subject_log}

  ########################################

    ####################
    #  tissuePrep      #
    ####################

  if [[ ${doCompCor} -eq 1 ]]; then

        #Log the task start time, set placeholder for end time
      timeLog "s"
      echo "task:tissuePrep,${timeStamp},tissuePrep_TIMEEND" >> ${subject_log}

    if [[ ! -d ${regressionDir}/tissue ]]; then
      mkdir -p ${regressionDir}/tissue
    fi

    #Push regressionCoreMask to EPI (avg) space
    $ANTSPATH/antsApplyTransforms -d 3 -i ${atlasDir}/regressionCoreMask/${atlasName}/regressionCoreMask.nii.gz \
    -r ${researcher}/${project}/derivatives/func/moco/moco_${atlasName}_native/avg/${epiBase}+motCorAvg.nii.gz \
    -o ${regressionDir}/tissue/regressionCoreMask.nii.gz \
    -t identity -n NearestNeighbor
    $FSLDIR/bin/fslmaths ${regressionDir}/tissue/regressionCoreMask.nii.gz -bin ${regressionDir}/tissue/regressionCoreMask.nii.gz -odt char

    #Invert the exclusion mask
    fslmaths ${regressionDir}/tissue/regressionCoreMask.nii.gz -mul -1 -add 1 -bin ${regressionDir}/tissue/regressionExclusionMask.nii.gz -odt char

    #Create binary WM, CSF tissue masks, threshold/remove basal and brainstem/pons regions
    for tissue in 'WM' 'CSF';
      do

      #Apply the regressionIgnore cost mask, epiMask
      $FSLDIR/bin/fslmaths ${tisDir}/${epiBase}_seg-${tissue}.nii.gz -thr 0.5 -bin \
      -mas ${regressionDir}/tissue/regressionExclusionMask.nii.gz -mas ${epiMask} \
      -bin ${regressionDir}/tissue/${epiBase}_seg-${tissue}.nii.gz -odt char

      #If WM, erode by 1 strip of voxels (analagous to Ciric/Power et. al)
      if [[ "${tissue}" == "WM" ]]; then
        $ANTSPATH/ImageMath 3 ${regressionDir}/tissue/${epiBase}_seg-WM.nii.gz ME ${regressionDir}/tissue/${epiBase}_seg-WM.nii.gz 1
      fi

      meanTS ${regressionDir}/intNorm/${epiBase}.nii.gz ${regressionDir}/tissue/${epiBase}_tmp${tissue}_ts.txt \
      ${regressionDir}/tissue/${epiBase}_seg-${tissue}.nii.gz 1

      #Reformat input to be space delimited (will be merged with quadratics, derivatives)
      cat ${regressionDir}/tissue/${epiBase}_tmp${tissue}_ts.txt \
      | sed s/"  "/" "/g > ${regressionDir}/tissue/${epiBase}_${tissue}.par

      rm ${regressionDir}/tissue/${epiBase}_tmp${tissue}_ts.txt
    done

        #Log the task end time
      timeLog "e"
      sed -i "s/tissuePrep_TIMEEND/${timeStamp}/g" ${subject_log}
  fi

  ########################################

    ####################
    #  globalSignal    #
    ####################

  if [[ ${doGlobalSignal} -eq 1 ]]; then

        #Log the task start time, set placeholder for end time
      timeLog "s"
      echo "task:globalSignal,${timeStamp},globalSignal_TIMEEND" >> ${subject_log}

    if [[ ! -d ${regressionDir}/global ]]; then
      mkdir -p ${regressionDir}/global
    fi

    #Calculate the TR to TR global signal
    meanTS ${regressionDir}/intNorm/${epiBase}.nii.gz ${regressionDir}/global/${epiBase}_global_ts.txt ${epiMask} 0

    #Reformat input to be space delimited (will be merged with quadratics, derivatives)
    cat ${regressionDir}/global/${epiBase}_global_ts.txt \
    | sed s/"  "/" "/g > ${regressionDir}/global/TMP.par
    mv ${regressionDir}/global/TMP.par ${regressionDir}/global/${epiBase}_global.par

    rm ${regressionDir}/global/${epiBase}_global_ts.txt

        #Log the task end time
      timeLog "e"
      sed -i "s/globalSignal_TIMEEND/${timeStamp}/g" ${subject_log}
  fi

  ########################################

    ####################
    #  spikeSetup      #
    ####################

  if [[ ${doSpikeRegression} -eq 1 ]]; then

        #Log the task start time, set placeholder for end time
      timeLog "s"
      echo "task:spikeSetup,${timeStamp},spikeSetup_TIMEEND" >> ${subject_log}

    if [[ ! -d ${regressionDir}/spikes ]]; then
      mkdir ${regressionDir}/spikes
    fi

    #Create movement regression spikes (rms motion TR difference > 0.25)
    spikeRegressionSetup ${epiPar} ${epiBase} ${regressionDir}/spikes

        #Log the task end time
      timeLog "e"
      sed -i "s/spikeSetup_TIMEEND/${timeStamp}/g" ${subject_log}
  fi

  ########################################

    ####################
    #  friston24       #
    ####################

  if [[ ${do36p} -eq 1 ]]; then

  #Make 4dfp style motion parameter and derivative regressors for timeseries (quadratic and derivatives)
    #Take the backwards temporal derivative in column $i of input $2 and output it as $3
    #Vectorized Matlab: d=[zeros(1,size(a,2));(a(2:end,:)-a(1:end-1,:))];
    #Bash version of above algorithm

        #Log the task start time, set placeholder for end time
      timeLog "s"
      echo "task:friston24_motPar,${timeStamp},friston24_TIMEEND" >> ${subject_log}

    if [[ ! -d ${regressionDir}/friston24 ]]; then
      mkdir -p ${regressionDir}/friston24
    fi

    #Reformat input to be space delimited (will be merged with quadratics, derivatives)
    cat ${epiPar} | sed s/"  "/" "/g > ${regressionDir}/friston24/${epiBase}_Friston24.par

    #Loop through the 6 motion parameters (mm)
    i=1
    while [[ ${i} -le 6 ]] ; do
      deriveBackwards ${i} ${epiPar} ${regressionDir}/friston24
      let i=i+1
    done

    #Push together the original file and subsequent derivatives/quadratics into one file
    paste -d " " ${regressionDir}/friston24/${epiBase}_Friston24.par ${regressionDir}/friston24/_tmp3 ${regressionDir}/friston24/_tmp1 \
    ${regressionDir}/friston24/_tmp2 > ${regressionDir}/friston24/${epiBase}_Friston24.par_
    mv ${regressionDir}/friston24/${epiBase}_Friston24.par_ ${regressionDir}/friston24/${epiBase}_Friston24.par

    #Clean up the last of the temporary files
    rm ${regressionDir}/friston24/_tmp*

    #The last of the formatting (6 decimal places, nice columns)
    cat ${regressionDir}/friston24/${epiBase}_Friston24.par | awk '{for(i=1;i<=NF;i++)printf("%10.6f ",$i);printf("\n")}' \
    > ${regressionDir}/friston24/${epiBase}_Friston24.par_
    mv ${regressionDir}/friston24/${epiBase}_Friston24.par_ ${regressionDir}/friston24/${epiBase}_Friston24.par

  else

    #Need to account for original motion parameters
    if [[ ! -d ${residualDir}/ts ]]; then
      mkdir -p ${residualDir}/ts
    fi
    
    cat ${epiPar} | sed s/"  "/" "/g > ${residualDir}/ts/motPar.par

        #Log the task end time
      timeLog "e"
      sed -i "s/friston24_TIMEEND/${timeStamp}/g" ${subject_log}
  fi

  ########################################

    ##################
    #  regressorTS   #
    ##################

      #Log the task start time, set placeholder for end time
    timeLog "s"
    echo "task:regressorTS,${timeStamp},regressorTS_TIMEEND" >> ${subject_log}

  if [[ ! -d ${residualDir}/ts ]]; then
    mkdir -p ${residualDir}/ts
  fi

  #36p (or regular motion correction
  if [[ ${do36p} -eq 1 ]]; then
    paste -d " " ${regressionDir}/friston24/${epiBase}_Friston24.par > ${residualDir}/ts/${epiBase}_regressors.1D
  else
    paste -d " " ${residualDir}/ts/motPar.par > ${residualDir}/ts/${epiBase}_regressors.1D
  fi

  #Global Signal Regression
  if [[ ${doGlobalSignal} -eq 1 ]]; then
    if [[ -e ${residualDir}/ts/${epiBase}_regressors.1D ]]; then
      paste -d " " ${residualDir}/ts/${epiBase}_regressors.1D ${regressionDir}/global/${epiBase}_global.par \
      > ${residualDir}/ts/${epiBase}_regressors.1D_
      mv ${residualDir}/ts/${epiBase}_regressors.1D_ ${residualDir}/ts/${epiBase}_regressors.1D
    else
      cp ${regressionDir}/global/${epiBase}_global.par ${residualDir}/ts/${epiBase}_regressors.1D
    fi
  fi

  #compCor/tissue
  if [[ ${doCompCor} -eq 1 ]]; then
    if [[ -e ${residualDir}/ts/${epiBase}_regressors.1D ]]; then
      paste -d " " ${residualDir}/ts/${epiBase}_regressors.1D \
      ${regressionDir}/tissue/${epiBase}_WM.par \
      ${regressionDir}/tissue/${epiBase}_CSF.par \
      > ${residualDir}/ts/${epiBase}_regressors.1D_
      mv ${residualDir}/ts/${epiBase}_regressors.1D_ ${residualDir}/ts/${epiBase}_regressors.1D
    else
      paste -d " " ${regressionDir}/tissue/${epiBase}_WM.par \
      ${regressionDir}/tissue/${epiBase}_CSF.par > ${residualDir}/ts/${epiBase}_regressors.1D
    fi
  fi

  #Spike Regression
  if [[ ${doSpikeRegression} -eq 1 ]]; then
    if [[ -e ${residualDir}/ts/${epiBase}_regressors.1D ]]; then
      paste -d " " ${residualDir}/ts/${epiBase}_regressors.1D ${regressionDir}/spikes/${epiBase}_spikes.1D \
      > ${residualDir}/ts/${epiBase}_regressors.1D_
      mv ${residualDir}/ts/${epiBase}_regressors.1D_ ${residualDir}/ts/${epiBase}_regressors.1D
    else
      cp ${regressionDir}/spikes/${epiBase}_spikes.1D ${residualDir}/ts/${epiBase}_regressors.1D
    fi
  fi

      #Log the task end time
    timeLog "e"
    sed -i "s/regressorTS_TIMEEND/${timeStamp}/g" ${subject_log}

  ########################################









#icaAROMA is not vetted

    ###############
    #  icaAROMA   #
    ###############

  if [[ ${doIcaAroma} -eq 1 ]]; then

      #Log the task start time, set placeholder for end time
    timeLog "s"
    echo "task:icaAROMA,${timeStamp},icaAROMA_TIMEEND" >> ${subject_log}

    #Push ICA-AROMA masks to epi space
    if [[ ! -d ${regressionDir}/ICAAROMA/masks/${epiBase} ]]; then
      mkdir -p ${regressionDir}/ICAAROMA/masks/${epiBase}
    fi

    for aromaMask in 'csf' 'edge' 'out';
      do

      $ANTSPATH/antsApplyTransforms -d 3 -i ${scriptDir}/ICA-AROMA-master/${atlasName}/mask_${aromaMask}.nii.gz \
      -r ${researcher}/${project}/derivatives/func/moco/moco_${atlasName}_native/avg/${epiBase}+motCorAvg.nii.gz \
      -o ${regressionDir}/ICAAROMA/masks/${epiBase}/mask_${aromaMask}.nii.gz \
      -t identity -n NearestNeighbor
      $FSLDIR/bin/fslmaths ${regressionDir}/ICAAROMA/masks/${epiBase}/mask_${aromaMask}.nii.gz -bin ${regressionDir}/ICAAROMA/masks/${epiBase}/mask_${aromaMask}.nii.gz -odt char
    done

    #ICA-AROMA
    if [[ ! -d ${regressionDir}/ICAAROMA/${epiBase} ]]; then
      mkdir -p ${regressionDir}/ICAAROMA/${epiBase}
    fi

    python ${scriptDir}/ICA-AROMA-master/ICA_AROMA.py -i ${regressionDir}/intNorm/${epiBase}.nii.gz \
    -o ${regressionDir}/ICAAROMA/${epiBase} -mc ${researcher}/${project}/derivatives/func/prep/sub-${subject}/ses-${session}/motionCorr/${epiBase}_mcImg_deg.par \
    -tr ${TR} -den nonaggr -maskDir ${regressionDir}/ICAAROMA/masks/${epiBase}

        #Log the task end time
      timeLog "e"
      sed -i "s/icaAROMA_TIMEEND/${timeStamp}/g" ${subject_log}
  fi

  ########################################

    ##################
    #  epiRegress    #
    ##################

      #Log the task start time, set placeholder for end time
    timeLog "s"
    echo "task:epiRegress,${timeStamp},epiRegress_TIMEEND" >> ${subject_log}

  if [[ ! -d ${regressionDir}/tmpResid ]]; then
    mkdir -p ${regressionDir}/tmpResid
  fi

  #Make sure to handle ICA-AROMA data differently
  if [[ ${doIcaAroma} -eq 1 ]]; then
    simultBandpassNuisanceReg ${regressionDir}/ICAAROMA/${epiBase}/denoised_func_data_nonaggr.nii.gz ${epiMask} ${residualDir}/ts/${epiBase}_regressors.1D ${TR}
  else
    simultBandpassNuisanceReg ${regressionDir}/intNorm/${epiBase}.nii.gz ${epiMask} ${residualDir}/ts/${epiBase}_regressors.1D ${TR}
  fi

      #Log the task end time
    timeLog "e"
    sed -i "s/epiRegress_TIMEEND/${timeStamp}/g" ${subject_log}

  ########################################

    ##################
    #  epiRescale    #
    ##################

      #Log the task start time, set placeholder for end time
    timeLog "s"
    echo "task:epiRescale,${timeStamp},epiRescale_TIMEEND" >> ${subject_log}

  if [[ ! -d ${residualDir}/resid_${atlasName}_native ]]; then
    mkdir -p ${residualDir}/resid_${atlasName}_native
  fi

  #Rescale data to be mean centered around value = 1000 (or alt (don't remove sd))
  if [[ ${doAltScale} -eq 1 ]]; then
    dataScale2 ${regressionDir}/tmpResid/${epiBase}_bp_res4d.nii.gz ${epiMask} ${residualDir}/resid_${atlasName}_native 1000
  else
    dataScale ${regressionDir}/tmpResid/${epiBase}_bp_res4d.nii.gz ${epiMask} ${residualDir}/resid_${atlasName}_native 1000
  fi
      #Log the task end time
    timeLog "e"
    sed -i "s/epiRescale_TIMEEND/${timeStamp}/g" ${subject_log}

  ########################################

    ###############
    #  epiScrub   #
    ###############

  if [[ ${doMotionScrub} -eq 1 ]]; then

        #Log the task start time, set placeholder for end time
      timeLog "s"
      echo "task:motionScrub,${timeStamp},motionScrub_TIMEEND" >> ${subject_log}

    if [[ ! -d ${residualDir}/resid_${atlasName}_native/motionScrub ]]; then
      mkdir -p ${residualDir}/resid_${atlasName}_native/motionScrub
    fi

    if [[ ! -d ${regressionDir}/tmpResid/motionScrub ]]; then
      mkdir -p ${regressionDir}/tmpResid/motionScrub
    fi

    #Check for uncompressed residual file for scrubbing
    if [[ ! -e ${regressionDir}/tmpResid/${epiBase}.nii ]]; then
      gunzip -c ${residualDir}/resid_${atlasName}_native/${epiBase}.nii.gz > ${regressionDir}/tmpResid/motionScrub/${epiBase}.nii
    fi

    #Motion scrub the residual file, given the motion parameters
    motionScrub ${regressionDir}/tmpResid/motionScrub/${epiBase}.nii ${epiPar}

        #Log the task end time
      timeLog "e"
      sed -i "s/motionScrub_TIMEEND/${timeStamp}/g" ${subject_log}

  fi

  ########################################

    #####################
    #  resampleToAtlas  #
    #####################

  if [[ ${doAtlasResample} -eq 1 ]]; then

        #Log the task start time, set placeholder for end time
      timeLog "s"
      echo "task:resampleToAtlas,${timeStamp},resampleToAtlas_TIMEEND" >> ${subject_log}

    if [[ ! -d ${residualDir}/resid_${atlasName}_${atlasSize} ]]; then
      mkdir -p ${residualDir}/resid_${atlasName}_${atlasSize}
      if [[ ${doMotionScrub} -eq 1 ]]; then
        if [[ ! -d ${residualDir}/resid_${atlasName}_${atlasSize}/motionScrub ]]; then
          mkdir -p ${residualDir}/resid_${atlasName}_${atlasSize}/motionScrub
        fi
      fi
    fi

    #Resample files to true atlas voxel/grid space
    atlasResample ${residualDir}/resid_${atlasName}_native/${epiBase}.nii.gz ${residualDir}/resid_${atlasName}_${atlasSize} ${atlasSize}
    
    if [[ ${doMotionScrub} -eq 1 ]]; then
      atlasResample ${residualDir}/resid_${atlasName}_native/motionScrub/${epiBase}_motionscrubbed.nii.gz ${residualDir}/resid_${atlasName}_${atlasSize}/motionScrub ${atlasSize}
    fi

        #Log the task end time
      timeLog "e"
      sed -i "s/resampleToAtlas_TIMEEND/${timeStamp}/g" ${subject_log}

  fi

  #################################

done

  #Log the task end time
timeLog "e"
sed -i "s/epiPrep2_TIMEEND/${timeStamp}/g" ${subject_log}

#########################################################################################################

#End logging
chgrp -R ${group} ${regressionDir} > /dev/null 2>&1
chmod -R g+rw ${regressionDir} > /dev/null 2>&1
chgrp -R ${group} ${residualDir} > /dev/null 2>&1
chmod -R g+rw ${residualDir} > /dev/null 2>&1
chgrp ${group} ${subject_log} > /dev/null 2>&1
chmod g+rw ${subject_log} > /dev/null 2>&1
date +"end:%Y-%m-%dT%H:%M:%S%z" >> ${subject_log}
echo "#--------------------------------------------------------------------------------" >> ${subject_log}
echo "" >> ${subject_log}

