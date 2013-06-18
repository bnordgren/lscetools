#!/bin/bash

cpunum=64
spinup=1

####----MSUB -p 6328

## script to run site simulations with ORCHIDEE
## MODIFICATIONS: Chao.YUE 03/02/2011
## ===========================================
## USER SETTINGS
## ===========================================



## LOCATIONS OF FILES 
BINDIR_A5F=/home/bnordgren/orchidee/modipsl/bin
BINFILE=orchidee_ol	#executable name
FIREDIR=/home/bnordgren/orchidee_data/USDATA    #data for lightning and population density
OUTLOC=/home/bnordgren/orchidee_data/SPINUP	#where files are to be saved
CO2FILE=/home/bnordgren/orchidee_data/SPINUP_FORCING/co2year.dat
DIR_RUN=${OUTLOC}/RUN

## ===========================================
## SCRIPT INTERNAL SETTINGS
## ===========================================
## Run control settings
interactive=1     #interactive mode
HISTORY_RESERVE=Y #deprecated

## Set loop numbers:
LOOPNO_TESTSTOMATE1=0 #200; long_name: LOOP NUMBER TESTSTOMATE
LOOPNO_FORCESOIL2=0 #120; long_name: LOOP NUMBER FORCESOIL
LOOPNO_ORCHIDEE3=0 #70; long_name: LOOP NUMBER ORCHIDEE (THE 3 LOOP FOR ONLY ORCHIDEE)
let FORCESOIL_NO=${LOOPNO_FORCESOIL2}

## Forcing
FORFILE=/home/bnordgren/orchidee_data/SPINUP_FORCING

TIME=1                  #timelength of the forcing file
UNIT=Y                  #unit of TIME
FORCE_YEAR_FINAL_BEGIN=1679
RUN_FINAL_YEAR=1900  #the year itself included

## RESTART FILES
moteur_dem=driver_start.nc
moteur_redem=driver_restart.nc
sechiba_dem=sechiba_start.nc
sechiba_redem=sechiba_restart.nc
stomate_dem=stomate_start.nc
stomate_redem=stomate_restart.nc

## Output level and frequency
sechistlev=1
sechistdt_year=31536000 # unit in seconds; 86400 for daily; 2592000 for monthly; 31536000 for yearly
sechistdt_month=2592000 #daily
sechistdt_day=86400 #daily

stohistlev=1
stohistdt_year=365
stohistdt_day=1 #STOMATE history timestep(d)


## Function to change the run.def
remplace()
{
sed -i "/$1/c$1=$2" run.def
}

## Displaying Information 
echo interactive runscript for ORCHIDEE
echo running in $OUTLOC 
echo using forcing in from directory $FORFILE
##===============================================
## Set up the simulation-- 


  if [ ! -d ${OUTLOC} ] ; then
    mkdir -p ${OUTLOC}
  fi

cd ${OUTLOC}

##choose the location of executable files
  cp ${BINDIR_A5F}/${BINFILE} orchidee.e

 
#######################FINAL RUNNING 

  if [ ! -d ${DIR_RUN} ] ; then
    mkdir -p ${DIR_RUN}
  fi

  cp /home/bnordgren/orchidee_data/SPINUP/run.def.template run.def
  remplace RESTART_FILEIN $moteur_dem
  remplace SECHIBA_restart_in $sechiba_dem
  remplace STOMATE_RESTART_FILEIN $stomate_dem
#  remplace RESTART_FILEIN NONE
#  remplace SECHIBA_restart_in NONE
#  remplace STOMATE_RESTART_FILEIN NONE

  remplace ORCHIDEE_WATCHOUT n
  remplace WRITE_STEP $sechistdt_year           #write step for sechiba(in seconds)
  remplace SECHIBA_HISTLEVEL $sechistlev
  remplace STOMATE_HISTLEVEL $stohistlev
  remplace STOMATE_HIST_DT $stohistdt_day      #write step for stomate(in days)
  remplace LIMIT_WEST -180
  remplace LIMIT_EAST 180
  remplace LIMIT_SOUTH -90
  remplace LIMIT_NORTH 90


  let i=1
  let FORCE_YEAR=${FORCE_YEAR_FINAL_BEGIN}
  let FINAL_LOOP=$((RUN_FINAL_YEAR - FORCE_YEAR_FINAL_BEGIN + 1))
  let IITER4=${FINAL_LOOP}+${LOOPNO_TESTSTOMATE1}+${LOOPNO_FORCESOIL2}+${LOOPNO_ORCHIDEE3}

