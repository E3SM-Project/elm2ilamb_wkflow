#!/bin/bash


# Author: Min Xu
# @ORNL

# Modification history:
# Required software: NCO toolkit 


# defaults:

ilamb_fields=0        # define varaible list for ILAMB
convert_to_cmip=0     # 0 - not cmorize outputs; 1 - cmorize outputs 
nconcurrent=0         # number of concurrent processes to run time serialzation, 0: equal to the number of total vairables, > 0 use it
add_fixed_flds=0      # default, the fx fields won't be generated
year_align=0
use_ncremap=0
use_cremap3=0
use_ncclimo=0
use_pyreshaper=0
skip_genmap=0
no_gen_ts=0

Script=`readlink -f $0`
SrcDir=`dirname $Script`

CmdDir=`which clm_to_mip 2>/dev/null`

#-if [[ ! -z "$CmdDir" ]]; then
#-   SrcDir=`dirname $CmdDir`
#-fi                        
#-

# print usage
print_usage () {
   CR_RED='\033[0;31m'
   CR_GRN='\033[0;32m'
   CR_NUL='\033[0m'

   FTBOLD='\033[1m'
   FTNORM='\033[0m'


   CmdNam=`basename $0`
   echo "Usage: $CmdNam --caseid[-c] --year_range[-y] --align_year[-a] --caseidpath[-i] --outputpath[-o] 
                 --experiment[-e] --model[-m] --numcc [--cmip] [--ilamb] [--addfxflds] --srcgrid[-s] --dstgrid[-g] -v --no-gents
                 --skip_genmap --ncclimo|--pyreshaper --ncremap|--cremap3"

   echo ""
   echo ""
   echo ""

   echo "         --caseid, -c           : the case name"
   echo "         --year_range, -y       : the year range of the simulations used in the name construction of the output files.
                                  Format: YYYY-YYYY, i.e. first year and last year, combine with the --align_year, the model years
                                  between first_year+align_year to last_year+align_year" are processed
   echo "         --year_align, -a       : the year used to align the model year and real years set in the --year_range, it equals
                                  model year minus real year"
   echo "         --no-gen-ts            : switch of not generating ts (i.e. they were generated before)"
   echo "         --skip_genmap          : 0 mean not skip map generation, positive integer number is to skip and use mapXXXX.nc"
   echo "         --srcgrid, -s          : if do remapping, source grid description in the SCRIP format is required"
   echo "         --dstgrid, -g          : if do remapping, target grid description in the SCRIP format is required"
   echo "         --caseidpath, -i       : the directory of the simulations"
   echo "         --outputpath -o        : the directory for the outputs generated by this script"
   echo "         --experiment, -e       : the experiment name following CMIP conventions used in the name constructions of the output files"
   echo "         --model, -m            : the model name with special features, for example ACME_WCYCL used as the subdirectory name under outputpath to save output files"
   echo "         --numcc                : number of concurrent processes to do time serialzation. if 0 or not set use the total number of variables"
   echo "         --ncclimo|pyreshaper   : switch of time serialization methods either using ncclimo or PyReshaper"
   echo "         --ncreamp|creamp3      : switch of remapping methods either using ncremap or conv_remap3"
   echo "         --cmip                 : switch to rewrite model outputs following CMIP conventions"
   echo "         --ilamb                : switch to rewrite the variables for analysis in ILAMB following CMIP conventions"
   echo "         --addfxflds            : switch to rewrite the two fixed datasets 'sftlf' and 'areacella' and exit. Default they won't be written out"

   echo ""
   echo ""
}

