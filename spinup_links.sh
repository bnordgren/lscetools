#!/bin/sh

path=/share/orchidee/orchidee_data/CRUNCEP
base=cruncep_halfdeg

window_start=1960
window_len=30

function make_fname () {
  printf ${base}_%04d.nc $1
}

# repeat a window of "representative weather" for 1600-1900
for spinup_year in `seq 1600 1899` ; do 
    let window_year=$window_start+\($spinup_year-1600\)%$window_len
    echo $spinup_year $window_year
    window_fname=`make_fname $window_year`
    spinup_fname=`make_fname $spinup_year`
    ln -s $path/$window_fname $spinup_fname
done 

# use real weather for 1900+
for spinup_year in `seq 1900 2010` ; do 
    spinup_fname=`make_fname $spinup_year`
    ln -s $path/$spinup_fname
done