while [ ${FORCE_YEAR} -le ${RUN_FINAL_YEAR} ] ; do 


    mv $moteur_redem $moteur_dem
    mv $sechiba_redem $sechiba_dem
    mv $stomate_redem $stomate_dem

    if [ $i -eq 2 ] ; then
      remplace RESTART_FILEIN $moteur_dem
      remplace SECHIBA_restart_in $sechiba_dem
      remplace STOMATE_RESTART_FILEIN $stomate_dem
    fi
    remplace POPDENS_FILE ${FIREDIR}/popdens_${FORCE_YEAR}.nc 
    FORCE_FILE=${FORFILE}/cruncep_halfdeg_${FORCE_YEAR}.nc 

    remplace CF_COARSE_FILE /home/bnordgren/orchidee_data/USDATA/CF_coarse.nc
    remplace CF_FINE_FILE /home/bnordgren/orchidee_data/USDATA/CF_fine.nc
    remplace READ_OBSERVED_BA n
    remplace RATIO_FILE /home/bnordgren/orchidee_data/USDATA/ratio_ones.nc
    remplace RATIO_FLAG_FILE /home/bnordgren/orchidee_data/USDATA/flag_minus_ones.nc

    remplace FORCING_FILE ${FORCE_FILE}
    let CO2_YEAR=$(if test $FORCE_YEAR -lt 1850 ; then echo 1850 ; else echo ${FORCE_YEAR} ; fi )
    CO2=$(awk "(\$1 == ${CO2_YEAR}) {print \$2}" ${CO2FILE} )
    remplace ATM_CO2 $CO2


    echo spin up $i of $IITER4 : $CO2 ${CO2_YEAR} using FORCEFILE OF ${FORCE_FILE} 
    
    cp run.def ${DIR_RUN}/run.def.${FORCE_YEAR}

    #./orchidee.e > out_orchidee.txt
    qsub -pe orte ${cpunum} -sync yes -cwd -S /bin/bash -j yes \
	-o out_orchidee.txt \
	-l 'hostname=compute-0-0|compute-0-1|compute-0-2|compute-0-3|compute-0-5|compute-0-6|compute-0-7|compute-0-8|compute-0-9|compute-0-10|compute-0-11|compute-0-12|compute-0-13|compute-0-14|compute-0-15|compute-0-16|compute-0-17' \
	./submit_script.sh
    # don't save the history files if we're just spinning up.
    if [ ${spinup} -eq 1 ] ; then 
      rm -f sechiba_history_????.nc stomate_history_????.nc out_orchidee_????
    else 
      i_proc=0
      while [ ${i_proc} -lt ${cpunum} ] ; do
        i_proc_4dit=$(printf "%0.4d" ${i_proc})
        mv -f sechiba_history_${i_proc_4dit}.nc ${DIR_RUN}/sechiba_history_${i_proc_4dit}_${FORCE_YEAR}.nc	
        mv -f stomate_history_${i_proc_4dit}.nc ${DIR_RUN}/stomate_history_${i_proc_4dit}_${FORCE_YEAR}.nc	
        mv out_orchidee_${i_proc_4dit} ${DIR_RUN}/out_orchidee_${i_proc_4dit}_${FORCE_YEAR}.txt
        let i_proc=i_proc+1
      done
    fi

    # always save the "out" files 
    mv out_orchidee.txt ${DIR_RUN}/out_orchidee_${FORCE_YEAR}.txt 

    # only save a copy of the restart files if we're not spinning up
    cp driver_restart.nc ${DIR_RUN}/driver_restart_${FORCE_YEAR}.nc
    cp sechiba_restart.nc ${DIR_RUN}/sechiba_restart_${FORCE_YEAR}.nc
    cp stomate_restart.nc ${DIR_RUN}/stomate_restart_${FORCE_YEAR}.nc

    # only save ten years of restart files....
    if [ ${spinup} -eq 1 ] ; then 
      let TRAIL_YEAR=${FORCE_YEAR}-50
      rm -f ${DIR_RUN}/driver_restart_${TRAIL_YEAR}.nc
      rm -f ${DIR_RUN}/sechiba_restart_${TRAIL_YEAR}.nc
      rm -f ${DIR_RUN}/stomate_restart_${TRAIL_YEAR}.nc
    fi
    echo Completed run for ${FORCE_YEAR} >> run.log
  
    let i=i+1
    let iout=iout+1
    let FORCE_YEAR=FORCE_YEAR+1      

     
done  # main loop
