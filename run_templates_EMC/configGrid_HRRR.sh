MACHINE="Jet"
ACCOUNT="hpc-wof1"

EXPT_BASEDIR="/mnt/lfs4/NAGAPE/hpc-wof1/ywang/comFV3LAM/testv2.0/expt_dirs"
EXPT_SUBDIR="GRID_wofs_conus"

POST_OUTPUT_DOMAIN_NAME="wofs_conus"

VERBOSE="TRUE"

RUN_ENVIR="community"
PREEXISTING_DIR_METHOD="delete"

GRID_GEN_METHOD="ESGgrid"
QUILTING="TRUE"
CCPP_PHYS_SUITE="FV3_RRFS_v1alpha"
FCST_LEN_HRS="6"
LBC_SPEC_INTVL_HRS="1"

DATE_FIRST_CYCL="20210824"
DATE_LAST_CYCL="20210824"
CYCL_HRS=( "00" )

EXTRN_MDL_NAME_ICS="HRRR"
EXTRN_MDL_NAME_LBCS="HRRR"

FV3GFS_FILE_FMT_ICS="grib2"
FV3GFS_FILE_FMT_LBCS="grib2"

WTIME_RUN_FCST="03:00:00"
WTIME_RUN_POST="01:00:00"

NNODES_MAKE_ICS="2"
NNODES_MAKE_LBCS="2"
PPN_MAKE_ICS="12"
PPN_MAKE_LBCS="12"
PPN_MAKE_GRID="12"
PPN_MAKE_OROG="12"
PPN_MAKE_SFC_CLIMO="12"

ESGgrid_LON_CTR="-97.5"
ESGgrid_LAT_CTR="38.5"
ESGgrid_DELX="3000.0"
ESGgrid_DELY="3000.0"
ESGgrid_NX="1720"
ESGgrid_NY="1024"
ESGgrid_WIDE_HALO_WIDTH="6"

DT_ATMOS="24"
LAYOUT_X="28"
LAYOUT_Y="28"
BLOCKSIZE="29"

QUILTING="TRUE"
PRINT_ESMF="FALSE"

WRTCMP_write_groups="1"
WRTCMP_write_tasks_per_group="28"

WRTCMP_output_grid="lambert_conformal"
WRTCMP_cen_lon="-97.5"
WRTCMP_cen_lat="38.5"
WRTCMP_lon_lwr_left="-122.719258"
WRTCMP_lat_lwr_left="21.138123"
#
# The following are used only for the case of WRTCMP_output_grid set to
# "'lambert_conformal'".
#
WRTCMP_stdlat1="38.5"
WRTCMP_stdlat2="38.5"
WRTCMP_nx="1799"
WRTCMP_ny="1059"
WRTCMP_dx="3000"
WRTCMP_dy="3000"
#
#
# Uncomment the following line in order to use user-staged external model
# files with locations and names as specified by EXTRN_MDL_SOURCE_BASEDIR_ICS/
# LBCS and EXTRN_MDL_FILES_ICS/LBCS.
#
USE_USER_STAGED_EXTRN_FILES="TRUE"
#
# The following is specifically for Hera.  It will have to be modified
# if on another platform, using other dates, other external models, etc.
#
EXTRN_MDL_SOURCE_BASEDIR_ICS="/public/data/grids/hrrr/conus/wrfnat/grib2"
EXTRN_MDL_FILES_ICS=( "2227800000000" )
EXTRN_MDL_SOURCE_BASEDIR_LBCS="/public/data/grids/hrrr/conus/wrfnat/grib2"
EXTRN_MDL_FILES_LBCS=( "2227800000001" "2227800000001" "2227800000002" "2227800000003" "2227800000004" "2227800000005" "2227800000006")
