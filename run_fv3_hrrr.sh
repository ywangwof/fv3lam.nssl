
#!/bin/bash
rootdir="/lfs4/NAGAPE/hpc-wof1/ywang/regional_fv3/fv3lam.nssl"
WORKDIRDF=$(realpath ${rootdir}/../run_dirs)
eventdateDF=$(date +%Y%m%d)

#export eventdate="20180214"

function usage {
    echo " "
    echo "    USAGE: $0 [options] DATETIME [WORKDIR]"
    echo " "
    echo "    PURPOSE: Run FV3/UPP on Jet."
    echo " "
    echo "    DATETIME - Case date and time in YYYYMMDD"
    echo "               empty for current day"
    echo "    WORKDIR  - Work Directory on Jet"
    echo " "
    echo "    OPTIONS:"
    echo "              -h              Display this message"
    echo "              -n              Show command to be run only"
    echo "              -v              Verbose mode"
    echo "              -r  emc/nssl    FV3 configuration"
    echo " "
    echo "   DEFAULTS:"
    echo "              eventdt = $eventdateDF"
    echo "              rootdir = $rootdir"
    echo "              WORKDIR = $WORKDIRDF"
    echo " "
    echo "                                     -- By Y. Wang (2022.04.28)"
    echo " "
    exit $1
}


export WORKDIR="$WORKDIRDF"
export eventdate="$eventdateDF"

#-----------------------------------------------------------------------
#
# Default values
#
#-----------------------------------------------------------------------

show=0
verb=0
run="nssl"
#-----------------------------------------------------------------------
#
# Handle command line arguments
#
#-----------------------------------------------------------------------

while [[ $# > 0 ]]
    do
    key="$1"

    case $key in
        -h)
            usage 0
            ;;
        -n)
            show=1
            ;;
        -v)
            verb=1
            ;;
        -r)
            run=$2
            shift
            ;;
        -*)
            echo "Unknown option: $key"
            exit
            ;;
        *)
            if [[ $key =~ ^[0-9]{8}$ ]]; then
                eventdate="$key"
            elif [[ -d $key ]]; then
                WORKDIR=$key
            else
                 echo ""
                 echo "ERROR: unknown option, get [$key]."
                 usage -2
            fi
            ;;
    esac
    shift # past argument or value
done

export WORKDIR="$WORKDIR/${run^^}"
export CYCLE="00"
#export FIX_AM="${rootdir}/fix/fix_am"

layout_x="35"
layout_y="28"
#quilt_procs="72"
quilt_nodes="2"
quilt_ppn="14"

#platppn="12"

npes=$((layout_x * layout_y + quilt_nodes*quilt_ppn))
#nodes1=$(( layout_x * layout_y/platppn ))
#nodes2=$(( quilt_nodes * quilt_ppn/platppn ))
#nodes=$(( nodes1 + nodes2 ))

echo "---- Jobs started at $(date +%m-%d_%H:%M:%S) for Event: $eventdate on host $(hostname) ----"
echo "     Working dir: $WORKDIR ----"
#usage

#-----------------------------------------------------------------------
#
# 0. Prepare working directories
#
#-----------------------------------------------------------------------

eventdir="${WORKDIR}/${eventdate}${CYCLE}_hrrr"
if [[ ! -r ${eventdir} ]]; then
  mkdir -p ${eventdir}
fi

cd ${eventdir}

template_dir="${rootdir}/run_templates_EMC"

intvhour=3
tophour=48
numhours=$(( tophour/intvhour ))
gridno="C3356"
npx=1721
npy=1025

out_nx="1701"
out_ny="1001"
out_lon1="-121.566577"
out_lat1="22.158393"

currsec=$(date +%s)
run_sec=$(date -d "$eventdate ${CYCLE}:00:00" +%s)

diffhour=$(( (currsec-run_sec)/3600 ))

##-----------------------------------------------------------------------
##
## 1. Prepare IC/BC datasets
##
##-----------------------------------------------------------------------

EXEDDD="$rootdir/exec"
fv3hrrr_dir="/public/data/grids/hrrr/conus/wrfnat/grib2"

