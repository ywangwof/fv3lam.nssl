#!/bin/sh -l
#SBATCH -A hpc-wof1
#SBATCH -p vjet,kjet,xjet
#SBATCH -J make_ics_DDDHHH
#SBATCH --ntasks=48
#SBATCH --exclusive
#SBATCH -t 00:30:00
#SBATCH -o WWWDDD/tmp_ICS/out.make_ics_%j
#SBATCH -e WWWDDD/tmp_ICS/err.make_ics_%j

nprocs=48
APRUN="srun -n $nprocs"
exec_fp="EXEDDD/chgres_cube"

fix_lam="/lfs4/NAGAPE/hpc-wof1/ywang/regional_fv3/fv3lam.nssl/fix_lam_C3356"
fix_am="/lfs4/NAGAPE/hpc-wof1/ywang/regional_fv3/fv3lam.nssl/fix_am"
#
#-----------------------------------------------------------------------
#
# Working directory
#
#-----------------------------------------------------------------------
#

ics_dir="WWWDDD"
workdir="${ics_dir}/tmp_ICS"
if [[ ! -e $workdir ]]; then
    mkdir -p $workdir
fi
cd $workdir

rm -f ${ics_dir}/error.ics ${ics_dir}/queue.ics
touch ${ics_dir}/running.ics

EXTRN_MDL_CDATE="DATDDD"

fv3grib2_dir="HRRR_INPUT_DIR"
fv3grib2_head=$(date -d "${EXTRN_MDL_CDATE:0:8} ${EXTRN_MDL_CDATE:8:2}:00:00" +%y%j%H%M)
fv3grib2_file="${fv3grib2_head}0000"
#
#-----------------------------------------------------------------------
#
# Grid configuration parameters needed regardless of grid generation me-
# thod used.
#
#-----------------------------------------------------------------------
#
TILE_RGNL="7"
NH0="0"
NH3="3"
NH4="4"

#
#-----------------------------------------------------------------------
#
# Build the FORTRAN namelist file that chgres_cube will read in.
#
#-----------------------------------------------------------------------
#
# Create a multiline variable that consists of a yaml-compliant string
# specifying the values that the namelist variables need to be set to
# (one namelist variable per line, plus a header and footer).  Below,
# this variable will be passed to a python script that will create the
# namelist file.
#
cat >fort.41  <<EOF
&config
    convert_atm = .true.
    convert_nst = .false.
    convert_sfc = .true.
    cycle_day  = $((10#${EXTRN_MDL_CDATE:6:2}))
    cycle_hour = $((10#${EXTRN_MDL_CDATE:8:2}))
    cycle_mon  = $((10#${EXTRN_MDL_CDATE:4:2}))
    data_dir_input_grid = "${fv3grib2_dir}"
    external_model = 'HRRR'
    fix_dir_input_grid = '${fix_am}'
    fix_dir_target_grid = '${fix_lam}'
    geogrid_file_input_grid = '${fix_lam}/geo_em.d01.nc_HRRRX'
    grib2_file_input_grid = '${fv3grib2_file}'
    halo_blend = 20
    halo_bndy = 4
    input_type = 'grib2'
    lai_from_climo = .true.
    minmax_vgfrc_from_climo = .true.
    mosaic_file_target_grid = '${fix_lam}/C3356_mosaic.halo4.nc'
    nsoill_out = 9
    orog_dir_target_grid = '${fix_lam}'
    orog_files_target_grid = 'C3356_oro_data.tile7.halo4.nc'
    regional = 1
    sotyp_from_climo = .true.
    tg3_from_soil = .true.
    tracers = ''
    tracers_input = ''
    varmap_file = '${fix_lam}/GFSphys_var_map.txt'
    vcoord_file_target_grid = '${fix_lam}/global_hyblev_fcst_RRFSL65.txt'
    vgfrc_from_climo = .true.
    vgtyp_from_climo = .true.
/
EOF

# original GFS configurations
#
#    atm_files_input_grid="${fv3grib2_head}.gfs.t${EXTRN_MDL_CDATE:8:2}z.atmanl.nc"
#    sfc_files_input_grid="${fv3grib2_head}.gfs.t${EXTRN_MDL_CDATE:8:2}z.sfcanl.nc"
#    tracers="sphum","liq_wat","o3mr","ice_wat","rainwat","snowwat","graupel"
#    tracers_input="spfh","clwmr","o3mr","icmr","rwmr","snmr","grle"
#    halo_blend=20
#    thomp_mp_climo_file  = '${fix_lam}/Thompson_MP_MONTHLY_CLIMO.nc'
#    grib2_file_input_grid  = ''
#    nsoill_out  = 4
#    tg3_from_soil  = .false.
#
#-----------------------------------------------------------------------
#
# Run chgres_cube.
#
#-----------------------------------------------------------------------
#
ulimit -s unlimited

${APRUN} ${exec_fp}

#
#-----------------------------------------------------------------------
#
# Move initial condition, surface, control, and 0-th hour lateral bound-
# ary files to ICs_BCs directory.
#
#-----------------------------------------------------------------------
#
if [[ $? -eq 0 ]]; then
    mv out.atm.tile${TILE_RGNL}.nc  ${ics_dir}/gfs_data.tile${TILE_RGNL}.halo${NH0}.nc
    mv out.sfc.tile${TILE_RGNL}.nc  ${ics_dir}/sfc_data.tile${TILE_RGNL}.halo${NH0}.nc
    mv gfs_ctrl.nc                  ${ics_dir}
    mv gfs.bndy.nc                  ${ics_dir}/gfs_bndy.tile${TILE_RGNL}.000.nc

    touch ${ics_dir}/done.ics
else
    touch ${ics_dir}/error.ics
    echo "ERROR: $?"
fi

rm -f ${ics_dir}/running.ics
