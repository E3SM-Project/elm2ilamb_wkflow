#!/usr/bin/env bash



# This script cannot be used as a standalone mode since some variables
# are defined in the script that sources this script

# If you do want to use it as a standalone mode, please define the following
# variables: outputpath, caseid, caseidpath, fldlist_monthly, stryear, endyear,
# etc.

cmip6_opt='-7 --dfl_lvl=1 --no_cll_msr --no_frm_trm --no_stg_grd' # CMIP6-specific options

DATA=$outputpath/$caseid
drc_inp=$caseidpath
drc_out=${DATA}/org # Native grid output directory
drc_rgr=${DATA}/rgr # Regridded output directory
drc_tmp=${DATA}/tmp # Temporary/intermediate-file directory
drc_map=${DATA}/map # Map directory
drc_log=${DATA}/log # Log directory


bgn_year=$stryear
end_year=$endyear

if [[ ! -d $drc_out ]]; then
   mkdir -p $drc_out
fi
if [[ ! -d $drc_rgr ]]; then
   mkdir -p $drc_rgr
fi
if [[ ! -d $drc_tmp ]]; then
   mkdir -p $drc_tmp
fi
if [[ ! -d $drc_map ]]; then
   mkdir -p $drc_map
fi
if [[ ! -d $drc_log ]]; then
   mkdir -p $drc_log
fi



use_mynco=1

if [[ $use_mynco == 1 ]]; then
   myncclimo=$SrcDir/tool/ncclimo
else
   myncclimo=ncclimo
fi

echo $DATA, $drc_map

echo $fldlist_monthly
vars="$(echo -e "${fldlist_monthly}" | sed -e 's/ \+/,/g' | sed -e 's/,$//')"
nvrs="$(echo -e "$vars" | tr -cd , | wc -c)"; nvrs=$((nvrs+1))

printf "%s\n%s" "Processing variables:" $vars
echo "Total number of variables is: $nvrs"

export TMPDIR=${drc_tmp}

cd ${drc_inp}

#generate the list of ncfiles not including directory information
ncfiles=''
for iy in `seq $((bgn_year+year_align)) $((end_year+year_align))`; do
    cy=`printf "%04d" $iy`
    ncfiles="$ncfiles "`/bin/ls *clm2.h0.${cy}*.nc`
done

#-echo $ncfiles

if [[ $nconcurrent == 0 ]]; then
   time /bin/ls $ncfiles | $myncclimo --var=${vars} --job_nbr=$nvrs --yr_srt=$bgn_year --yr_end=$end_year --ypf=500 \
        ${cmip6_opt} --drc_out=${drc_out} > ${drc_log}/ncclimo.lnd 2>&1
else
   time /bin/ls $ncfiles | $myncclimo --var=${vars} --job_nbr=$nconcurrent --yr_srt=$bgn_year --yr_end=$end_year --ypf=500 \
        ${cmip6_opt} --drc_out=${drc_out} > ${drc_log}/ncclimo.lnd 2>&1
fi

if [ "$?" != 0 ]; then
   echo "Error in the ncclimo, exiting .."
   exit;

else
   echo $DATA, $drc_map
fi

