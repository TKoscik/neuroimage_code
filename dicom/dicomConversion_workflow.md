# DICOM Conversion Workflow
## Iowa Neuroimage Processing Core
Author: Timothy R. Koscik
Date: 2021-06-25

*****

### Code Base:
```bash
source /shared/inc_scratch/dev_code/inc_source.sh
```

### Necessary Directories and Files
*setup when code base is sourced*
```bash
INC_DB=/Dedicated/inc_database
INC_IMPORT=${INC_DB}/import
INC_QC=${INC_DB}/qc

${INC_DB}/projects.tsv
```
#### ${INC_DB}/projects.tsv
| xnat_operator | xnat_project | pi | project_name | project_directory | irb_approval               |
|---------------|--------------|----|--------------|-------------------|----------------------------|
| HAWKID        | XNAT_PROJECT | PI | PROJECT      | DIR_PROJECT       | HAWKID1,HAWKID2,...HAWKIDN |



### Workflow
1. DICOM files added to IMPORT FOLDER  
    - file format: `${INC_IMPORT}/pi-${PI}_project-${PROJECT}_sub-${PID}_${YYMMDDHHMMSS}.zip`  
    - Automated download from XNAT using ${INC_DB}/projects.tsv, CRON job runs at midnight nightly  
    - Manual transfer, e.g., files uploaded via GLOBUS
2. Convert DICOM files to NIfTI-1  
    - create folder in QC directory, move zipped DICOMs
    - unzip DICOM folder, keep zipped
    - convert and generate BIDS-json files
    - generate PNG files from DICOMs and NIFTIs for each image
```
${INC_QC}/
  └──dicom_conversion/
     └──pi-${PI}_project-${PROJECT}_sub-${PID}_${YYMMDDHHMMSS}
        ├──sub-${PID}_ses-${YYMMDDHHMMSS}_ACQ.json
        ├──sub-${PID}_ses-${YYMMDDHHMMSS}_ACQ.png
        ├──sub-${PID}_ses-${YYMMDDHHMMSS}_ACQ.nii.gz
        .
        .
        .
        └──sub-${PID}_ses-${YYMMDDHHMMSS}.zip #zipped DICOM files
```
3. [MANUAL] Verify file information and conversion, dicomQC. QC data is autosaved to appropriate log files  
    - PI  
    - PROJECT  
    - participant identifier, PID  
    - session identifier, SID  
    - file destinations  
    - verify scan modalities  
    - verify/modify filename flags and values  
    - evaluate acquisition quality, rating 0=good, 1=marginal, 2=poor, 3=needs review 
    - confirm orientation  
#### INC LOG
`${INC_DB}/qc/qc_FYYYYYQq.tsv`
`${DIR_PROJECT}/rawdata/sub-${PID}/ses-${SID}/session.tsv`

| pi | project | file_dir | file_name | action           | status | qc | comment | operator | proc_start  | proc_end |
|----|---------|----------|-----------|------------------|--------|----|---------|----------|-------------|----------|
|    |         |          |           | dicom_conversion |        |    |         |          |             |          |


4. Move to proper destinations, append info to participants.tsv
```
${DIR_PROJECT}/
   ├──participants.tsv
   ├──rawdata/
   |  └──sub-${PID}
   |     └──ses-${SID}
   |        ├──session.tsv
   |        ├──anat/
   |        ├──dwi/
   |        ├──fmap/
   |        └──func/
   └──sourcedata/
      └──sub-${SID}_ses-${SID}_DICOM.zip
```

