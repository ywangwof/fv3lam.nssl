# fv3lam.nssl
Run configurations for NSSL FV3LAM HWT runs in 2021

Users should copy the following direcotries for executables and fixed files

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

After clone the repository, users just change "rootdir" in run_fv3_Jet.sh
to the working repostiory directory.


Source packages in 2022:

* UPP    #82f3133 (2022-02-15) with local updates for processing NSSL MP products

* ufs-srweather-app (develop branch #91cefa5e by 2022-04-05)
    - regional_workflow  (wofs/feature_nssl)
    - src/ufs-weather-model (Ted/wofs_sdf, #92e317e7)
        - FV3 (#63582aa by 2022-04-05)
            - atmos_cubed_sphere (feature/HAILCAST, #018b480)
