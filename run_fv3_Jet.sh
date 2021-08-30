#!/bin/bash
rootdir="/lfs4/NAGAPE/hpc-wof1/ywang/regional_fv3"
WORKDIRDF="${rootdir}/run_dirs"
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
    echo "                                     -- By Y. Wang (2020.04.24)"
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

echo "---- Jobs started at $(date +%m-%d_%H:%M:%S) for Event: $eventdate"
echo "     Working dir: $WORKDIR ----"
#usage

##-----------------------------------------------------------------------
##
## 1. Download EMC IC/BC datasets
##
##-----------------------------------------------------------------------
#
#  inthour=3
#  tophour=60
#  echo "-- 1: download EMC data files at $(date +%m-%d_%H:%M:%S) ----"
#  emc_dir="${rootdir}/emcic"   #"/fv3sar.${eventdate}/00"
#
#  cd ${emc_dir}
#
#  emc_event="${emc_dir}/fv3lam.${eventdate}/${CYCLE}"
#  emcdone="donefile.${eventdate}${CYCLE}"
#
#  files=(gfs_ctrl.nc gfs_data.tile7.nc sfc_data.tile7.nc)
#  for hr in $(seq 0 ${inthour} ${tophour}); do
#    fhr=$(printf "%03d" $hr)
#    files+=(gfs_bndy.tile7.${fhr}.nc)
#  done
#  files+=(${emcdone})
#
#  #
#  # 1.1 Try public/data directory first
#  #
#  publicdatadir="/public/data/grids/ncep/fv3sar"
#
#  if [ ! -f ${emc_event}/${emcdone} ]; then
#
#    if [[ ! -d ${emc_event} ]]; then
#      mkdir -p ${emc_event}
#    fi
#
#    currjdate=$(date +%j)
#    curryyval=$(date +%g)
#
#    jdate=$(date -d "$eventdate" +%j)
#    yyval=$(date -d "$eventdate" +%g)
#
#    waitmaxseconds=7200   # wait for at most 1-hour
#    waitseconds=0;  found=0
#
#    readyfile="${publicdatadir}/${yyval}${jdate}0000.donefile.${eventdate}00"
#    while [[ $waitseconds -lt $waitmaxseconds ]]; do
#        if [[ -f $readyfile ]]; then
#            echo "Found $readyfile"
#            found=1
#            break
#        elif [[ $curryyval -eq $yyval && $currjdate -gt $((jdate+1)) ]]; then
#            break
#        else
#            echo "Waiting for $readyfile at ${eventdate} ... "
#            sleep 20
#            waitseconds=$(( waitseconds+=20 ))
#        fi
#    done
#
#    if [[ $found -gt 0 ]]; then
#      for fn in ${files[@]}; do
#        echo "Copying $fn ....."
#        cp -v ${publicdatadir}/${yyval}${jdate}0000.$fn ${emc_event}/$fn
#      done
#
#      #touch ${emc_event}/${emcdone}
#    fi
#  fi
#
#  #
#  # 1.2 Try the ftp server if not found in publicdatadir
#  #
#  #emcurl="ftp://ftp.emc.ncep.noaa.gov/mmb/mmbpll/fv3sar/fv3sar.${eventdate}/${CYCLE}"
#  emcurl="ftp://ftp.emc.ncep.noaa.gov/mmb/mmbpll/fv3lam/fv3lam.${eventdate}/${CYCLE}"
#
#  if [ ! -f ${emc_event}/${emcdone} ]; then
#
#    while true; do
#
#      wget -m -nH --cut-dirs=3 ${emcurl}/${emcdone}
#
#      if [[ $? -eq 0 ]]; then
#        break
#      else
#        #echo "Waiting for EMC datasets ..."
#        sleep 10
#      fi
#    done
#
#    for fn in ${files[@]}; do
#      echo "Downloading $fn ....."
#      wget -m -nH --cut-dirs=3 ${emcurl}/$fn > /dev/null 2>&1
#    done
#  fi
#
#echo " "

#-----------------------------------------------------------------------
#
# 0. Prepare working directories
#
#-----------------------------------------------------------------------

eventdir="${WORKDIR}/${eventdate}${CYCLE}"
if [[ ! -r ${eventdir} ]]; then
  mkdir -p ${eventdir}
fi

cd ${eventdir}

emc_dir="${rootdir}/emcic"   #"/fv3sar.${eventdate}/00"
template_dir="${rootdir}/fv3lam.nssl/run_templates_EMC"

