# TO DO for version 0

## General
- add initialization file
    - version number
    - version date  
    - DIR_CODE  
    - DIR_TEMPLATE >>> _find a home for this with Steve_ 
    - software needed, with versions  
        - AFNI, latest
        - ANTs, latest
        - FSL, 6.0.1 multicore
            - on ARGON needs OpenBLAS module
        - R
        - Python, version? does 3dplotter work?
- remove all group, dir-code, dir-pincsource, dir-template inputs and references in help
    - replace with read from init file.
- remove deprecated functions entirely
- add model folder, for stistical modelling workflows
- probably should remove backticks and use $() instead... \`\` are deprecated

## anatomical workflow
- finish/start __map_hyperintensity.sh__
    - lets talk about the workflow within this
- deprecate older registration functions, replace with __coregistration.sh__
- fix/finish/debug __build_template.sh__ and __make_template.sh__
    - one of these needs to be deprecated
    - process needs debugging and updating to use coregistration.sh
- other stat map functions?
    - __map_myelin.sh__ could use a tweak in terms of potentially using a single divide function in ImageMath rather than the negative exponent and multiplication

## diffusion workflow
- clarification of what the tractography function does?
- need correlation matrix for output

## functional workflow
- functions to include
    - moco+reg.sh >> rename to __moco_reg.sh__ (probably better to abandon the +)
    - regressor functions
        - compcor-anatomy.sh >> rename to __regressor_compcorr-anat.sh__
        - compcor-temporal.sh >> rename to __regressor_compcorr-temp.sh__
        - new regressor functions, I want each function to do one thing
            - __regressor_frame-disp.sh__
            - __regressor_spike.sh__
            - __regressor_deriv.sh__
                - output should be ${PREFIX}_moco+6+deriv.1D  
                -bash:  
                `>> Rscript ${DIR_CODE}/func/regressor_deriv.sh ${INPUT_1D} ${DIR_SAVE}`  
                -R:  
                `R> args <- commandArgs(trailingOnly = TRUE)`  
                `R> library(tools)`
                `R> df <- read.csv(args[1], header=F)`  
                `R> df <- apply(df, 2, diff)`  
                `R> write.table(df, filename=paste0(args[2], basename(file_path_sans_ext(args[1])), quotes=F, row.names=F, col.names=F, sep=" "), ".1D")`  
            - __regressor_quad.sh__
                - output should be ${PREFIX}_moco+6+quad.1D
                - output should just keep appending, e.g., ${PREFIX}_moco+6+deriv+quad.1D
            - others?
    - __nuisance_regression.sh__, should be fine
    - __ts_deconvolve.sh__
        - can this be done simultaneously to nuisance_regression? or does that interfere with LSS?
        - with LSS and LSA options (LSS as default)
        - can we allow amplitude and duration modulation with stim_times_IM, LSS?
        - provide options for HRF, but default to canonical
        - alternatives for regression, is robust regression implemented? this may be a longer discussion and a longer term project (assuming people do tasks more frequently)
    - __roi_ts.sh__, should be fine
    - additional functions, not critical for version 0.0.0.0
        - __connectivity_mx.sh__
            - take output of roi_ts.sh and make a correlation matrix, (using R would be easy)
            - optional output variable, correlation coefficient (maybe option for cross order) or z-score

## modelling workflow
The idea for modelling workflows is to simplify statistical modelling for normal types of models.  
This would include:
    - wrapper functions for simple models (i.e., typical instances of lm, glm, lmer, glmer)
    - options for desired output
    - the idea for this is to generate job, sh, and R files as necessary for simple things
    - with minimal inputs, i.e., which brain data, which subject data, function, and formula
- __mx_to_df.sh__
    - convert matrix (upper triangle) to a row or column vector
    - option for row or column
    - allow multiple inputs (e.g., subjects) to be concatenated in output
    - option to include diagonal
- __model_3d.sh__ for modelling 3-dimensional volumetric data
- __model_4d.sh__ for modelling 4-dimensional volumetric data
- __model_surf.sh__ for modelling surface data, freesurfer surf/curv format to start, maybe move to cifti/gifti
- __model_roi.sh__ for modelling rois
- __model_rsa.sh__ for representational similarity analyses, e.g., on connectivity matrices
- __model_summary.sh__
    - postmodelling operations, including cluster thresholding and generation of images and tables
    - generic to handle output from any of the above modelling functions
    - output is an html report
    - might be better to break this down into subfunctions... like effect_cluster.sh, effect_plot.sh, effect_table.sh, etc. 
- move __combat_harmonization__ into here from generic... and finish writing, should handle 3D, 4D, and tsv/csv inputs
- move __power_proportion__ into here from generic, finish writing, should handle 3D, 4D, and tsv/csv inputs

## quality control
- needed functions:
    - image panels for initial qc of dicoms
    - 3d plane view with ROI overlay for brain mask, navigable html
    - 3d plane view with colored overlay
        - options to specify color bar
        - multiple overlays possible?
        - navigable?
        - easily exportable as publication ready figure?
    - time series gifs?
    - moco/1D plots
    - matrix heatmaps
    - publication ready images
- perhaps not premade, rather it would be nice if we can feed these to the website or email on the fly

## BIDS and Generic functions
- is there anything else that we pull from the bids structure that could use a function assist
- 