ics_dir="${eventdir}/INPUT"
doneics="${ics_dir}/done.ics"
if [[ -f ${ics_dir}/done.ics || -f ${ics_dir}/queue.ics || -f ${ics_dir}/running.ics ]]; then
    :
else

    fv3ics_head=$(date -d "${eventdate} ${CYCLE}:00:00" +%y%j%H%M)
    expectedsize=670000000

    if [[ ! -e "${eventdir}/INPUT/tmp_ICS" ]]; then
        mkdir -p INPUT/tmp_ICS
    fi
    cd INPUT/tmp_ICS

    #
    # Wait for atmanl file
    #
    hrrrfile="$fv3hrrr_dir/${fv3ics_head}0000"
    echo "Waiting for $hrrrfile ...."
    while [[ ! -e $hrrrfile ]]; do
        sleep 10
    done

    hrrrsize=$(stat -c %s $(realpath $hrrrfile))
    while [[ $hrrrsize -lt $expectedsize ]]; do
        echo "Waiting for $hrrrfile ($hrrrsize) ...."
        sleep 10
        hrrrsize=$(stat -c %s $(realpath $hrrrfile))
    done

    #
    # Run make_ics
    #
    # NOTE: cannot run on sjet
    #
    if [[ $diffhour -lt 5 ]]; then
      sleep 20   # for safety while waiting for the file to be written
    fi

    jobscript=run_ics_$eventdate${CYCLE}.slurm
    cp ${template_dir}/make_ics_hrrr.slurm ${jobscript}
    sed -i -e "/WWWDDD/s#WWWDDD#$eventdir/INPUT#;s#EXEDDD#$EXEDDD#;s#DATDDD#${eventdate}${CYCLE}#g;s#DDDHHH#${eventdate:4:4}#g" ${jobscript}
    sed -i -e "/HRRR_INPUT_DIR/s#HRRR_INPUT_DIR#$fv3hrrr_dir#" ${jobscript}

    echo -n "sbatch $jobscript .... "
    sbatch $jobscript
    touch ${eventdir}/INPUT/queue.ics
fi

cd ${eventdir}

lbc_dir="${eventdir}/INPUT"
donelbcs="${lbc_dir}/done.lbcs"
if [[ ! -f $donelbcs ]]; then

    fv3lbcs_head=$(date -d "${eventdate} ${CYCLE}:00:00" +%y%j%H%M)
    expectedsize=700000000

    for (( i=intvhour; i<=tophour; i+=intvhour )); do

        cd $eventdir

        fhr3d=$(printf "%03d" "${i}" )
        fhr4d=$(printf "%04d" "${i}" )

        if [[ -f ${lbc_dir}/done.lbc_${fhr3d} || -f ${lbc_dir}/queue.lbc_${fhr3d} || -f ${lbc_dir}/running.lbc_${fhr3d} ]]; then
            :
        else
            hrrrfile="$fv3hrrr_dir/${fv3lbcs_head}${fhr4d}"

            echo "Waiting for $hrrrfile ...."
            while [[ ! -e $hrrrfile ]]; do
                sleep 10
            done

            hrrrsize=$(stat -c %s $(realpath $hrrrfile))
            while [[ $hrrrsize -lt $expectedsize ]]; do
                echo "Waiting for $hrrrfile ($hrrrsize) ...."
                sleep 10
                hrrrsize=$(stat -c %s $(realpath $hrrrfile))
            done

            if [[ $diffhour -lt 5 ]]; then
              sleep 20
            fi

            if [[ ! -e "${eventdir}/INPUT/tmp_LBCS_${fhr3d}" ]]; then
                mkdir -p INPUT/tmp_LBCS_${fhr3d}
            fi
            cd INPUT/tmp_LBCS_${fhr3d}

            jobscript=run_lbcs_$eventdate${CYCLE}_${fhr3d}.slurm
            cp ${template_dir}/make_lbcs_hrrr.slurm ${jobscript}
            sed -i -e "/WWWDDD/s#WWWDDD#$eventdir/INPUT#;s#EXEDDD#$EXEDDD#g;s#DATDDD#${eventdate}${CYCLE}#g;s#HHHNNN#${i}#g;s#DDDHHH#${fhr3d}#g" ${jobscript}
            sed -i -e "/HRRR_INPUT_DIR/s#HRRR_INPUT_DIR#$fv3hrrr_dir#" ${jobscript}

            echo -n "sbatch $jobscript .... "
            sbatch $jobscript
            touch ${lbc_dir}/queue.lbc_${fhr3d}
        fi
    done

