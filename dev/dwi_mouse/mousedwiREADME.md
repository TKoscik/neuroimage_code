# Running TBSS on mouse DWI data

This pipeline takes 140umX140umX300um DWI data and processes it using a basic pipeline build around TBSS from fsl
## Requirements

* FSL
* AFNI
* ANTS

## formatting overview

The pipeline assumes you have data organized in BIDS format as follows:
- rawdata
  - participants.tsv
  - sub-001
    - dti
      - sub-001_dti.nii.gz
      - nodif_brain_mask.nii.gz
      - bvecs
      - bvals
  - sub-002
    - dti
      - sub-002_dti.nii.gz
      - nodif_brain_mask.nii.gz
      - bvecs
      - bvals
  - sub-003
    - dti
      - sub-003_dti.nii.gz
      - nodif_brain_mask.nii.gz
      - bvecs
      - bvals
- derivatives
  - sub-001
    - all processed data files for sub-001, including FA
  - sub-002
  - sub-003

# the importance of the participants file

The participant file is what directs the processing scripts, so when the 000_run_dtifit.sh script runs it looks for any subjects defined in the participants file to process for analysis. When the 001_run_tbss.sh script runs it uses the participants.tsv file to decide which groups to assign subjects to, so can be useful for streamlining data pooling