# command line arguments:
parse_options () {
     longargs=ilamb,cmip,addfxflds,ncclimo,pyreshaper,ncremap,cremap3,no-gen-ts,skip-genmap:,caseid:,year_range:,year_align:,caseidpath:,outputpath:,experiment:,model:,numcc:,srcgrid:,dstgrid:
     shrtargs=hvc:T:y:a:i:o:e:m:s:g:
     CmdLine=`getopt -s bash  -o  $shrtargs --long $longargs -- "$@"`
     
     if [[ $? != 0 ]]; then 
       echo "Terminating..." >/dev/stderr
       exit 1
     fi
     
     eval set -- "$CmdLine"
     
     while true; do
          case "$1" in
             -h) echo $printusage; exit 1; shift ;;
             -v) set -x; shift ;;
             -c|--caseid)
                     caseid=$2
             	echo "The case name: $2"; shift 2 ;;
             -y|--year_range)
                     year_range=$2
                     if [[ $2 == *'-'* ]]; then
                         yearsplit=(`echo $2 | sed 's/-/ /g'`)
             
                         stryear=${yearsplit[0]}
                         endyear=${yearsplit[1]}
                     else
                         echo "year range should be in the format of YYYY-YYYY"
                     fi
             	echo "The simulated year range: "\`$2:q\'; shift 2 ;; 
             -a|--year_align)
                     year_align=$2
                     echo "the alignment year: $2"; shift 2 ;;
             -s|--srcgrid)
                     src_grd=$2
                     echo "the source grid: $2"; shift 2 ;;
             -g|--dstgrid)
                     dst_grd=$2
                     echo "the destination grid: $2"; shift 2 ;;
             -i|--caseidpath)
                     caseidpath=`readlink -f $2`
             	echo "The directory of the case results: "\`$2:q\' ; shift 2 ;;
             -o|--outputpath)
                     outputpath=`readlink -f $2`
     		echo "The output directory: "\`$2:q\'; shift 2 ;;
             -e|--experiment)
                     experiment=$2
     		echo "The experiment name: "\`$2:q\' ; shift 2 ;;
             -m|--model)
                     model=$2
     		echo "The model name: "\`$2:q\' ; shift 2 ;;
             --numcc)
                     nconcurrent=$2
     		echo "Number of concurrent processes: $2"; shift 2 ;;
             --skip-genmap)
                     skip_genmap=$2
     		echo "skip_genmap: $2"; shift 2 ;;
             --no-gen-ts)
                     no_gen_ts=1; shift ;;
             --ilamb)
                     ilamb_fields=1; shift ;;
             --cmip)
                     convert_to_cmip=1; shift ;;
             --addfxflds)
                     add_fixed_flds=1; shift ;;
             --ncclimo)
                     use_ncclimo=1; shift ;;
             --pyreshaper)
                     use_pyreshaper=1; shift ;;
             --ncremap)
                     use_ncremap=1; shift ;;
             --cremap3)
                     use_cremap3=1; shift ;;
             --) shift; break ;;
             *) echo "Internal error!"; exit 1 ;;
         esac
     done


     #
     if [[ -z ${caseidpath+x} ]]; then
         echo "please provide input data directory"
         exit 1
     fi
     
     #check ts options

     if [[ ! -f ./tool/clm_to_mip && $convert_to_cmip == 1 ]]; then
        echo "clm_to_mip is needed for converting model outputs following cmip conventions" 
     fi

     if [[ $use_ncclimo == 0 && $use_pyreshaper == 0 ]]; then
        echo "Time serialization option is not specified, use ncclimo as default"
         use_ncclimo=1
     
     elif [[ $use_ncclimo == 1 && $use_pyreshaper == 1 ]]; then
        echo "--ncclimo and --pyreshaper cannot be used together"
        exit -1
     fi
     
     #check remap options
     if [[ $use_ncremap == 0 && $use_cremap3 == 0 ]]; then
        skip_remap=1
     elif [[ $use_ncremap == 1 && $use_cremap3 == 1 ]]; then
        echo "${CR_RED}--ncremap and --cremap3 cannot be used together"
        exit -1
     else
        skip_remap=0
     fi
     
     if [[ ($skip_remap == 0 || $add_fixed_flds == 1) && (-z ${src_grd+x} || -z ${dst_grd+x}) ]]; then
         echo "remapping needs the srcgrd and dstgrd"
         exit -1
     fi
}


time_shift (){

difyear=$1
cmordir=$2

cd $cmordir
for cf in *.nc; do
   echo $cf
   /bin/rm -f cmortmp.nc
   ncap2 -s "time_bounds=time_bounds+$(($difyear*(-365))); time=time_bounds(:,1);" $cf cmortmp.nc
   /bin/mv -f cmortmp.nc $cf
done
}

args="$@"

#print_usage
if [[ $# == 0 ]]; then
   print_usage; exit 1
else
   parse_options $args
fi

if [[ $? != 0 ]]; then
   echo "Interal error"
fi

#directory preparation
if [[ ! -d $outputpath ]]; then
   mkdir -p $outputpath
fi

if [[ ! -d $outputpath/$caseid ]]; then
   mkdir -p $outputpath/$caseid
fi



DATA=$outputpath/$caseid
drc_inp=$caseidpath
drc_out=${DATA}/org # Native grid output directory
drc_rgr=${DATA}/rgr # Regridded output directory
drc_tmp=${DATA}/tmp # Temporary/intermediate-file directory
drc_map=${DATA}/map # Map directory
drc_log=${DATA}/log # Log directory

drc_cmor=${drc_rgr}/CMOR


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
if [[ ! -d $drc_cmor ]]; then
   mkdir -p $drc_cmor
fi

cd $outputpath/$caseid



# improve it using JSON in future
if [[ $ilamb_fields == 1 ]]; then 
   fldlist_monthly="ALT AR BTRAN CH4PROD DENIT EFLX_LH_TOT ELAI ER ESAI FAREA_BURNED \
    FCEV FCH4 FCH4TOCO2 FCOV FCTR FGEV FGR FGR12 FH2OSFC FINUNDATED FIRA FIRE FLDS FPG FPI \
    FPSN FROST_TABLE FSA FSAT FSDS FSH FSM FSNO FSR F_DENIT F_NIT GPP \
    GROSS_NMIN H2OSFC H2OSNO HR HTOP LAND_USE_FLUX LEAFC FROOTC NDEP_TO_SMINN NBP NEE NEP \
    NET_NMIN NFIX_TO_SMINN NPP Q2M QCHARGE QDRAI QOVER QRUNOFF QRGWL QSNOMELT \
    QSOIL QVEGE QVEGT RAIN RH2M SMIN_NO3 SMIN_NH4 SNOW SNOWDP SNOWICE SNOWLIQ SNOW_DEPTH \
    SNOW_SINKS SNOW_SOURCES SOMHR TG TSA TSAI TLAI TV QBOT TBOT \
    AGNPP FROOTC_ALLOC LEAFC_ALLOC WOODC_ALLOC WOOD_HARVESTC \
    CH4_SURF_AERE_SAT CH4_SURF_AERE_UNSAT CH4_SURF_DIFF_SAT \
    CH4_SURF_DIFF_UNSAT CH4_SURF_EBUL_SAT CONC_CH4_SAT \
    CONC_CH4_UNSAT FCH4_DFSAT MR TOTCOLCH4 ZWT_CH4_UNSAT \
    FSDSND FSDSNI FSDSVD FSDSVI \
    TWS VOLR WA ZWT_PERCH ZWT WIND COL_FIRE_CLOSS \
    F_DENIT_vr F_NIT_vr H2OSOI O_SCALAR SOILICE SOILLIQ SOILPSI TLAKE TSOI T_SCALAR W_SCALAR  \
    SOIL1N SOIL2N SOIL3N SOIL1C SOIL2C SOIL3C TOTVEGC TOTVEGN TOTECOSYSC TOTLITC TOTLITC_1m \
    TOTLITN_1m TOTSOMC TOTSOMC_1m TOTSOMN_1m CWDC PBOT"
   fldlist_annual=( )
else
   fldlist_monthly="ALT FCH4 FAREA_BURNED EFLX_LH_TOT FH2OSFC LAND_USE_FLUX H2OSOI NBP NEE \
    NPP Q2M RAIN SNOW SNOWDP SNOW_DEPTH TWS VOLR ZWT TSA RH2M QRUNOFF QOVER QDRAI FSNO TSOI \
    TLAI TSAI ELAI ESAI FSH FSDS FSA FIRE FIRA LEAFC TOTSOMC TOTSOMC_1m TOTVEGC TOTECOSYSC \
    TLAKE CWDC COL_FIRE_CLOSS WOOD_HARVESTC GPP ER NEP QSOIL QVEGE QVEGT QRGWL QSNOMELT"
   fldlist_annual=( )
fi


# fixed field first
if [[ $add_fixed_flds == 1 ]]; then

   use_mynco=1
   if [[ $use_mynco == 1 ]]; then
      export NCO_PATH_OVERRIDE=Yes
      myncremap=$SrcDir/tool/ncremap
   
   else
      myncremap=ncremap
   fi
   
   echo "begin of remapping for fixed field"
   firstyr=`printf "%04d" $((stryear+year_align))`
   
   echo "do mapping"
   
   ncks -O -v area,landfrac,TSA ${drc_inp}/*.clm2.h0.${firstyr}-01.nc ${drc_tmp}/area.nc 
   $myncremap -a aave -P sgs -s $src_grd -g $dst_grd -m ${drc_map}/map_${BASHPID}.nc --drc_out=${drc_rgr} \
                             ${drc_tmp}/area.nc > ${drc_log}/ncremap.lnd 2>&1
   if [[ $? != 0 ]]; then
      echo "Failed in the ncreamp, please check out ${drc_log}/ncremap.lnd"
      exit
   fi
   mapid=$BASHPID
   skip_genmap=1

   ncks -v area ${drc_rgr}/area.nc  ${drc_rgr}/areacella.nc
   ncks -v landfrac ${drc_rgr}/area.nc  ${drc_rgr}/sftlf.nc

   #remove global attribute
   ncatted -h -a ,global,d,, ${drc_rgr}/areacella.nc
   ncatted -h -a ,global,d,,     ${drc_rgr}/sftlf.nc

   #area
   ncap2 -O -h -4 -v -s 'areacella=area*6371000.*6371000.;' ${drc_rgr}/areacella.nc ${drc_cmor}/areacella"_fx_"${model}"_"${experiment}"_r0i0p0.nc"
   ncatted -h -a units,areacella,o,c,'m2' ${drc_cmor}/areacella"_fx_"${model}"_"${experiment}"_r0i0p0.nc"
   ncatted -h -a standard_name,areacella,o,c,'cell_area' ${drc_cmor}/areacella"_fx_"${model}"_"${experiment}"_r0i0p0.nc"
   ncatted -h -a long_name,areacella,o,c,'Land grid-cell area' ${drc_cmor}/areacella"_fx_"${model}"_"${experiment}"_r0i0p0.nc"
   ncatted -h -a comment,areacella,o,c,'from land model output, so it is masked out ocean part' ${drc_cmor}/areacella"_fx_"${model}"_"${experiment}"_r0i0p0.nc"
   ncatted -h -a original_name,areacella,o,c,'area' ${drc_cmor}/areacella"_fx_"${model}"_"${experiment}"_r0i0p0.nc"
   ncatted -h -a _FillValue,areacella,o,f,1.e20 ${drc_cmor}/areacella"_fx_"${model}"_"${experiment}"_r0i0p0.nc"
   ncatted -h -a missing_value,areacella,o,f,1.e20 ${drc_cmor}/areacella"_fx_"${model}"_"${experiment}"_r0i0p0.nc"

   /bin/rm -f  ${drc_rgr}/areacella.nc

   ncap2 -O -h -4 -v -s 'sftlf=landfrac*100;' ${drc_rgr}/sftlf.nc ${drc_cmor}/sftlf"_fx_"${model}"_"${experiment}"_r0i0p0.nc"
   ncatted -h -a standard_name,sftlf,o,c,'Land Area Fraction' ${drc_cmor}/sftlf"_fx_"${model}"_"${experiment}"_r0i0p0.nc"
   ncatted -h -a _FillValue,sftlf,o,f,1.e20 ${drc_cmor}/sftlf"_fx_"${model}"_"${experiment}"_r0i0p0.nc"
   ncatted -h -a missing_value,sftlf,o,f,1.e20 ${drc_cmor}/sftlf"_fx_"${model}"_"${experiment}"_r0i0p0.nc"
   ncatted -h -a units,sftlf,o,c,'%' ${drc_cmor}/sftlf"_fx_"${model}"_"${experiment}"_r0i0p0.nc"
   /bin/rm -f  ${drc_rgr}/sftlf.nc 
   /bin/rm -f  ${drc_rgr}/area.nc 
fi


# time-serialization
if [[ $no_gen_ts == 0 ]]; then
   if [[ $use_ncclimo == 1 ]]; then
      source $SrcDir/tool/run_gen_ts.bash
   else
      source $SrcDir/tool/run_reshaper.bash
   fi
fi

# remapping
if [[ $skip_remap == 0 ]]; then
   # use ncremap
   if [[ $use_ncremap == 1 ]]; then
      source $SrcDir/tool/run_ncremap.bash
   fi

   # use scipy spare matrix first
   if [[ $use_cremap3 == 1 ]]; then
      #
      #source $SrcDir/conv_remap3.bash
      echo "will be added in near future"
      exit
   fi
else
   echo "No remapping and cmorized variables directly"
fi

# cmorization (converting to CMIP format)
if [[ $convert_to_cmip == 1 ]]; then
   /bin/cp -f $SrcDir/tool/clm_to_mip $outputpath/$caseid/rgr
   cd $outputpath/$caseid/rgr
   echo clm_to_mip ${model} ${experiment} ${year_range}

   #renaming
   if [[ $use_pyreshaper == 1 ]]; then
      rename ${stryear} .${stryear} *${stryear}*.nc
   fi

   if [[ $use_ncclimo == 1 ]]; then
      # change var_YYYY01_YYYY12.nc to ncclimo.var.YYYY01_YYYY12.nc
      rename _${stryear} .monthly.${stryear} *${stryear}*.nc
      for rgrf in *${stryear}*.nc; do
          /bin/mv $rgrf ncclimo.$rgrf
      done
   fi

   ./clm_to_mip ${model} ${experiment} ${year_range}

   if [[ $year_align != 0 ]]; then
      cd $outputpath/$caseid/rgr/CMOR
      time_shift $year_align $outputpath/$caseid/rgr/CMOR
   fi
fi


# post processing 
#setenv email_address  ${LOGNAME}@ucar.edu
#echo `date` $caseid > email_msg2
#echo MESSAGE FROM clm_singlevar_ts.csh >> email_msg2
#echo YOUR TIMESERIES FILES ARE NOW READY! >> email_msg2
#mail -s 'clm_singlevar_ts.csh is complete' $email_address < email_msg2
#echo E_MAIL SENT
#'rm' email_msg2

exit 0