fi

echo "$$: Checking: ${doneics} ..."
while [[ ! -f ${doneics} ]]; do
  sleep 10
  if [[ $verb -eq 1 ]]; then echo "Waiting for ${doneics} ..."; fi
done

echo "$$: Checking: ${donelbcs} ..."
donelbcs_size=$(ls -1 ${lbc_dir}/done.lbc_* 2>/dev/null | wc -l)
while [ ${donelbcs_size} -lt ${numhours} ]; do
  if [[ $verb -eq 1 ]]; then echo "Waiting for ${donelbcs}_* (found ${donelbcs_size}) ...."; fi
  sleep 10
  donelbcs_size=$(ls -1 ${lbc_dir}/done.lbc_* 2>/dev/null | wc -l)
done
rm -rf ${lbc_dir}/done.lbc_*
touch ${donelbcs}

##-----------------------------------------------------------------------
##
## 2. FV3 forecast directory
##
##-----------------------------------------------------------------------

cd ${eventdir}

donefv3="$eventdir/done.fv3"

if [[ -f $donefv3 || -f $eventdir/queue.fv3 || -f $eventdir/running.fv3 ]]; then
    :
else

  echo "-- 2: prepare working directory for FV3SAR at $(date +%m-%d_%H:%M:%S) ----"

  cd INPUT
  ln -sf gfs_data.tile7.halo0.nc gfs_data.nc
  ln -sf sfc_data.tile7.halo0.nc sfc_data.nc

  runfix_ldir="${rootdir}/fix_lam_${gridno}"
  ln -sf ${runfix_ldir}/${gridno}_grid.tile7.halo3.nc          ${gridno}_grid.tile7.halo3.nc
  #ln -s ${runfix_ldir}/${gridno}_grid.tile7.halo4.nc          ${gridno}_grid.tile7.halo4.nc
  #ln -s ${runfix_ldir}/${gridno}_grid.tile7.halo6.nc          ${gridno}_grid.tile7.halo6.nc
  #ln -s ${runfix_ldir}/${gridno}_grid.tile7.nc                ${gridno}_grid.tile7.nc
  ln -sf ${runfix_ldir}/${gridno}_grid.tile7.halo4.nc          grid.tile7.halo4.nc
  #ln -s ${runfix_ldir}/${gridno}_oro_data.tile7.halo0.nc      ${gridno}_oro_data.tile7.nc
  ln -sf ${runfix_ldir}/${gridno}_oro_data.tile7.halo0.nc      oro_data.nc
  ln -sf ${runfix_ldir}/${gridno}_oro_data.tile7.halo4.nc      oro_data.tile7.halo4.nc
  ln -sf ${runfix_ldir}/${gridno}_oro_data_ls.tile7.halo0.nc   oro_data_ls.nc
  ln -sf ${runfix_ldir}/${gridno}_oro_data_ss.tile7.halo0.nc   oro_data_ss.nc
  ln -sf ${runfix_ldir}/${gridno}_mosaic.halo3.nc              grid_spec.nc

  cd ..

  #ln -s ${runfix_ldir}/${gridno}.facsf.tile7.nc                 ${gridno}.facsf.tile1.nc
  #ln -s ${runfix_ldir}/${gridno}.snowfree_albedo.tile7.nc       ${gridno}.snowfree_albedo.tile1.nc
  #ln -s ${runfix_ldir}/${gridno}.substrate_temperature.tile7.nc ${gridno}.substrate_temperature.tile1.nc
  #ln -s ${runfix_ldir}/${gridno}.vegetation_greenness.tile7.nc  ${gridno}.vegetation_greenness.tile1.nc
  #ln -s ${runfix_ldir}/${gridno}.vegetation_type.tile7.nc       ${gridno}.vegetation_type.tile1.nc
  #ln -s ${runfix_ldir}/${gridno}.soil_type.tile7.nc             ${gridno}.soil_type.tile1.nc
  #ln -s ${runfix_ldir}/${gridno}.slope_type.tile7.nc            ${gridno}.slope_type.tile1.nc
  #ln -s ${runfix_ldir}/${gridno}.maximum_snow_albedo.tile7.nc   ${gridno}.maximum_snow_albedo.tile1.nc

  mkdir -p RESTART

  cp ${template_dir}/data_table  .
  cp ${template_dir}/field_table_${run^^}     field_table
  cp ${template_dir}/diag_table               diag_table
  cp ${template_dir}/input.nml_${run^^}       input.nml
  cp ${template_dir}/model_configure_${run^^} model_configure
  cp ${template_dir}/nems.configure .

  #if [[ ${run^^} =~ "EMC" ]]; then
  #  cp ${template_dir}/suite_FV3_GFS_v15_thompson_mynn_lam3km.xml .
  #elif [[ ${run^^} =~ "NSSL" ]]; then
  #  #cp ${template_dir}/suite_FV3_RRFS_v1nssl_lsmnoah.xml .
  #  cp ${template_dir}/suite_FV3_WoFS_v0ruc.xml .
  #else
  #    echo "ERROR: unsupport run mode."
  #    exit 1
  #fi

  runfix_dir="${rootdir}/fix_am"
  ln -sf ${runfix_dir}/fd_nems.yaml                      .
  for m in $(seq 1 12); do
    m2str=$(printf "%02d" $m)
    ln -sf ${runfix_dir}/fix_clim/merra2.aerclim.2003-2014.m${m2str}.nc aeroclim.m${m2str}.nc
  done
  ln -sf ${runfix_dir}/global_climaeropac_global.txt aerosol.dat

  for yr in $(seq 2010 2021); do
    ln -sf ${runfix_dir}/fix_co2_proj/global_co2historicaldata_${yr}.txt co2historicaldata_${yr}.txt
  done
  ln -sf ${runfix_dir}/global_co2historicaldata_glob.txt co2historicaldata_glob.txt
  ln -sf ${runfix_dir}/co2monthlycyc.txt                 .
  ln -sf ${runfix_dir}/global_albedo4.1x1.grb            .
  ln -sf ${runfix_dir}/global_h2o_pltc.f77               global_h2oprdlos.f77
  ln -sf ${runfix_dir}/ozprdlos_2015_new_sbuvO3_tclm15_nuchem.f77   global_o3prdlos.f77
  ln -sf ${runfix_dir}/global_tg3clim.2.6x1.5.grb        .
  ln -sf ${runfix_dir}/global_zorclim.1x1.grb            .

  ln -sf ${runfix_dir}/fix_clim/optics_BC.v1_3.dat       optics_BC.dat
  ln -sf ${runfix_dir}/fix_clim/optics_DU.v15_3.dat      optics_DU.dat
  ln -sf ${runfix_dir}/fix_clim/optics_OC.v1_3.dat       optics_OC.dat
  ln -sf ${runfix_dir}/fix_clim/optics_SS.v3_3.dat       optics_SS.dat
  ln -sf ${runfix_dir}/fix_clim/optics_SU.v1_3.dat       optics_SU.dat

  ln -sf ${runfix_dir}/global_sfc_emissivity_idx.txt            sfc_emissivity_idx.txt
  ln -sf ${runfix_dir}/global_solarconstant_noaa_an.txt         solarconstant_noaa_an.txt

  ymd=`echo ${eventdate} |cut -c 1-8`
  yyy=`echo ${eventdate} |cut -c 1-4`
  mmm=`echo ${eventdate} |cut -c 5-6`
  ddd=`echo ${eventdate} |cut -c 7-8`

  sed -i -e "/NPES/s/NPES/${npes}/;/YYYY/s/YYYY/$yyy/;/MM/s/MM/${mmm#0}/;/DD/s/DD/${ddd#0}/" model_configure
  sed -i -e "s/NODES2/${quilt_nodes}/;s/PPN2/${quilt_ppn}/;s/TTTTTT/${tophour}/"             model_configure
  sed -i -e "s/NOX/${out_nx}/;s/NOY/${out_ny}/;s/OLON1/${out_lon1}/;s/OLAT1/${out_lat1}/"    model_configure

  sed -i -e "/NPES/s/NPES/${npes}/;/YYYY/s/YYYY/$yyy/;/MM/s/MM/$mmm/;/DD/s/DD/$ddd/"         diag_table

  sed -i -e "/LAYOUT/s/LAYOUTX/${layout_x}/;s/LAYOUTY/${layout_y}/;s/BC_UPDATE/$intvhour/;"  input.nml
  sed -i -e "/FIX_AM/s#FIX_AM#${runfix_dir}#;s#FIX_LAM#${runfix_ldir}#"                      input.nml
  sed -i -e "s/GRIDNO/$gridno/g;/npx/s/NPX/$npx/;/npy/s/NPY/$npy/;"                          input.nml
