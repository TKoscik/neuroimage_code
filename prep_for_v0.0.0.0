[ ] add initialization file
    [ ] version number
    [ ] version date
    [ ] DIR_CODE
    [ ] DIR_TEMPLATE {find a home for this with Steve}
    [ ] software needed, with versions
        [ ] AFNI, latest
        [ ] ANTs, latest
        [ ] FSL, 6.0.1 multicore
            [ ] on ARGON needs OpenBLAS module
        [ ] R
[ ] remove all group, dir-code, dir-pincsource, dir-template inputs and references in help
    [ ] replace with read from init file.
[ ] functional code
    [ ] functions to include
        [ ] moco+reg.sh >> rename to moco_reg.sh (probably better to abandon the +)
        [ ] regressor functions
            [ ] compcor-anatomy.sh >> rename to regressor_compcorr-anat.sh
            [ ] compcor-temporal.sh >> rename to regressor_compcorr-temp.sh
            [ ] new regressor functions, I want each function to do one thing
                [ ] regressor_frame-disp.sh
                [ ] regressor_spike.sh
                [ ] regressor_deriv.sh
                    [ ] output should be ${PREFIX}_moco+6+deriv.1D
                [ ] regressor_quad.sh
                    [ ] output should be ${PREFIX}_moco+6+quad.1D
                    [ ] output should just keep appending, e.g., ${PREFIX}_moco+6+deriv+quad.1D
                [ ] others?
        [ ] nuisance_regression.sh, should be fine
        [ ] ts_deconvolve.sh
            [ ] can this be done simultaneously to nuisance_regression? or does that interfere with LSS?
            [ ] with LSS and LSA options (LSS as default)
            [ ] can we allow amplitude and duration modulation with stim_times_IM, LSS?
            [ ] provide options for HRF, but default to canonical
            [ ] alternatives for regression, is robust regression implemented? this may be a longer discussion and a longer term project (assuming people do tasks more frequently)
        [ ] roi_ts.sh, should be fine
        [ ] additional functions, not critical for version
            [ ] 
