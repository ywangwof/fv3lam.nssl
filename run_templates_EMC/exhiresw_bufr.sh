#!/bin/ksh
#SBATCH -A hpc-wof1
#SBATCH --partition=xjet
#SBATCH -J bufr_00-60
#SBATCH --nodes=NNNNNN --ntasks-per-node=PPPPPP
#SBATCH --exclusive
#SBATCH -t 20:20:00
#SBATCH -o WWWDDD/fv3sar_bufr_%j.out
#SBATCH -e WWWDDD/fv3sar_bufr_%j.err

time1=$(date '+%s')
echo "Job Started: $(date). Job Id:  $SLURM_JOBID"
echo " "

######################################################################
####  UNIX Script Documentation Block
#                      .                                             .
# Script name:         exhireswfv3_bufr.sh
# Script description:  Trigger sounding post job
#
# Author:        Eric Rogers       Org: NP22         Date: 1999-06-23
#
# Abstract: This script triggers the sounding post job, which
#           creates a piece of the model sounding profile whose
#           time interval is determined by the input forecast hours.
#
# Script history log:
# 2000-05-16  Eric Rogers
# 2006-01-20  Eric Rogers -- extended to 84-h and modified for WRF-NMM NAM
# 2009-12-18  Matthew Pyle -- shortened to 48-h and generalized for multiple domains
#                             and diferent dynamical cores
# 2019-10-28  Matthew Pyle -- Converted for FV3 SAR and 60 hours
#

dom="conus"

DATA=WWWDDD
FIXsar=EEEEEE/fix_am
cyc=HHHHHH
INPUT_DATA=$(dirname $DATA)

FHRLIM=60

STARTDATE=$(date -d "DDDDDD $cyc:00" +%Y-%m-%d_%H:%M:%S)
FINALDATE=$(date -d "DDDDDD $cyc:00 $FHRLIM hours" +%Y-%m-%d_%H:%M:%S)

#set -x

NEST=${dom}
MODEL=fv3

#mkdir -p $DATA/postbufr
cd $DATA

RUNLOC=${NEST}${MODEL}

numprocess=$((PPPPPP*NNNNNN))
APRUN="srun -n $numprocess"
EXECfv3="EEEEEE/exec"
PARMfv3="EEEEEE/run_templates_EMC"
COMOUT="${DATA}"

export tmmark=tm00

echo FIXsar is $FIXsar
echo profdat file name is hiresw_${RUNLOC}_profdat


cp $FIXsar/hiresw_${RUNLOC}_profdat hiresw_profdat

OUTTYP=netcdf

model=FV3S

INCR=01
FHRLIM=60

let NFILE=1

#YYYY=`echo $PDY | cut -c1-4`
#MM=`echo $PDY | cut -c5-6`
#DD=`echo $PDY | cut -c7-8`
#CYCLE=$PDY$cyc
#
#startd=$YYYY$MM$DD
#startdate=$CYCLE
#
##endtime=`$NDATE $FHRLIM $CYCLE`
#
#STARTDATE=${YYYY}-${MM}-${DD}_${cyc}:00:00
#
#YYYY=`echo $endtime | cut -c1-4`
#MM=`echo $endtime | cut -c5-6`
#DD=`echo $endtime | cut -c7-8`
#
#FINALDATE=${YYYY}-${MM}-${DD}_${cyc}:00:00

# check for existence of sndpostdone files

#cd $DATA

if [ -e sndpostdone00.tm00 ]
then

lasthour=`ls -1rt sndpostdone??.tm00 | tail -1 | cut -c 12-13`
typeset -Z2 lasthour

let "fhr=lasthour+1"
typeset -Z2 fhr

else

fhr=00

fi

echo starting with fhr $fhr

#cd $DATA/postbufr

########################################################

while [ $fhr -le $FHRLIM ]
do

fhrstr=$(printf "%03d" $fhr)

datadir=${DATA}/${fhrstr}
mkdir -p $datadir

cd $datadir

#date=`$NDATE $fhr $CYCLE`

let fhrold="$fhr - 1"

if [ $model == "FV3S" ]
then

OUTFILDYN=$INPUT_DATA/dynf0${fhr}.nc
OUTFILPHYS=$INPUT_DATA/phyf0${fhr}.nc

icnt=1

# wait for model restart file
while [ $icnt -lt 1000 ]
do
   if [ -s $INPUT_DATA/logf0${fhr} ]
   then
      break
   else
      icnt=$((icnt + 1))
      sleep 9
   fi
if [ $icnt -ge 200 ]
then
    msg="FATAL ERROR: ABORTING after 30 minutes of waiting for FV3S ${RUNLOC} FCST F${fhr} to end."
    err_exit $msg
fi
done



else
  msg="FATAL ERROR: ABORTING due to bad model selection for this script"
  err_exit $msg
fi

datestr=`date`
echo top of loop after found needed log file for $fhr at $datestr

cat > itag <<EOF
$OUTFILDYN
$OUTFILPHYS
$model
$OUTTYP
$STARTDATE
$NFILE
$INCR
$fhr
$OUTFILDYN
$OUTFILPHYS
EOF

export pgm=hireswfv3_bufr.x

#. prep_step

export FORT19="$DATA/hiresw_profdat"
export FORT79="$datadir/profilm.c1.${tmmark}.f${fhr}"
export FORT11="itag"

