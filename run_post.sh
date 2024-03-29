#!/bin/bash -l

FV3SARDIR=${FV3SARDIR-$(pwd)}  #"/lfs3/projects/hpc-wof1/ywang/regional_fv3/fv3sar.mine"

#-----------------------------------------------------------------------
#
# This script runs the post-processor (UPP) on the NetCDF output files
# of the write component of the FV3SAR model.
#
#-----------------------------------------------------------------------
#
UPPFIX="${FV3SARDIR}/UPP_fix"
#UPPEXE="${FV3SARDIR}/exec"
CRTM_FIX="${FV3SARDIR}/CRTM_v2.2.3_fix"
ENDIAN="Big_Endian"

hostname=$(hostname)
case $hostname in
  odin?)
    template_job="${FV3SARDIR}/run_templates_EMC/run_upp_on_Odin.job"
    ;;
  fe*)
    template_job="${FV3SARDIR}/run_templates_EMC/run_upp_on_Jet.job"
    ;;
  *)
    echo "Unsupported machine: $hostname."
    exit
    ;;
esac

#
#-----------------------------------------------------------------------
#
# Save current shell options (in a global array).  Then set new options
# for this script/function.
#
#-----------------------------------------------------------------------
#
RUNDIR=$1      # $eventdir
CDATE=$2

sfhr=${3-0}
tophour=${4-60}
MODE=${5-EMC}

do_bufr=1
if [[ $MODE == "NSSL_hrrr" ]]; then do_bufr=0; fi

nodes1="2"
numprocess="12"
numthread="4"
platppn=$((numprocess/nodes1))
#npes="24"

#
# Configuration for Bufr
#
nodesb="3"
numprocess="72"
platppnb=$((numprocess/nodesb))

POSTBUFR_DIR="$RUNDIR/postbufr"
if [[ ! -r ${POSTBUFR_DIR} ]]; then
  mkdir -p ${POSTBUFR_DIR}
fi

if [[ ! -f  $POSTBUFR_DIR/hiresw_profdat ]]; then
    cp ${FV3SARDIR}/fix_am/hiresw_conusfv3_profdat $POSTBUFR_DIR/hiresw_profdat
fi
bufrtmpl=${FV3SARDIR}/run_templates_EMC/exhiresw_bufr000.job

#-----------------------------------------------------------------------
#
# Create directory (POSTPRD_DIR) in which to store post-processing out-
# put.  Also, create a temporary work directory (FHR_DIR) for the cur-
# rent output hour being processed.  FHR_DIR will be deleted later be-
# low after the processing for the current hour is complete.
#
#-----------------------------------------------------------------------
POSTPRD_DIR="$RUNDIR/postprd"

declare -a waitlist
for hr in $(seq $sfhr 1 ${tophour}); do
    fhr=$(printf "%03d" $hr)

    if [[ -f ${POSTPRD_DIR}/done.upp_$fhr || -f ${POSTPRD_DIR}/queue.upp_$fhr || -f ${POSTPRD_DIR}/running.upp_$fhr ]]; then
        :
    else
        dyn_file=${RUNDIR}/dynf${fhr}.nc
        phy_file=${RUNDIR}/phyf${fhr}.nc

        log_file=${RUNDIR}/logf${fhr}

        wtime=0
        while [[ ! -f ${log_file} ]]; do
          sleep 20
          wtime=$(( wtime += 20 ))
          echo "Waiting ($wtime seconds) for ${log_file}"
        done
        #while [[ ! -f ${dyn_file} ]]; do
        #  sleep 20
        #  wtime=$(( wtime += 20 ))
        #  echo "Waiting ($wtime seconds) for ${dyn_file}"
        #done
        #
        #while [[ ! -f ${phy_file} ]]; do
        #  sleep 10
        #  wtime=$(( wtime += 10 ))
        #  echo "Waiting ($wtime seconds) for ${phy_file}"
        #done

        FHR_DIR="${POSTPRD_DIR}/$fhr"
        if [[ ! -r ${FHR_DIR} ]]; then
          mkdir -p ${FHR_DIR}
        fi

        cd ${FHR_DIR}


#-----------------------------------------------------------------------
#
# Create text file containing arguments to the post-processing executa-
# ble.
#
#-----------------------------------------------------------------------


        POST_TIME=$( date -d "${CDATE} $hr hours" +%Y%m%d%H%M )
        post_yyyy=${POST_TIME:0:4}
        post_mm=${POST_TIME:4:2}
        post_dd=${POST_TIME:6:2}
        post_hh=${POST_TIME:8:2}

        cat > itag <<EOF
