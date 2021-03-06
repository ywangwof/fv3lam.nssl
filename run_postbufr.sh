#!/bin/bash

FV3SARDIR=${FV3SARDIR-$(pwd)}  #"/lfs3/projects/hpc-wof1/ywang/regional_fv3/fv3sar.mine"

RUNDIR=$1      # $eventdir
CDATE=$2
sfhr=${3-0}
tophour=${4-60}
MODE=${5-EMC}

#hr=${CDATE:8:2}
#CDATE=${CDATE:0:8}

nodes1="3"
numprocess="72"
platppn=$((numprocess/nodes1))

POSTPRD_DIR="$RUNDIR/postbufr"
mkdir -p $POSTPRD_DIR

cd $POSTPRD_DIR
if [[ ! -f hiresw_profdat ]]; then
    cp ${FV3SARDIR}/fix_am/hiresw_conusfv3_profdat hiresw_profdat
fi

jobtmpl=${FV3SARDIR}/run_templates_EMC/exhiresw_bufr000.job
declare -a waitlist
for hr in $(seq $sfhr 1 ${tophour}); do
  fhr=$(printf "%03d" $hr)

  logfile=$RUNDIR/logf${fhr}
  wtime=0
  while [[ ! -f ${logfile} ]]; do
    sleep 20
    wtime=$(( wtime += 10 ))
    echo "Waiting ($wtime seconds) for ${logfile}"
  done

  FHR_DIR="${POSTPRD_DIR}/$fhr"
  if [[ ! -r ${FHR_DIR} ]]; then
    mkdir -p ${FHR_DIR}
  fi

  cd ${FHR_DIR}

  jobscript=${FHR_DIR}/exhiresw_bufr${fhr}.job

  sed -e "s#WWWDDD#$FHR_DIR#;s#MMMMMM#$MODE#;s#NNNNNN#${nodes1}#;s#PPPPPP#${platppn}#g;s#EEEEEE#${FV3SARDIR}#;s#DDDDDD#${CDATE}#;s#HHHHHH#${hr}#;s#HHHTOP#${tophour}#;" ${jobtmpl} > ${jobscript}

  echo "Submitting $jobscript ..."
  sbatch $jobscript
  waitlist+=($fhr)
done

POSTBUFR_DIR="$RUNDIR/postbufr"
cd $POSTBUFR_DIR
hr=$((tophour+1))
nlevs=65
bufrtmpl=${FV3SARDIR}/run_templates_EMC/exhiresw_bufr061.job
jobscript=$POSTBUFR_DIR/exhiresw_bufr0${hr}.job
sed -e "s#WWWDDD#${POSTBUFR_DIR}#;s#MMMMMM#$MODE#;s#EEEEEE#${FV3SARDIR}#;s#DDDDDD#${CDATE}#;s#HHHHHH#${hr}#;s#HHHTOP#${tophour}#;s#NNNLEV#${nlevs}#;" ${bufrtmpl} > ${jobscript}

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

echo "Submitting $jobscript ..."
sbatch $jobscript

exit 0