fi

#-----------------------------------------------------------------------
#
# 3. run fv3 model
#
#-----------------------------------------------------------------------

echo "-- 3: run FV3SAR at $(date +%m-%d_%H:%M:%S) ----"

EXEPRO="$rootdir/exec/ufs_model"

if [[ -f $donefv3 || -f $eventdir/queue.fv3 || -f $eventdir/running.fv3 ]]; then
    :
else
  #echo "Waiting for ${chgresfile} ..."
  #while [[ ! -f ${chgresfile} ]]; do
  #  sleep 10
  #  #echo "Waiting for ${chgresfile} ..."
  #done
  #ls -l ${chgresfile}

  cd ${eventdir}

  jobscript=run_fv3sar_$eventdate${CYCLE}.slurm
  cp ${template_dir}/run_on_Jet_EMC.job ${jobscript}
  sed -i -e "/WWWDDD/s#WWWDDD#$eventdir#;s#EXEPPP#$EXEPRO#;s#NPES#${npes}#;s#MODE#${run}_hrrr#g" ${jobscript}
  #sed -i -e "/WWWDDD/s#WWWDDD#$eventdir#;s#EXEPPP#$EXEPRO#;s#NNNNNN#${nodes1}#;s#PPPPP1#${platppn}#g;s#MMMMMM#${nodes2}#;s#PPPPP2#${quilt_ppn}#g" ${jobscript}

  #module load slurm

  echo -n "sbatch $jobscript .... "
  sbatch $jobscript
  touch ${eventdir}/queue.fv3

  echo "Waiting for ${donefv3} ..."
  #while [[ ! -f ${donefv3} ]]; do
  #  sleep 10
  #  #echo "Waiting for ${donefv3} ..."
  #done
  #ls -l ${donefv3}
