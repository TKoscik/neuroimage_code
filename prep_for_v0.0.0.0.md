# TO DO for version 0.0.0.0
## Updated: 2020-11-16

## General
- add initialization file  
    - ~~version number~~  
    - version date  
    - ~~DIR_CODE ==> DIR_INC~~  
    - ~~DIR_TEMPLATE >>> _find a home for this with Steve_~~ 
    - ~~software needed, with versions~~  
        - ~~AFNI, latest~~
        - ~~ANTs, latest~~
        - ~~FSL, 6.0.1 multicore~~
            - ~~on ARGON needs OpenBLAS module~~
        - ~~R~~
        - ~~Python, version?~~ does 3dplotter work?
- ~~remove all group, dir-code, dir-pincsource, dir-template inputs and references in help~~
    - setup with source script using init file.
- ~~remove deprecated functions entirely~~
- add model folder, for statistical modelling workflows
- ~~probably should remove backticks and use $() instead... \`\` are deprecated~~
- ~~naming convention for functions, lowercase and underscores~~
- ~~no IS_SES as an input variable into functions~~  
- is it possible to make the egress function a separate function and have trap execute it? so that we can get rid of the egress function for everything?  
- ~~Update to file paths, important for default paths, should have one more layer to derivatives structure, to specify the pipeline:~~  
```
dir_project/
   └──derivatives/
      ├──baw/
      ├──freesurfer/
      └──inc/
         ├──anat/
         ├──dwi/
         └──func/
```

## anatomical workflow
- ~~finish/start __map_hyperintensity.sh__~~, SAMSEG  
- ~~deprecate older registration functions, replace with __coregistration.sh__~~  
- fix/finish/debug __make_template.sh__  
    - process needs debugging and updating to use coregistration.sh
- other stat map functions?
    - ~~__map_myelin.sh__~~  

## diffusion workflow
- clarification of what the tractography function does?
- need correlation matrix for output

## functional workflow
- functions to include
    - ~~moco+reg.sh >> rename to __moco_reg.sh__ (probably better to abandon the +)~~  
    - regressor functions
        - ~~compcor-anatomy.sh >> rename to __regressor_acompcorr.sh__~~
        - ~~compcor-temporal.sh >> rename to __regressor_tcompcorr.sh__~~
        - new regressor functions, I want each function to do one thing
            - __regressor_frame-disp.sh__
            - __regressor_spike.sh__
            - ~~__regressor_deriv.sh__~~  
            - ~~__regressor_quad.sh__~~  
            - others?
    - ~~__nuisance_regression.sh__, should be fine~~  
    - __ts_deconvolve.sh__
        - can this be done simultaneously to nuisance_regression? or does that interfere with LSS?
        - with LSS and LSA options (LSS as default)
        - can we allow amplitude and duration modulation with stim_times_IM, LSS?
        - provide options for HRF, but default to canonical
        - alternatives for regression, is robust regression implemented? this may be a longer discussion and a longer term project (assuming people do tasks more frequently)
    - ~~__roi_ts.sh__, should be fine~~  
    - __connectivity_mx.sh__
        - take output of roi_ts.sh and make a correlation matrix, (using R would be easy)
        - optional output variable, correlation coefficient (maybe option for cross order) or z-score