&model_inputs
    fileName='${dyn_file}'
    IOFORM='netcdf'
    grib='grib2'
    DateStr='${post_yyyy}-${post_mm}-${post_dd}_${post_hh}:00:00'
    MODELNAME='FV3R'
    fileNameFlux='${phy_file}'
/

&NAMPGB
    KPO=6,PO=1000.,925.,850.,700.,500.,250.,
/
EOF

        rm -f fort.*

#-----------------------------------------------------------------------
#
# Stage files.
#
#-----------------------------------------------------------------------

        ln -sf $UPPFIX/nam_micro_lookup.dat ./eta_micro_lookup.dat
        #ln -sf $UPPFIX/postxconfig-NT-fv3sar-hwt2019.txt ./postxconfig-NT.txt
        ln -sf $UPPFIX/postxconfig-NT-fv3lam_2022.txt ./postxconfig-NT.txt
        ln -sf $UPPFIX/params_grib2_tbl_2022 ./params_grib2_tbl_new
        ln -sf $UPPFIX/testbed_fields_bgdawp.txt ./testbed_fields_bgdawp.txt

#-----------------------------------------------------------------------
#
# CRTM fix files
#
#-----------------------------------------------------------------------

        spcCoeff_files=(imgr_g15.SpcCoeff.bin imgr_g13.SpcCoeff.bin imgr_g12.SpcCoeff.bin imgr_g11.SpcCoeff.bin \
          amsre_aqua.SpcCoeff.bin tmi_trmm.SpcCoeff.bin \
          ssmi_f13.SpcCoeff.bin ssmi_f14.SpcCoeff.bin ssmi_f15.SpcCoeff.bin ssmis_f16.SpcCoeff.bin \
          ssmis_f17.SpcCoeff.bin ssmis_f18.SpcCoeff.bin ssmis_f19.SpcCoeff.bin ssmis_f20.SpcCoeff.bin \
          seviri_m10.SpcCoeff.bin imgr_mt2.SpcCoeff.bin imgr_mt1r.SpcCoeff.bin \
          imgr_insat3d.SpcCoeff.bin abi_gr.SpcCoeff.bin ahi_himawari8.SpcCoeff.bin)

        for fn in ${spcCoeff_files[@]}; do
          ln -sf ${CRTM_FIX}/SpcCoeff/${ENDIAN}/$fn .
        done

        tauCoeff_files=(imgr_g15.TauCoeff.bin imgr_g13.TauCoeff.bin imgr_g12.TauCoeff.bin imgr_g11.TauCoeff.bin \
            amsre_aqua.TauCoeff.bin tmi_trmm.TauCoeff.bin \
            ssmi_f13.TauCoeff.bin ssmi_f14.TauCoeff.bin ssmi_f15.TauCoeff.bin ssmis_f16.TauCoeff.bin \
            ssmis_f17.TauCoeff.bin ssmis_f18.TauCoeff.bin ssmis_f19.TauCoeff.bin ssmis_f20.TauCoeff.bin \
            seviri_m10.TauCoeff.bin imgr_mt2.TauCoeff.bin imgr_mt1r.TauCoeff.bin \
            imgr_insat3d.TauCoeff.bin abi_gr.TauCoeff.bin ahi_himawari8.TauCoeff.bin)

        for fn in ${tauCoeff_files[@]}; do
          ln -sf ${CRTM_FIX}/TauCoeff/ODPS/${ENDIAN}/$fn .
        done

        cloudAndAerosol_files=(CloudCoeff/${ENDIAN}/CloudCoeff.bin AerosolCoeff/${ENDIAN}/AerosolCoeff.bin \
             EmisCoeff/IR_Land/SEcategory/${ENDIAN}/NPOESS.IRland.EmisCoeff.bin \
             EmisCoeff/IR_Snow/SEcategory/${ENDIAN}/NPOESS.IRsnow.EmisCoeff.bin \
             EmisCoeff/IR_Ice/SEcategory/${ENDIAN}/NPOESS.IRice.EmisCoeff.bin \
             EmisCoeff/IR_Water/${ENDIAN}/Nalli.IRwater.EmisCoeff.bin \
             EmisCoeff/MW_Water/${ENDIAN}/FASTEM6.MWwater.EmisCoeff.bin )

        for fn in ${cloudAndAerosol_files[@]}; do
          ln -sf ${CRTM_FIX}/$fn .
        done