intvhour=3
tophour=60
numhours=$(( tophour/intvhour ))


currsec=$(date +%s)
run_sec=$(date -d "$eventdate ${CYCLE}:00:00" +%s)

diffhour=$(( (currsec-run_set)/3600 ))

##-----------------------------------------------------------------------
##
## 1. Prepare IC/BC datasets
##
##-----------------------------------------------------------------------

EXEDDD="$rootdir/fv3lam.nssl/exec"

doneics="${eventdir}/INPUT/done.ics"
if [[ ! -f $doneics ]]; then

    fv3grib2_dir="/public/data/grids/gfs/anl/netcdf"
    fv3grib2_head=$(date -d "${eventdate} ${CYCLE}:00:00" +%y%j%H%M)
    expectedsize=13000000000

    if [[ ! -e "${eventdir}/INPUT/tmp_ICS" ]]; then
        mkdir -p INPUT/tmp_ICS
    fi
    cd INPUT/tmp_ICS

    #
    # Wait for atmanl file
    #
    gfsfile="$fv3grib2_dir/${fv3grib2_head}.gfs.t${CYCLE}z.atmanl.nc"
    echo "Waiting for $gfsfile ...."
    while [[ ! -e $gfsfile ]]; do
        sleep 10
    done

    gfssize=$(stat -c %s $(realpath $gfsfile))
    while [[ $gfssize -lt $expectedsize ]]; do
        echo "Waiting for $gfsfile ($gfssize) ...."
        sleep 10
        gfssize=$(stat -c %s $(realpath $gfsfile))
    done

    #
    # Wait for sfcanl file
    #
    sfcfile="$fv3grib2_dir/${fv3grib2_head}.gfs.t${CYCLE}z.sfcanl.nc"
    expectedsize=340000000

    echo "Waiting for $sfcfile ...."
    while [[ ! -e $sfcfile ]]; do
        sleep 10
    done

    sfcsize=$(stat -c %s $(realpath $sfcfile))
    while [[ $sfcsize -lt $expectedsize ]]; do
        echo "Waiting for $sfcfile ($sfcsize) ...."
        sleep 10
        sfcsize=$(stat -c %s $(realpath $sfcfile))
    done

    #
    # Run make_ics
    #
    # NOTE: cannot run on sjet
    #
    if [[ $diffhour -lt 2 ]]; then
      sleep 20
    fi

    jobscript=run_ics_$eventdate${CYCLE}.slurm
    cp ${template_dir}/make_ics.slurm ${jobscript}
    sed -i -e "/WWWDDD/s#WWWDDD#$eventdir/INPUT#;s#EXEDDD#$EXEDDD#;s#DATDDD#${eventdate}${CYCLE}#g;s#DDDHHH#${eventdate:4:4}#g" ${jobscript}

    echo "sbatch $jobscript"
    sbatch $jobscript
fi

cd ${eventdir}

donelbcs="${eventdir}/INPUT/done.lbcs"
if [[ ! -f $donelbcs ]]; then

    fv3grib2_dir="/public/data/grids/gfs/0p25deg/grib2"
    fv3grib2_head=$(date -d "${eventdate} ${CYCLE}:00:00" +%y%j%H)
    expectedsize=700000000

    for (( i=intvhour; i<=tophour; i+=intvhour )); do

        cd $eventdir

        fhr2d=$(printf "%02d" "${i}" )
        fhr3d=$(printf "%03d" "${i}" )

        gfsfile="$fv3grib2_dir/${fv3grib2_head}0000${fhr2d}"

        echo "Waiting for $gfsfile ...."
        while [[ ! -e $gfsfile ]]; do
            sleep 10
        done

        gfssize=$(stat -c %s $(realpath $gfsfile))
        while [[ $gfssize -lt $expectedsize ]]; do
            echo "Waiting for $gfsfile ($gfssize) ...."
            sleep 10
            gfssize=$(stat -c %s $(realpath $gfsfile))
        done

        if [[ $diffhour -lt 2 ]]; then
          sleep 20
        fi

        if [[ ! -e "${eventdir}/INPUT/tmp_LBCS_${fhr3d}" ]]; then
            mkdir -p INPUT/tmp_LBCS_${fhr3d}
        fi
        cd INPUT/tmp_LBCS_${fhr3d}

        jobscript=run_lbcs_$eventdate${CYCLE}_${fhr3d}.slurm
        cp ${template_dir}/make_lbcs.slurm ${jobscript}
        sed -i -e "/WWWDDD/s#WWWDDD#$eventdir/INPUT#;s#EXEDDD#$EXEDDD#g;s#DATDDD#${eventdate}${CYCLE}#g;s#HHHNNN#${i}#g;s#DDDHHH#${fhr3d}#g" ${jobscript}

        echo "sbatch $jobscript"
        sbatch $jobscript
    done

