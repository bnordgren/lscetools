#!/bin/sh

if (( $# != 1 )) ; then 
	echo Usage: $0 restart_file
	exit
fi

restart_file=$1

ncrename -a .missing_value,_FillValue $restart_file
# att var mode type val
ncatted -a _FillValue,,m,d,1e20 $restart_file