#-----------------------------------------------------------------------
#
# Run the post-processor and move output files from FHR_DIR to POSTPRD_-
# DIR.
#
#-----------------------------------------------------------------------
        jobscript=run_upp_$fhr.job
        cp ${template_job} ${jobscript}
        sed -i -e "s#WWWDDD#${FHR_DIR}#;s#MMMMMM#$MODE#g;s#NNNNNN#${nodes1}#;s#PPPPPP#${platppn}#g;s#TTTTTT#${numthread}#g;s#EEEEEE#${FV3SARDIR}#;s#DDDDDD#${CDATE}#;s#HHHHHH#${hr}#;" ${jobscript}

        echo -n "Submitting $jobscript ... "
        sbatch $jobscript
        touch ${POSTPRD_DIR}/queue.upp_$fhr

    fi
#-----------------------------------------------------------------------
#
# Run postbufr
#
#-----------------------------------------------------------------------

    if [[ $do_bufr -eq 1 ]]; then
        if [[ -f ${POSTBUFR_DIR}/done.postbufr_$fhr || -f ${POSTBUFR_DIR}/queue.postbufr_$fhr || -f ${POSTBUFR_DIR}/running.postbufr_$fhr ]]; then
            :
        else

            FHR_DIR="${POSTBUFR_DIR}/$fhr"
            if [[ ! -r ${FHR_DIR} ]]; then
              mkdir -p ${FHR_DIR}
            fi

            cd ${FHR_DIR}

            jobscript=${FHR_DIR}/exhiresw_bufr${fhr}.job

            sed -e "s#WWWDDD#$FHR_DIR#;s#MMMMMM#$MODE#g;s#NNNNNN#${nodesb}#;s#PPPPPP#${platppnb}#g;s#EEEEEE#${FV3SARDIR}#;s#DDDDDD#${CDATE}#;s#HHHHHH#${hr}#;s#HHHTOP#${tophour}#;" ${bufrtmpl} > ${jobscript}

            echo -n "Submitting $jobscript ..."
            sbatch $jobscript
            touch ${POSTBUFR_DIR}/queue.postbufr_$fhr
        fi
    fi
    waitlist+=($fhr)
done

if [[ $do_bufr -eq 1 ]]; then
    cd $POSTBUFR_DIR
    hr=$((tophour+1))
    nlevs=65
    bufrtmpl=${FV3SARDIR}/run_templates_EMC/exhiresw_bufr061.job
    jobscript=$POSTBUFR_DIR/exhiresw_bufr0${hr}.job
    sed -e "s#WWWDDD#${POSTBUFR_DIR}#;s#MMMMMM#$MODE#g;s#EEEEEE#${FV3SARDIR}#;s#DDDDDD#${CDATE}#;s#HHHHHH#${hr}#;s#HHHTOP#${tophour}#;s#NNNLEV#${nlevs}#;" ${bufrtmpl} > ${jobscript}

    fhr=$(printf "%03d" $hr)
    if [[ -f ${POSTBUFR_DIR}/done.postbufr_$fhr || -f ${POSTBUFR_DIR}/queue.postbufr_$fhr || -f ${POSTBUFR_DIR}/running.postbufr_$fhr ]]; then
        :
    else
        wtime=0
        nowait=${#waitlist[@]}
        while true; do
            for fhr in ${waitlist[@]}; do
                donefile=$POSTBUFR_DIR/sndpostdone${fhr}.tm00

                if [[ -e $donefile ]]; then
                    waitlist=("${waitlist[@]/$fhr}")
                    nowait=$((nowait-1))
                else
                    echo "Waiting ($wtime seconds) for ${donefile}"
                fi
            done
            if [[ ${nowait} -eq 0 ]]; then
                break
            fi
            sleep 20
            wtime=$(( wtime += 20 ))
        done

        #echo "tophour=$tophour"
        #fhr=$(printf "%03d" $tophour)
        #donefile=$POSTBUFR_DIR/sndpostdone${fhr}.tm00
        #wtime=0
        #while [[ ! -f ${donefile} ]]; do
        #  sleep 20
        #  wtime=$(( wtime += 10 ))
        #  echo "Waiting ($wtime seconds) for ${donefile}"
        #done

        echo -n "Submitting $jobscript ..."
        sbatch $jobscript
        touch $POSTBUFR_DIR/queue.postbufr_$fhr
    fi
fi

exit 0