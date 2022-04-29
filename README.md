# fv3lam.nssl
Run configurations for NSSL FV3LAM HWT runs in 2022

## Users should copy the following direcotries for executables and fixed files

* exec/
  - ufs_model
  - chgres_cube
  - upp.x
  - hireswfv3_bufr.x
  - hireswfv3_sndp.x
  - hireswfv3_stnmlist.x

* CRTM_v2.2.3_fix/
* fix_am/
* fix_lam/
* UPP_fix/

## Instructions

After clone the repository, users just
    1. Change "rootdir" in run_fv3_Jet.sh to your clone directory
    2. Change "WORKDIRDF" to your fv3 runtime direcotry or specify as command
       line option.
    3. Run (preprocessing, UFS forecast and post-processing) for any event date as
        $> run_fv3_Jet.sh YYYYMMDD [workdir] or
        $> run_fv3_Jet.sh                    Default of event date is current UTC date
                                             and work directory is "WORKDIRDF"


## Notes

Source packages used in 2022 (users do NOT need to copy these packages)

* UPP    #82f3133 (2022-02-15) with local updates for processing NSSL MP products

* ufs-srweather-app (develop branch #91cefa5e by 2022-04-05)
    - regional_workflow  (wofs/feature_nssl)
    - src/ufs-weather-model (Ted/wofs_sdf, #92e317e7)
        - FV3 (#63582aa by 2022-04-05)
            - atmos_cubed_sphere (feature/HAILCAST, #018b480)