#startmsg
echo ${APRUNC} $EXECfv3/hireswfv3_bufr.x
${APRUNC} $EXECfv3/hireswfv3_bufr.x  > pgmout.log_${fhr} 2>&1
#export err=$?;err_chk

echo DONE $fhr at `date`

#mv $datadir/profilm.c1.${tmmark} $datadir/profilm.c1.${tmmark}.f${fhr}
echo "done" > $DATA/sndpostdone${fhr}.${tmmark}

if [[ -f $DATA/profilm.c1.${tmmark} ]]; then
  cat $DATA/profilm.c1.${tmmark}  $datadir/profilm.c1.${tmmark}.f${fhr} > $DATA/profilm_int
  mv $DATA/profilm_int $DATA/profilm.c1.${tmmark}
else
  cat $datadir/profilm.c1.${tmmark}.f${fhr} > $DATA/profilm.c1.${tmmark}
fi

fhr=`expr $fhr + $INCR`


if [ $fhr -lt 10 ]
then
fhr=0$fhr
fi

#wdate=`$NDATE ${fhr} $CYCLE`

done

cd $datadir

########################################################
############### SNDP code
########################################################

export pgm=hiresw_sndp_${RUNLOC}

#. prep_step

cp $PARMfv3/hiresw_sndp.parm.mono $datadir/hiresw_sndp.parm.mono
cp $PARMfv3/hiresw_bufr.tbl $datadir/hiresw_bufr.tbl

export FORT11="$datadir/hiresw_sndp.parm.mono"
export FORT32="$datadir/hiresw_bufr.tbl"
export FORT66="$DATA/profilm.c1.${tmmark}"
export FORT78="$datadir/class1.bufr"

#startmsg

echo here RUNLOC $RUNLOC
echo here MODEL $MODEL
echo here model $model

nlev=60

echo "${model} $nlev" > itag
${APRUNS} $EXECfv3/hireswfv3_sndp.x  < itag >> $pgmout 2>$pgmout
#export err=$?;err_chk

############### Convert BUFR output into format directly readable by GEMPAK namsnd on WCOSS

#echo USHobsproc_shared_bufr_cword is ${USHobsproc_shared_bufr_cword}
#${USHobsproc_shared_bufr_cword}/bufr_cword.sh unblk class1.bufr class1.bufr.unb
#${USHobsproc_shared_bufr_cword}/bufr_cword.sh block class1.bufr.unb class1.bufr.wcoss

#if [ $SENDCOM == "YES" ]
#then
#cp $DATA/class1.bufr $COMOUT/${RUN}.t${cyc}z.${RUNLOC}.class1.bufr
#cp $DATA/class1.bufr.wcoss $COMOUT/${RUN}.t${cyc}z.${RUNLOC}.class1.bufr.wcoss
#cp $DATA/profilm.c1.${tmmark} ${COMOUT}/${RUN}.t${cyc}z.${RUNLOC}.profilm.c1
#fi

# remove bufr file breakout directory in $COMOUT if it exists

if [ -d ${COMOUT}/bufr.${NEST}${MODEL}${cyc} ]
then
  cd $COMOUT
  rm -r bufr.${NEST}${MODEL}${cyc}
  cd $datadir
fi

rm stnmlist_input

cat <<EOF > stnmlist_input
1
$datadir/class1.bufr
${COMOUT}/bufr.${NEST}${MODEL}${cyc}/${NEST}${MODEL}bufr
EOF

  mkdir -p ${COMOUT}/bufr.${NEST}${MODEL}${cyc}

  export pgm=hireswfv3_stnmlist
  #. prep_step

  export FORT20=$datadir/class1.bufr
  export DIRD=${COMOUT}/bufr.${NEST}${MODEL}${cyc}/${NEST}${MODEL}bufr

  #startmsg
${APRUNS}  $EXECfv3/hireswfv3_stnmlist.x < stnmlist_input >> $pgmout 2>errfile
  #export err=$?;err_chk

  echo ${COMOUT}/bufr.${NEST}${MODEL}${cyc} > ${COMOUT}/bufr.${NEST}${MODEL}${cyc}/bufrloc

#   cp class1.bufr.tm00 $COMOUT/${RUN}.${cyc}.class1.bufr

  cd ${COMOUT}/bufr.${NEST}${MODEL}${cyc}

# Tar and gzip the individual bufr files and send them to /com
  tar -cf - . | /usr/bin/gzip > ../${RUN}.t${cyc}z.${RUNLOC}.bufrsnd.tar.gz

#files=`ls`
#for fl in $files
#do
#${USHobsproc_shared_bufr_cword}/bufr_cword.sh unblk ${fl} ${fl}.unb
#${USHobsproc_shared_bufr_cword}/bufr_cword.sh block ${fl}.unb ${fl}.wcoss
#rm ${fl}.unb
#done


# Make an upper case version of the ${RUNLOC} variable for the alert
#export DBN_NEST=`echo ${RUNLOC} | tr '[a-z]' '[A-Z]'`

#if [ $SENDDBN == "YES" ]
#then
#  $DBNROOT/bin/dbn_alert MODEL ${DBN_ALERT_TYPE} $job $COMOUT/${RUN}.t${cyc}z.${RUNLOC}.class1.bufr
#  $DBNROOT/bin/dbn_alert MODEL ${DBN_ALERT_TYPE}_TAR $job $COMOUT/${RUN}.t${cyc}z.${RUNLOC}.bufrsnd.tar.gz
#fi

echo EXITING $0 with return code $err
exit $err