fi

echo "Waiting for ${doneics} ..."
while [[ ! -f ${doneics} ]]; do
  sleep 10
  #echo "Waiting for ${doneics} ..."
done
ls -l ${doneics}

donelbcs_size=$(ls -1 ${eventdir}/INPUT/done.lbcs_* 2>/dev/null | wc -l)
while [ ${donelbcs_size} -lt ${numhours} ]; do
  echo "Waiting for ${donelbcs}_* (found ${donelbcs_size}) ...."
  sleep 10
done
touch ${donelbcs}


##-----------------------------------------------------------------------
##
## 2. FV3 forecast directory
##
##-----------------------------------------------------------------------

cd ${eventdir}

donefv3="$eventdir/done.fv3"

if [ ! -f $donefv3 ]; then

  echo "-- 2: prepare working directory for FV3SAR at $(date +%m-%d_%H:%M:%S) ----"

  cd INPUT
  ln -s gfs_data.tile7.halo0.nc gfs_data.nc
  ln -s sfc_data.tile7.halo0.nc sfc_data.nc

  ln -s ${emc_dir}/fv3lam_esg.grid.2021/C3359_grid.tile7.halo3.nc     C3359_grid.tile7.halo3.nc
  ln -s ${emc_dir}/fv3lam_esg.grid.2021/C3359_grid.tile7.halo4.nc     C3359_grid.tile7.halo4.nc
  ln -s ${emc_dir}/fv3lam_esg.grid.2021/C3359_grid.tile7.halo6.nc     C3359_grid.tile7.halo6.nc
  ln -s ${emc_dir}/fv3lam_esg.grid.2021/C3359_grid.tile7.nc           C3359_grid.tile7.nc
  ln -s ${emc_dir}/fv3lam_esg.grid.2021/C3359_grid.tile7.halo4.nc     grid.tile7.halo4.nc
  ln -s ${emc_dir}/fv3lam_esg.grid.2021/C3359_oro_data.tile7.halo0.nc C3359_oro_data.tile7.nc
  ln -s ${emc_dir}/fv3lam_esg.grid.2021/C3359_oro_data.tile7.halo0.nc oro_data.nc
  ln -s ${emc_dir}/fv3lam_esg.grid.2021/C3359_oro_data.tile7.halo4.nc oro_data.tile7.halo4.nc
  ln -s ${emc_dir}/fv3lam_esg.grid.2021/C3359_mosaic.nc               grid_spec.nc

  cd ..

  ln -s ${emc_dir}/fv3lam_esg.grid.2021/C3359.facsf.tile7.nc                 C3359.facsf.tile1.nc
  ln -s ${emc_dir}/fv3lam_esg.grid.2021/C3359.snowfree_albedo.tile7.nc       C3359.snowfree_albedo.tile1.nc
  ln -s ${emc_dir}/fv3lam_esg.grid.2021/C3359.substrate_temperature.tile7.nc C3359.substrate_temperature.tile1.nc
  ln -s ${emc_dir}/fv3lam_esg.grid.2021/C3359.vegetation_greenness.tile7.nc  C3359.vegetation_greenness.tile1.nc
  ln -s ${emc_dir}/fv3lam_esg.grid.2021/C3359.vegetation_type.tile7.nc       C3359.vegetation_type.tile1.nc
  ln -s ${emc_dir}/fv3lam_esg.grid.2021/C3359.soil_type.tile7.nc             C3359.soil_type.tile1.nc
  ln -s ${emc_dir}/fv3lam_esg.grid.2021/C3359.slope_type.tile7.nc            C3359.slope_type.tile1.nc
  ln -s ${emc_dir}/fv3lam_esg.grid.2021/C3359.maximum_snow_albedo.tile7.nc   C3359.maximum_snow_albedo.tile1.nc

  mkdir -p RESTART

  cp ${template_dir}/data_table  .
  cp ${template_dir}/field_table_${run^^}     field_table
  cp ${template_dir}/diag_table               diag_table
  cp ${template_dir}/input.nml_${run^^}       input.nml
  cp ${template_dir}/model_configure_${run^^} model_configure
  cp ${template_dir}/nems.configure .
  if [[ ${run^^} =~ "EMC" ]]; then
  cp ${template_dir}/suite_FV3_GFS_v15_thompson_mynn_lam3km.xml .
  elif [[ ${run^^} =~ "NSSL" ]]; then
      cp ${template_dir}/suite_FV3_RRFS_v1nssl_lsmnoah.xml .
  else
      echo "ERROR: unsupport run mode."
      exit 1
  fi

  runfix_dir="${rootdir}/fv3lam.nssl/run_fix"
  #ln -s ${runfix_dir}/global_o3prdlos.f77 .
  #ln -s ${runfix_dir}/global_h2oprdlos.f77 .
  ln -s ${runfix_dir}/aerosol.dat .
  ln -s ${runfix_dir}/solarconstant_noaa_an.txt .
  ln -s ${runfix_dir}/CFSR.SEAICE.1982.2012.monthly.clim.grb .
  ln -s ${runfix_dir}/RTGSST.1982.2012.monthly.clim.grb .
  ln -s ${runfix_dir}/seaice_newland.grb .
  ln -s ${runfix_dir}/sfc_emissivity_idx.txt .
  ln -s ${runfix_dir}/co2* .
  ln -s ${runfix_dir}/global_* .
  rm global_o3prdlos.f77
  ln -s ${runfix_dir}/ozprdlos_2015_new_sbuvO3_tclm15_nuchem.f77 global_o3prdlos.f77
  rm global_soilmgldas.t126.384.190.grb
  ln -s ${runfix_dir}/CCN_ACTIVATE.BIN .


  ymd=`echo ${eventdate} |cut -c 1-8`
  yyy=`echo ${eventdate} |cut -c 1-4`
  mmm=`echo ${eventdate} |cut -c 5-6`
  ddd=`echo ${eventdate} |cut -c 7-8`

  sed -i -e "/NPES/s/NPES/${npes}/;/YYYY/s/YYYY/$yyy/;/MM/s/MM/$mmm/;/DD/s/DD/$ddd/" model_configure
  sed -i -e "s/NODES2/${quilt_nodes}/;s/PPN2/${quilt_ppn}/;s/TTTTTT/${tophour}/" model_configure
  sed -i -e "/NPES/s/NPES/${npes}/;/YYYY/s/YYYY/$yyy/;/MM/s/MM/$mmm/;/DD/s/DD/$ddd/" diag_table

  sed -i -e "/LAYOUT/s/LAYOUTX/${layout_x}/;s/LAYOUTY/${layout_y}/" input.nml
  sed -i -e "/FIX_AM/s#FIX_AM#${runfix_dir}#"   input.nml