fi

echo " "

#-----------------------------------------------------------------------
#
# 4. post-processing
#
#-----------------------------------------------------------------------

echo "-- 4: run post-processing at $(date +%m-%d_%H:%M:%S) ----"

export FV3SARDIR="${rootdir}"
${FV3SARDIR}/run_post.sh ${eventdir} ${eventdate} 0 ${tophour} ${run^^}

echo " "

exit

#-----------------------------------------------------------------------
#
# 5. Transfer grib files
#
#-----------------------------------------------------------------------

#echo "-- 5: Transfer grib2 file to bigbang3 at $(date +%m-%d_%H:%M:%S) ----"
#
#donetransfer="$WORKDIR/C384_${eventdate}00_VLab/done.transfer"
#
#if [ ! -f $donetransfer ]; then
#
#  echo "Waiting for ${donepost} ..."
#  while [[ ! -f ${donepost} ]]; do
#    sleep 10
#    #echo "Waiting for ${donepost} ..."
#  done
#  ls -l ${donepost}
#
#  cd $WORKDIR/C384_${eventdate}00_VLab
#  echo "scp *.grb2 bigbang3:/raid/efp/se2018/ftp/nssl/fv3_test"
#  scp *.grb2 bigbang3:/raid/efp/se2018/ftp/nssl/fv3_test
#
#  touch $donetransfer
#fi
#
#echo " "

#-----------------------------------------------------------------------
#
# 6. Clean old runs
#
#-----------------------------------------------------------------------

#cleandate=$(date -d "2 days ago" +%Y%m%d )
#echo "-- 5: Clean run on ${cleandate} ----"
#
#cd $WORKDIR
#rm -r ${cleandate}.00Z_IC C384_${cleandate}00_VLab
#
#echo " "

echo "==== Jobs done at $(date +%m-%d_%H:%M:%S) ===="
echo " "
exit 0