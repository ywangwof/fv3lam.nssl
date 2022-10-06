#!/bin/sh -l
#SBATCH -A hpc-wof1
#SBATCH -p sjet,vjet,kjet,xjet
#SBATCH -J make_lbcs_DDDHHH
#SBATCH --ntasks=48
#SBATCH --exclusive
#SBATCH -t 00:30:00
#SBATCH -o WWWDDD/tmp_LBCS_DDDHHH/out.makelbcs_DDDHHH_%j
#SBATCH -e WWWDDD/tmp_LBCS_DDDHHH/err.makelbcs_DDDHHH_%j

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
curhr=HHHNNN

lbcs_dir="WWWDDD"
workdir="${lbcs_dir}/tmp_LBCS_DDDHHH"
if [[ ! -e $workdir ]]; then
    mkdir -p $workdir
fi
cd $workdir

fhr3=$(printf "%03d" ${curhr})

rm -f ${lbcs_dir}/error.lbc_${fhr3} ${lbcs_dir}/queue.lbc_${fhr3}
touch ${lbcs_dir}/running.lbc_${fhr3}

ulimit -s unlimited

EXTRN_MDL_CDATE="DATDDD"
#
#-----------------------------------------------------------------------
#
# Run chgres_cube.
#
#-----------------------------------------------------------------------
#

fv3grib2_dir="HRRR_INPUT_DIR"
fv3grib2_head=$(date -d "${EXTRN_MDL_CDATE:0:8} ${EXTRN_MDL_CDATE:8:2}:00:00" +%y%j%H%M)

#for (( i=${intvlhr}; i<=${numhrs}; i+=${intvlhr} )); do
#
# Get the forecast hour of the external model.
#
  fhr=$(printf "%04d" ${curhr})
#
# Set external model output file name and file type/format.  Note that
# these are now inputs into chgres_cube.
#
  fn_atm=""
  fv3grib2_file="${fv3grib2_head}${fhr}"
#
# Get the starting date (year, month, and day together), month, day, and
# hour of the the external model forecast.  Then add the forecast hour
# to it to get a date and time corresponding to the current forecast time.
#
  yyyymmdd="${EXTRN_MDL_CDATE:0:8}"
  mm="${EXTRN_MDL_CDATE:4:2}"
  dd="${EXTRN_MDL_CDATE:6:2}"
  hh="${EXTRN_MDL_CDATE:8:2}"

  cdate_crnt_fhr=$( date --utc --date "${yyyymmdd} ${hh} UTC + ${curhr} hours" "+%Y%m%d%H" )
#
# Get the month, day, and hour corresponding to the current forecast time
# of the the external model.
#
  mm="${cdate_crnt_fhr:4:2}"
  dd="${cdate_crnt_fhr:6:2}"
  hh="${cdate_crnt_fhr:8:2}"
#
# Build the FORTRAN namelist file that chgres_cube will read in.
#
  cat >fort.41  <<EOF
&config
    convert_atm = .true.
    cycle_day   = $((10#${dd}))
    cycle_hour  = $((10#$hh))
    cycle_mon   = $((10#${mm}))
    data_dir_input_grid = '${fv3grib2_dir}'
    external_model = 'HRRR'
    fix_dir_input_grid = '${fix_am}'
    fix_dir_target_grid = '${fix_lam}'
    grib2_file_input_grid = '${fv3grib2_file}'
    halo_blend = 10
    halo_bndy = 4
    input_type = 'grib2'
    mosaic_file_target_grid = '${fix_lam}/C3356_mosaic.halo4.nc'
    orog_dir_target_grid = '${fix_lam}'
    orog_files_target_grid = 'C3356_oro_data.tile7.halo4.nc'
    regional = 2
    tracers = ''
    tracers_input = ''
    varmap_file = '${fix_lam}/GFSphys_var_map.txt'
    vcoord_file_target_grid = '${fix_lam}/global_hyblev_fcst_RRFSL65.txt'
/
EOF
#    halo_blend = 20

#
#-----------------------------------------------------------------------
#
# Run chgres_cube.
#
#-----------------------------------------------------------------------
#
# NOTE:
# Often when the chgres_cube.exe run fails, it still returns a zero re-
# turn code, so the failure isn't picked up the the logical OR (||) be-
# low.  That should be fixed.  This might be due to the APRUN command -
# maybe that is returning a zero exit code even though the exit code
# of chgres_cube is nonzero.
# A similar thing happens in the forecast task.
#
  ${APRUN} ${exec_fp}
#
# Move LBCs file for the current lateral boundary update time to the LBCs
# work directory.  Note that we rename the file by including in its name
# the forecast hour of the FV3-LAM (which is not necessarily the same as
# that of the external model since their start times may be offset).
#
  if [[ $? -eq 0 ]]; then
    fcst_hhh_FV3LAM=$( printf "%03d" "${curhr}" )
    mv gfs.bndy.nc ${lbcs_dir}/gfs_bndy.tile7.${fcst_hhh_FV3LAM}.nc

    touch ${lbcs_dir}/done.lbc_${fcst_hhh_FV3LAM}
  else
    touch ${lbcs_dir}/error.lbc_${fcst_hhh_FV3LAM}
  fi

rm -f ${lbcs_dir}/running.lbc_${fcst_hhh_FV3LAM}
#done