fi

#-----------------------------------------------------------------------
#
# 3. run fv3 model
#
#-----------------------------------------------------------------------

echo "-- 3: run FV3SAR at $(date +%m-%d_%H:%M:%S) ----"

EXEPRO="$rootdir/fv3lam.nssl/exec/ufs_model"

if [ ! -f $donefv3 ]; then
  #echo "Waiting for ${chgresfile} ..."
  #while [[ ! -f ${chgresfile} ]]; do
  #  sleep 10
  #  #echo "Waiting for ${chgresfile} ..."
  #done
  #ls -l ${chgresfile}

  cd ${eventdir}

  jobscript=run_fv3sar_$eventdate${CYCLE}.slurm
  cp ${template_dir}/run_on_Jet_EMC.job ${jobscript}
  sed -i -e "/WWWDDD/s#WWWDDD#$eventdir#;s#EXEPPP#$EXEPRO#;s#NPES#${npes}#;s#MODE#${run}#g" ${jobscript}
  #sed -i -e "/WWWDDD/s#WWWDDD#$eventdir#;s#EXEPPP#$EXEPRO#;s#NNNNNN#${nodes1}#;s#PPPPP1#${platppn}#g;s#MMMMMM#${nodes2}#;s#PPPPP2#${quilt_ppn}#g" ${jobscript}

  #module load slurm

  echo "sbatch $jobscript"
  sbatch $jobscript

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

export FV3SARDIR="${rootdir}/fv3lam.nssl"
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
