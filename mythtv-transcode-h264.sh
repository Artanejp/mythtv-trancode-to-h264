#!/bin/bash

# MythTV multi-pass auto-transcode to H.264, remove commercials, delete original recording, and
# make database entry point to transcoded file. 
# This is a Bourne shell script optimized for Hauppauge PVR-150 captures.
#
# Written by Defcronyke Webmaster, copyright 2012.
# Version 0.8
# https://code.google.com/p/mythtv-scripts/source/browse/trunk/test/mythtv-transcode-h264.sh
#
# Modified by K.Ohta <whatisthis.sowhat _at_ gmail.com>
# Arguments
# 
# -i path      : Path must be the directory/file to be transcoded.
# -o path      : Path must be the output directory / file name. The directory must be writeable by the mythtv user
# -c chanid    : Chanid must be chanid written in database.
# -t starttime : Starttime  must be starttime written in database.
# Etc.
# And set User Job of MythTV:
# Place local configuration file, 
# the full userjob command in mythtv-setup should look like this:
# /usr/local/bin/mythtv-transcode-h264.sh -i "%DIR%/%FILE%" -o "%DIR%/%TITLE% %SUBTITLE% - %CHANID% %STARTTIME%.mp4" -c "%CHANID%" -t "%STARTTIMEISOUTC%" --otheroptions


# MySQL database login information (for mythconverg database)
DATABASEUSER="mythtv"
DATABASEPASSWORD="yourpasswordhere"

# MythTV Install Prefix (make sure this matches with the directory where MythTV is installed)
INSTALLPREFIX="/usr/bin"

# Number of threads to use (default uses all threads)
USEOPENCL=0

AUDIOBITRATE=224
AUDIOCUTOFF=22050

ENCTHREADS=4
VIDEO_MINQ=14
VIDEO_MAXQ=33
VIDEO_QUANT=22

VIDEO_AQSTRENGTH="1.1"
VIDEO_QCOMP="0.55"

CMCUT=0
REMOVE_SOURCE=0
FASTENC=0
HWACCEL_DEC="NONE"
VIDEO_FILTERCHAIN_NOSCALE=0
VIDEO_FILTER_NOCROP=0

X264_ENCPRESET="--preset slower --8x8dct --partitions all"
X264_BITRATE="2000"

VIDEO_SKIP="-ss 15"

FFMPEG_ENC=0
HWENC=0
HWDEC=0
HW_SCALING="No"
HWACCEL_DEC=""
N_QUERY_ID=0;
if [ -e /etc/mythtv/mythtv-transcode-x264 ]; then
   . /etc/mythtv/mythtv-transcode-x264
fi


if [ -e $HOME/.mythtv-transcode-x264 ]; then
   . $HOME/.mythtv-transcode-x264
fi

#echo $DATABASEUSER $DATABASEPASSWORD
SRC=$1
DST=$2

F_CHANID=0
F_STARTTIME=0
I_CHANID=$3
I_STARTTIME=$4
I_LOCALSTARTTIME=""
F_LOCALSTARTTIME=0
USE_DATABASE=1
ENCMODE="DEFAULT"
NOENCODE=0
NEED_X264="Yes"
USE_60FPS=0
TESTMODE=0
VIDEO_DESC=""
VIDEO_SUBTITLE=""
VIDEO_EPISODE=""
VIDEO_ONAIR=""
DST=""
SRC=""
N_DIRSET=0
S_DIRSET=""
IS_HELP=0

function logging() {
   __str="$@"
   echo ${__str} | logger -t "MYTHTV.TRANSCODE[${BASHPID}]"
   echo ${__str}
}

logging "$@"

# Parse ARGS
for x in "$@" ; do
    SS="$1"
    case "$1" in
    -d | --dir )
    shift
    S_DIRSET="$1"
    N_DIRSET=1
    shift
    ;;
    -i | --src | --i )
    shift
    SRC="$1"
    shift
    ;;
    -o | --dst | --o )
    shift
    DST="$1"
    shift
    ;;
    --jobid | --job-id )
    shift
    N_QUERY_ID="$1"
    shift
    ;;
    --desc | --video-desc )
    shift
    VIDEO_DESC="$1"
    if [ -n "${VIDEO_DESC}" ] ; then
      shift
    fi
    ;;
    --episode | --video-episode )
    shift
    VIDEO_EPISODE="$1"
    if [ -n "${VIDEO_EPISODE}" ] ; then
      shift
    fi
    ;;
    --subtitle | --sub-title | --video-sub-title )
    shift
    VIDEO_SUBTITLE="$1"
    if [ -n "${VIDEO_SUBTITLE}" ] ; then
      shift
    fi
    ;;
    --onair | --on-air | --video-onair )
    shift
    VIDEO_ONAIR="$1"
    if [ -n "${VIDEO_ONAIR}" ] ; then
      shift
    fi
    ;;
    --no-chanid | --nc )
    F_CHANID=0
    shift
    ;;
    --chanid | -c )
    shift
    I_CHANID="$1"
    F_CHANID=1
    shift
    ;;
    --starttime | -t )
    shift
    I_STARTTIME="$1"
    F_STARTTIME=1
    shift
    ;;
    --local-starttime | --lt | -lt | --local_starttime )
    shift
    I_LOCALSTARTTIME="$1"
    F_LOCALSTARTTIME=1
    shift
    ;;
    --noskip | --no-skip | --no_skip )
    VIDEO_SKIP=""
    shift
    ;;
    --skip_sec | --skip-sec )
    shift
    VIDEO_SKIP="-ss $1"
    shift
    ;;
    --threads )
    shift
    ENCTHREADS="$1"
    shift
    ;;
    --db | --use-db | --with-db )
    shift
    USE_DATABASE=1
    ;;
    --hwaccel-vaapi )
    shift
    HWACCEL_DEC="VAAPI"
    ;;
    --hwaccel-vdpau )
    shift
    HWACCEL_DEC="VDPAU"
    ;;
     --no-hwaccel )
    shift
    HWACCEL_DEC="NONE"
    ;;
    --no-database | --nodb | --not-use-db | --without-db )
    shift
    USE_DATABASE=0
    ;;
    --noenc | --noencode )
    shift
    NOENCODE=1
    ;;
    --opencl | --OpenCL | --OPENCL)
    shift
    USEOPENCL=1
    ;;
    --no-opencl | --no-OpenCL | --NO-OpenCL | --NO-OPENCL)
    shift
    USEOPENCL=0
    ;;
    --cmcut )
    shift
    CMCUT=1
    ;;
    --no-cmcut )
    shift
    CMCUT=0
    ;;
    --fast-enc )
    shift
    FASTENC=1
    ;;
    --no-fast-enc )
    shift
    FASTENC=0
    ;;
    --encpreset )
    shift
    ENCPRE="$1"
     case "$ENCPRE" in
     "std" | "STD" | "standard" | "STANDARD" )
       X264_ENCPRESET="--preset slower --8x8dct --partitions all"
       ;;
     "fast" | "FAST" )
       X264_ENCPRESET="--preset slow --8x8dct --partitions all"
       ;;
     "faster" | "FASTER" )
       X264_ENCPRESET="--preset medium --8x8dct --partitions all"
       ;;
     "slow" | "SLOW" )
       X264_ENCPRESET="--preset veryslow --8x8dct --partitions all"
       ;;
     esac
     shift
     ;;
    --anime )
    # Optimize for anime
    shift
    ENCMODE="ANIME"
    echo "anime"
    ;;
    --anime_high | --anime-high )
    # Optimize for anime
    shift
    ENCMODE="ANIME_HIGH"
    ;;
    --anime_high_hw | --anime-high-hw )
    # Optimize for anime
    shift
    ENCMODE="ANIME_HIGH_HW"
    ;;
    --live_hd_high | --live-hd-high)
    # for Live, HD, high quality.
    shift
    ENCMODE="LIVE_HD_HIGH"
    ;;
    --live_hd_mid | --live-hd-mid)
    # for Live, HD, high quality.
    shift
    ENCMODE="LIVE_HD_MID"
    ;;
    --live_hd_mid_hw | --live-hd-mid-hw)
    # for Live, HD, high quality.
    shift
    ENCMODE="LIVE_HD_MID_HW"
    ;;
    --live_hd_mid_hw_test | --live-hd-mid-hw_test)
    # for Live, HD, high quality.
    shift
    ENCMODE="LIVE_HD_MID_HW"
    TESTMODE=1
    ;;
    --live1 | --live)
    # for Live, middle quality.
    shift
    ENCMODE="LIVE1"
    ;;
    --live_high | --live-high )
    # for Live, middle quality.
    shift
    ENCMODE="LIVE_HIGH"
    ;;
    --live_high_hw | --live-high-hw )
    # for Live, middle quality.
    shift
    ENCMODE="LIVE_HIGH_HW"
    ;;
    --live_mid_hw | --live-mid-hw )
    # for Live, middle quality.
    shift
    ENCMODE="LIVE_MID_HW"
    ;;
    --live_sd_high | --live-sd-high )
    # for Live, middle quality.
    shift
    ENCMODE="LIVE_SD_HIGH"
    ;;
    --live_sd_high_hw | --live-sd-high-hw )
    # for Live, middle quality.
    shift
    ENCMODE="LIVE_SD_HIGH_HW"
    ;;
    --live_sd_mid | --live-sd-mid )
    # for Live, middle quality.
    shift
    ENCMODE="LIVE_SD_MID"
    ;;
    --live_sd_mid_hw | --live-sd-mid-hw )
    # for Live, middle quality.
    shift
    ENCMODE="LIVE_SD_MID_HW"
    ;;
    --live_low | --live-low)
    # for Live, middle quality.
    shift
    ENCMODE="LIVE_LOW"
    ;;
    --live_low_hw | --live-low-hw)
    # for Live, middle quality.
    shift
    ENCMODE="LIVE_LOW_HW"
    ;;
    --live_mid | --live-mid)
    # for Live, middle quality.
    shift
    ENCMODE="LIVE_MID"
    ;;
    --live_mid_hw | --live-mid-hw)
    # for Live, middle quality.
    shift
    ENCMODE="LIVE_MID_HW"
    ;;
    --encmode )
    shift
    ENCMODE="$1"
    shift
    ;;
    --remove | --remove-source | --REMOVE-SOURCE )
    shift
    REMOVE_SOURCE=1
    ;;
    --fps60 | --60fps )
    shift
    USE_60FPS=1
    ;;
    --norm | --no-remove | --no-remove-source | --NO-REMOVE-SOURCE )
    shift
    REMOVE_SOURCE=0
    ;;
    -h | --help )
    IS_HELP=1
    ;;
    esac
done
# don't change these
MYPID=$$
HWDECODE_TAG=TRANSCODE_${MYPID}

# a temporary working directory (must be writable by mythtv user)
TEMPDIR=`mktemp -d`

function change_arg_nonpath() {
    # $1 = str
    __tmpv1="$1"
    logging "${__tmpv1}"
#    if [ -n "${__tmpv1}" ] ; then
cat <<EOF >${TEMPDIR}/__tmpscript0
s/\"/”/g
s/&/ ＆/g
s/'/’/g
s/!/！/g
s/?/？/g
s/\#/＃/g
s/\//／/g
s/=/＝/g
s/ /　/g
s/"\\"/＼/g
s/\;/；/g
s/)/）/g
s/(/（/g
s/\[/［/g
s/"\"/＼/g
s/\]/］/g
s/</＜/g
s/>/＞/g
s/"\n"/_/g
EOF
__tmpv1=`echo "${__tmpv1}" | awk -F/ '{print $NF}' | sed -f ${TEMPDIR}/__tmpscript0`
echo "${__tmpv1}"
#rm ${TEMPDIR}/__tmpscript0
}

# Not substitude slash.
function change_arg_nonpath2() {
    # $1 = str
    __tmpv1="$1"
    logging "${__tmpv1}"
#    if [ -n "${__tmpv1}" ] ; then
cat <<EOF >${TEMPDIR}/__tmpscript02
s/\"/”/g
s/&/ ＆/g
s/'/’/g
s/!/！/g
s/?/？/g
s/\#/＃/g
s/=/＝/g
s/ /　/g
s/"\\"/＼/g
s/\;/；/g
s/)/）/g
s/(/（/g
s/\[/［/g
s/"\"/＼/g
s/\]/］/g
s/</＜/g
s/>/＞/g
s/"\n"/_/g
EOF
__tmpv1=`echo "${__tmpv1}" | awk -F/ '{print $NF}' | sed -f ${TEMPDIR}/__tmpscript02`
echo "${__tmpv1}"
#rm ${TEMPDIR}/__tmpscript02
}

function change_arg_file() {
# $1 = str
__SRCFILE="$1"
__TMPF=${TEMPDIR}/__tmpfile

cat <<EOF >${TEMPDIR}/__tmpscript1
s/\"/”/g
s/&/ ＆/g
s/'/’/g
s/!/！/g
s/?/？/g
s/\#/＃/g
s/\//／/g
s/=/＝/g
s/ /　/g
s/"\\"/＼/g
s/:/：/g
s/\;/；/g
s/)/）/g
s/(/（/g
s/\[/［/g
s/"\"/＼/g
s/\]/］/g
s/</＜/g
s/>/＞/g
s/"\n"/_/g
EOF
__tmpv1=`cat ${__SRCFILE} | sed -f "${TEMPDIR}/__tmpscript1"`
#rm ${TEMPDIR}/__tmpscript1
echo "${__tmpv1}"
}

# Not substitude slash.
function change_arg_file2() {
# $1 = str
__SRCFILE="$1"
__TMPF=${TEMPDIR}/__tmpfile

cat <<EOF >${TEMPDIR}/__tmpscript12
s/\"/”/g
s/&/ ＆/g
s/'/’/g
s/!/！/g
s/?/？/g
s/\#/＃/g
s/=/＝/g
s/ /　/g
s/"\\"/＼/g
s/\;/；/g
s/)/）/g
s/(/（/g
s/\[/［/g
s/"\"/＼/g
s/\]/］/g
s/</＜/g
s/>/＞/g
s/"\n"/_/g
EOF
__tmpv1=`cat ${__SRCFILE} | sed -f "${TEMPDIR}/__tmpscript12"`
#rm ${TEMPDIR}/__tmpscript12
echo "${__tmpv1}"
}


ARG_METADATA=""

ARG_DESC=""
ARG_SUBTITLE=""
ARG_EPISODE=""
ARG_ONAIR=""

__N_TITLE=""

if [ -n "${VIDEO_DESC}" ] ; then
   ARG_DESC=`change_arg_nonpath "${VIDEO_DESC}"`
   ARG_METADATA="${ARG_METADATA} -metadata description=\"${ARG_DESC}\""
fi
if [ -n "${VIDEO_EPISODE}" ] ; then
   ARG_EPISODE=`change_arg_nonpath "${VIDEO_EPISODE}"`
   ARG_METADATA="${ARG_METADATA} -metadata episode_id=\"${ARG_EPISODE}\""
fi
if [ -n "${VIDEO_SUBTITLE}" ] ; then
   ARG_SUBTITLE=`change_arg_nonpath "${VIDEO_SUBTITLE}"`
   ARG_METADATA="${ARG_METADATA} -metadata synopsis=\"${ARG_SUBTITLE}\""
fi
if [ -n "${VIDEO_ONAIR}" ] ; then
   ARG_ONAIR="${VIDEO_ONAIR}"
   ARG_METADATA="${ARG_METADATA} -metadata date=\"${ARG_ONAIR}\""
fi
if test $N_QUERY_ID -gt 0; then
  logging "QUERY JOBQUEUE id ${N_QUERY_ID}"
  
#  echo "SELECT * from jobqueue where id=${N_QUERY_ID} ;" > "$TEMPDIR/jobqueue.query.sql"
  #logging `cat "$TEMPDIR/jobqueue.query.sql"`
#  logging `mysql -v -v -v --user=$DATABASEUSER --password=$DATABASEPASSWORD mythconverg < "$TEMPDIR/jobqueue.query.sql"`

  echo "SELECT chanid from jobqueue where id=${N_QUERY_ID} ;" > "$TEMPDIR/getchanid.query.sql"
  #logging `cat "$TEMPDIR/getchanid.query.sql"`
  mysql -B -N --user=$DATABASEUSER --password=$DATABASEPASSWORD mythconverg < "$TEMPDIR/getchanid.query.sql" >"$TEMPDIR/chanid.txt"
  loggind "SID:"
  logging `cat "$TEMPDIR/chanid.txt"`

  echo "SELECT starttime from jobqueue where id=${N_QUERY_ID} ;" > "$TEMPDIR/getstarttime.query.sql"
  #logging `cat "$TEMPDIR/getstarttime.query.sql"`
  mysql -B -N  --user=$DATABASEUSER --password=$DATABASEPASSWORD mythconverg < "$TEMPDIR/getstarttime.query.sql" > "$TEMPDIR/starttime.txt" 
  logging `cat "$TEMPDIR/starttime.txt"`
 
   __N_CHANID=`cat "$TEMPDIR/chanid.txt"`
   __N_STARTTIME=`cat "$TEMPDIR/starttime.txt"`
  
#  logging "TITLE:"
  echo "SELECT title from recorded where chanid=${__N_CHANID} and starttime=\"${__N_STARTTIME}\" ;" > "$TEMPDIR/gettitle.query.sql"
#  logging `cat "$TEMPDIR/gettitle.query.sql"`
  mysql -B -N  --user=$DATABASEUSER --password=$DATABASEPASSWORD mythconverg < "$TEMPDIR/gettitle.query.sql" > "$TEMPDIR/title.txt" 
#  logging `cat "$TEMPDIR/title.txt"`

#  logging "DESC:"
  echo "SELECT subtitle from recorded where chanid=${__N_CHANID} and starttime=\"${__N_STARTTIME}\" ;" > "$TEMPDIR/getsubtitle.query.sql"
#  logging `cat "$TEMPDIR/getsubtitle.query.sql"`
  mysql -B -N  --user=$DATABASEUSER --password=$DATABASEPASSWORD mythconverg < "$TEMPDIR/getsubtitle.query.sql" > "$TEMPDIR/subtitle.txt" 
#  logging `cat "$TEMPDIR/subtitle.txt"`
  
#  logging "SUBTITLE:"
  echo "SELECT description from recorded where chanid=${__N_CHANID} and starttime=\"${__N_STARTTIME}\" ;" > "$TEMPDIR/getdesc.query.sql"
#  logging `cat "$TEMPDIR/getdesc.query.sql"`
  mysql -B -N  --user=$DATABASEUSER --password=$DATABASEPASSWORD mythconverg < "$TEMPDIR/getdesc.query.sql" > "$TEMPDIR/desc.txt"
#  logging `cat "$TEMPDIR/desc.txt"`

  __N_DESC=`cat "$TEMPDIR/desc.txt"`
    __N_SUBTITLE=`cat "$TEMPDIR/subtitle.txt"`
    __N_TITLE=`cat "$TEMPDIR/title.txt"`
#    logging ${__N_TITLE}
#    if [ -n "${__N_TITLE}" ] ; then
#      change_arg_file "$TEMPDIR/title.txt"
      ARG_TITLE=$(change_arg_file "$TEMPDIR/title.txt")
      ARG_METADATA="${ARG_METADATA} -metadata title=\"${ARG_TITLE}\""
#      logging ${ARG_TITLE}
#    fi
    if [ -n "${__N_DESC}" ] ; then
      ARG_DESC=$(change_arg_file "$TEMPDIR/desc.txt")
      ARG_METADATA="${ARG_METADATA} -metadata description=\"${ARG_DESC}\""
#      logging ${ARG_DESC}
    fi
    if [ -n "${__N_SUBTITLE}" ] ; then
      ARG_SUBTITLE=$(change_arg_file "$TEMPDIR/subtitle.txt")
      ARG_METADATA="${ARG_METADATA} -metadata synopsis=\"${ARG_SUBTITLE}\""
#      logging ${ARG_SUBTITLE}
    fi
    if [ $F_CHANID -eq 0 ]; then
       I_CHANID=${__N_CHANID}
 #  __N_STARTTIME=`cat "$TEMPDIR/chanid.txt"`
    fi
    if [ -n "$I_LOCALSTARTTIME" ] ; then
        ARG_STARTTIME="${I_LOCALSTARTTIME}"
    else
        ARG_STARTTIME="${__N_STARTTIME}"
    fi
fi
if [ -z "${ARG_STARTTIME}" ] ; then
    ARG_STARTTIME="${I_STARTTIME}"
fi
logging "TITLE:"
logging ${ARG_TITLE}
logging "START:"
logging ${ARG_STARTTIME}
logging "SUBTITLE:"
logging ${ARG_SUBTITLE}
logging "DESCRIPTION:"
logging ${ARG_DESC}

BASENAME=""
if [ $N_DIRSET -ne 0 ] ; then
   DIRNAME2="${S_DIRSET}"
   DIRNAME="${S_DIRSET}"
#   BASENAME=`change_arg_nonpath "${DST}"`
#  BASENAME=`echo "${DST}" | awk -F/ '{print $NF}' | sed 's/!/！/g' | sed 's/ /_/g' | sed 's/://g' | sed 's/?/？/g' | sed "s/'/’/g" | sed 's/"//g' `
else
  DIRNAME2=`dirname "$SRC"`
  DIRNAME=`dirname "$DST"`
  #DIRNAME=`dirname "$SRC"`
  #BASENAME0=`basename "$DST"`
  BASENAME=`echo "$DST" | awk -F/ '{print $NF}' | sed 's/!/！/g' | sed 's/ /_/g' | sed 's/://g' | sed 's/?/？/g' | sed s/"'"/’/g `
fi
if [ -z "${BASENAME}" ] ; then
   BASENAME="${ARG_TITLE}_${I_CHANID}_${ARG_STARTTIME}.mp4"
fi
  logging "TRY TO ENCODE SRC:DIR=${DIRNAME2} NAME=${SRC} TO DST:DIR=${DIRNAME} NAME=${BASENAME}" 

if [ -n "${BASENAME}" ] ; then
   echo
else
   IS_HELP=1
fi

if [ ${IS_HELP} -ne 0 ] ; then
    echo "Auto transcode script for MythTV."
    echo "  Written by Defcronyke Webmaster, copyright 2012."
    echo "    See, https://code.google.com/p/mythtv-scripts/source/browse/trunk/test/mythtv-transcode-h264.sh ."
    echo "  Modified from v0.8: K.Ohta <whatsithis.sowhat@gmail.com>"
    echo "Note:"
    echo " - Transcoded file is MP4 container, H.264 AVC + AAC." 
    echo " - You can put configuration file to ~/.mythtv-transcode-x264 ."
    echo "   To use MythTV's user's job, put this config file to /home/mythtv etc..."
    echo " "
    echo "Usage:"
    echo " -d | --dir Directory                     : Set Input/Output directory."
    echo " -i | --src | --i Input-File              : Set input file."
    echo " -o | --dst | --o Output-File             : Set output file. You must set to MP4 File."
    echo " -c | --chanid chanid                     : Set channel-id written in database."
    echo " -t | --starttime starttime               : Set start time written in database."
    echo " --noskip   | --no-skip                   : Not skip (mostly 15Sec.) from head of source."
    echo " --skip_sec | --skip-sec sec              : Skip sec  from head of source."
    echo " --jobid [MYTHTV's JOBID]                 : Set JOBID from MythTV.Query some metadatas from MythTV's Database."
    echo " --title 'title'                          : Set title for output movie,"
    echo " --desc 'DESCRIPTION'                     : Set DESCRIPTION for output movie,"
    echo " --subtitle 'SUBTITLE'                    : Set SUB TITLE for output movie,"
    echo " --onair 'TIME'                           : Set on air time  for output movie,"
    echo " --cmcut : Perform CM CUT.(DANGER!) Seems to be imcomplete audio(s) at ISDB/Japan"
    echo " --no-cmcut : DO NOT Perform CM CUT.(Default)"
    echo " --db    : Use MythTV's database to manage trancoded video.(Default)"
    echo " --nodb  : Don't use MythTV's database and not manage trancoded video.(not default, useful for manual transcoding)"
    echo " --threads threads : Set threads for x264 video encoder. (Default = 4)"
    echo " --opencl    : Use OpenCL on video encoding."
    echo " --no-opencl : DO NOT Use OpenCL on video encoding.(Default)"
    echo " --hwaccel-vaapi : Use VAAPI to decode video ."
    echo " --hwaccel-vdpau : Use VDPAU to decode video ."
    echo " --no-hwaccel    : DO not use HW Accelaration to decode video ."
    echo " "
    echo " --anime          : Set encode parameters for Anime (standard)."
    echo " --anime_high     : Set encode parameters for Anime (high quality a little)."
    echo " --live1 | --live : Set encode parameters for Live movies (standard)."
    echo " --live_hd_high      : Set encode parameters for Live movies (1920x1080 : higher than standard)."
    echo " --live_hd_mid      : Set encode parameters for Live movies (1920x1080 : standard)."
    echo " --live_high      : Set encode parameters for Live movies (higher than standard)."
    echo " --live_mid       : Set encode parameters for Live movies (lower than standard)."
    echo " --live_low : Set encode parameters for Live movies (low-bitrate, low-quality)."
    echo " --encmode MODE : Set encode parameters to preset named MODE."
    echo " --remove-source | --remove       : Remove source after if transcoding is succeeded. (CAUTION!)"
    echo " --no-remove-source | --no-remove : DO NOT remove source after if transcoding is succeeded. (CAUTION!)"
    echo " --encpreset <std | fast | faster | slow> : Set x264's preset mode."
    echo "    std    = --preset slower"
    echo "    fast   = --preset slow"
    echo "    fast   = --preset medium"
    echo "    faster = --preset fast"
    logging "END."
    exit 1
fi

if [ ! -e "$DIRNAME2/$SRC2" ] ; then
   logging "Source file : $DIRNAME2/$SRC2 has not exists."
   exit 4
fi
logging ${TEMPDIR}
#if [ -d "$DIRNAME2/$SRC2" ] ; then
#    echo "Source file is Directory."
#    exit 4
#fi

touch "$DIRNAME/test$BASENAME"
if [ ! -w "$DIRNAME/test$BASENAME" ] ; then 
   logging "Unable to Write output."
   exit 3
fi
rm "$DIRNAME/test$BASENAME"


BASENAME2=`echo "$SRC" | awk -F/ '{print $NF}'`
logging `printf "BASENAME=%s STARTTIME=%s" ${BASENAME} ${I_STARTTIME}`

# play nice with other processes
renice 19 $MYPID
ionice -c 3 -p $MYPID

# make working dir, go inside
mkdir $TEMPDIR/mythtmp-$MYPID
cd $TEMPDIR/mythtmp-$MYPID

SRC2="$BASENAME2"
if test $USE_DATABASE -ne 0 ; then
  # remove commercials
  if test $CMCUT -ne 0; then
    $INSTALLPREFIX/mythcommflag  --chanid "$I_CHANID" --starttime "$I_STARTTIME"
    $INSTALLPREFIX/mythtranscode --chanid "$I_CHANID" --starttime "$I_STARTTIME" --mpeg2 --honorcutlist
    echo "UPDATE recorded SET basename='$BASENAME2.tmp' WHERE chanid='$I_CHANID' AND starttime='$I_STARTTIME';" > update-database_$MYPID.sql
    mysql -v -v -v --user=$DATABASEUSER --password=$DATABASEPASSWORD mythconverg < update-database_$MYPID.sql
    SRC2="$BASENAME2.tmp"
  fi
  # fix seeking and bookmarking by removing stale db info
  echo "DELETE FROM recordedseek WHERE chanid='$I_CHANID' AND starttime='$I_STARTTIME';" > update-database_$MYPID.sql
  mysql -v -v -v --user=$DATABASEUSER --password=$DATABASEPASSWORD mythconverg < update-database_$MYPID.sql
  echo "DELETE FROM recordedmarkup WHERE chanid='$I_CHANID' AND starttime='$I_STARTTIME';" > update-database_$MYPID.sql
  mysql -v -v -v --user=$DATABASEUSER --password=$DATABASEPASSWORD mythconverg < update-database_$MYPID.sql
fi

if test $NOENCODE -eq 0; then
x=$ENCMODE
case "$x" in
#   "ANIME" | "LIVE_MID")
#   AUDIOBITRATE=192
#   AUDIOCUTOFF=20000
#   ;;
   "ANIME_HIGH" | "LIVE_HIGH" | "LIVE_HD_HIGH"  | "LIVE_HD_MID" | "LIVE_SD_HIGH" )
   AUDIOBITRATE=224
   AUDIOCUTOFF=22050
   ;;
   "ANIME_HIGH_HW" | "LIVE_HIGH_HW" | "LIVE_HD_HIGH_HW"  | "LIVE_HD_MID_HW" | "LIVE_SD_HIGH_HW" )
   AUDIOBITRATE=224
   AUDIOCUTOFF=22050
   ;;
esac

# convert audio track to aac
AUDIOTMP="$TEMPDIR/a1tmp.raw"
mkfifo $AUDIOTMP


# first video pass
VIDEOTMP="$TEMPDIR/v1tmp.y4m"
mkfifo $VIDEOTMP

# if set encode mode ($ENCMODE), override defaults.

#VIDEO_FILTERCHAIN0="crop=out_w=1440:out_h=1080:y=1080:keep_aspect=1"
VIDEO_FILTERCHAIN0=""
VIDEO_FILTERCHAINX="kerndeint,hqdn3d=luma_spatial=4.5:chroma_spatial=3.4:luma_tmp=4.4:chroma_tmp=4.0"
VIDEO_FILTERCHAIN_SCALE="scale=width=1280:height=720:flags=lanczos"
#X264_FILTPARAM="--vf resize:width=1280,height=720,method=lanczos"
X264_FILTPARAM=""
# Live video (low motion)

X264_BITRATE=0
#Determine override presets when set to mode
x=$ENCMODE
case "$x" in
   "ANIME" | "ANIME_HW" )
   VIDEO_QUANT=24
   VIDEO_MINQ=15
   VIDEO_MAXQ=28
   VIDEO_AQSTRENGTH=0.65
   VIDEO_QCOMP=0.70
   VIDEO_FILTERCHAINX="yadif,hqdn3d=luma_spatial=2.7:chroma_spatial=2.2:luma_tmp=2.5:chroma_tmp=2.5"
   VIDEO_FILTERCHAIN_SCALE="scale=width=1280:height=720:flags=spline"
   VIDEO_FILTERCHAIN_NOCROP=1
   if test $USE_60FPS -ne 0 ; then
      VIDEO_FILTERCHAIN_VAAPI="deinterlace_vaapi=mode=motion_adaptive:rate=2,scale_vaapi=w=1280:h=720"
   else
      VIDEO_FILTERCHAIN_VAAPI="deinterlace_vaapi=mode=motion_adaptive,scale_vaapi=w=1280:h=720"
   fi
   X264_BITRATE="2500"
   #X264_FILTPARAM="--vf resize:width=1280,height=720,method=bicubic"
   ;;
   "ANIME_HIGH" | "ANIME_HIGH_HW" )
   VIDEO_QUANT=23
   VIDEO_MINQ=14
   VIDEO_MAXQ=26
   VIDEO_AQSTRENGTH=0.47
   VIDEO_QCOMP=0.75
   #VIDEO_FILTERCHAINX="yadif,hqdn3d=luma_spatial=2.5:chroma_spatial=2.7:luma_tmp=2.8:chroma_tmp=2.9"
   VIDEO_FILTERCHAINX="yadif"
   VIDEO_FILTERCHAIN_SCALE="scale=width=1280:height=720:flags=spline"
   VIDEO_FILTERCHAIN_NOCROP=1

   VIDEO_FILTERCHAIN_VAAPI_HEAD="format=nv12|vaapi,hwupload"
   #VIDEO_FILTERCHAIN_VAAPI="deinterlace_vaapi=mode=motion_adaptive,scale_vaapi=w=1280:h=720"
   if test $USE_60FPS -ne 0 ; then
      VIDEO_FILTERCHAIN_VAAPI="deinterlace_vaapi=mode=motion_adaptive:rate=2,scale_vaapi=w=1280:h=720"
   else
      VIDEO_FILTERCHAIN_VAAPI="deinterlace_vaapi=mode=motion_adaptive,scale_vaapi=w=1280:h=720"
   fi
   VIDEO_FILTERCHAIN_VAAPI_TAIL="hwdownload,format=yuv420p"
   ;;
   "LIVE1" )
   VIDEO_QUANT=23
   VIDEO_MINQ=17
   VIDEO_MAXQ=37
   VIDEO_AQSTRENGTH=1.00
   VIDEO_QCOMP=0.60
   X264_BITRATE=2500
   VIDEO_FILTERCHAINX="yadif,hqdn3d=luma_spatial=4.2:chroma_spatial=3.2:luma_tmp=3.8:chroma_tmp=3.8"
   VIDEO_FILTERCHAIN_NOCROP=1
   ;;
   "LIVE_HD_MID" | "LIVE_HD_MID_HW" )
   VIDEO_QUANT=25
   VIDEO_MINQ=12
   VIDEO_MAXQ=37
   VIDEO_AQSTRENGTH=1.15
   VIDEO_QCOMP=0.70
   #X264_BITRATE=3500
   #VIDEO_FILTERCHAINX="yadif,hqdn3d=luma_spatial=3.0:chroma_spatial=3.0:luma_tmp=2.8:chroma_tmp=2.7"
   VIDEO_FILTERCHAINX="yadif"
#   VIDEO_FILTERCHAIN_SCALE="scale=width=1920:height=1080:flags=lanczos"
   VIDEO_FILTERCHAIN_VAAPI_HEAD="format=nv12|vaapi,hwupload"
   if test $USE_60FPS -ne 0 ; then
      VIDEO_FILTERCHAIN_VAAPI="deinterlace_vaapi=mode=motion_adaptive:rate=2,scale_vaapi=w=1440:h=1080"
   else
      VIDEO_FILTERCHAIN_VAAPI="deinterlace_vaapi=mode=motion_adaptive,scale_vaapi=w=1440:h=1080"
   fi
   VIDEO_FILTERCHAIN_VAAPI_TAIL="hwdownload,format=yuv420p"
   VIDEO_FILTERCHAIN_NOCROP=1
   VIDEO_FILTERCHAIN_NOSCALE=1
   ;;
   "LIVE_HD_HIGH" | "LIVE_HD_HIGH_HW" )
   VIDEO_QUANT=24
   VIDEO_MINQ=14
   VIDEO_MAXQ=33
   VIDEO_AQSTRENGTH=0.75
   VIDEO_QCOMP=0.75
   #X264_BITRATE=3500
#   VIDEO_FILTERCHAINX="yadif,hqdn3d=luma_spatial=2.5:chroma_spatial=2.4:luma_tmp=3.1:chroma_tmp=3.0"
   VIDEO_FILTERCHAINX="yadif"
   if test $USE_60FPS -ne 0 ; then
      VIDEO_FILTERCHAIN_VAAPI="deinterlace_vaapi=mode=motion_adaptive:rate=2,scale_vaapi=w=1440:h=1080"
   else
      VIDEO_FILTERCHAIN_VAAPI="deinterlace_vaapi=mode=motion_adaptive,scale_vaapi=w=1440:h=1080"
   fi
   VIDEO_FILTERCHAIN_NOSCALE=1
   VIDEO_FILTERCHAIN_NOCROP=1

   ;;
   "LIVE_HIGH" | "LIVE_HIGH_HW" )
   VIDEO_QUANT=24
   VIDEO_MINQ=12
   VIDEO_MAXQ=34
   VIDEO_AQSTRENGTH=1.05
   VIDEO_QCOMP=0.70
   #X264_BITRATE=3500
   VIDEO_FILTERCHAINX="yadif"
   #VIDEO_FILTERCHAINX="yadif,hqdn3d=luma_spatial=4.2:chroma_spatial=3.2:luma_tmp=3.8:chroma_tmp=3.8"
   VIDEO_FILTERCHAIN_VAAPI_HEAD="format=nv12|vaapi,hwupload"
   if test $USE_60FPS -ne 0 ; then
      VIDEO_FILTERCHAIN_VAAPI="deinterlace_vaapi=mode=motion_adaptive:rate=2,scale_vaapi=w=1280:h=720"
   else
      VIDEO_FILTERCHAIN_VAAPI="deinterlace_vaapi=mode=motion_adaptive,scale_vaapi=w=1280:h=720"
   fi
   VIDEO_FILTERCHAIN_VAAPI_TAIL="hwdownload,format=yuv420p" 
   VIDEO_FILTERCHAIN_NOCROP=1
   #VIDEO_FILTERCHAIN_VAAPI_TAIL="hwdownload"
   ;;
   "LIVE_SD_HIGH" | "LIVE_SD_HIGH_HW" )
   VIDEO_QUANT=22
   VIDEO_MINQ=12
   VIDEO_MAXQ=27
   VIDEO_AQSTRENGTH=0.95
   VIDEO_QCOMP=0.75
   #X264_BITRATE=3500
   VIDEO_FILTERCHAIN0="crop=out_w=640:out_h=480:y=480:keep_aspect=1"
   VIDEO_FILTERCHAINX="yadif"
   VIDEO_FILTERCHAIN_VAAPI_HEAD="format=nv12|vaapi,hwupload"
   if test $USE_60FPS -ne 0 ; then
      VIDEO_FILTERCHAIN_VAAPI="deinterlace_vaapi=mode=bob:rate=2"
   else
      VIDEO_FILTERCHAIN_VAAPI="deinterlace_vaapi=mode=bob"
   fi
   VIDEO_FILTERCHAIN_VAAPI=${VIDEO_FILTERCHAIN_VAAPI},scale_vaapi=w=640:h=480
   #VIDEO_FILTERCHAIN_VAAPI="deinterlace_vaapi=mode=bob"
   VIDEO_FILTERCHAIN_VAAPI_TAIL="hwdownload,format=yuv420p"
   VIDEO_FILTERCHAIN_NOSCALE=0
   VIDEO_FILTER_NOCROP=1
   ;;
   "LIVE_MID" | "LIVE_MID_HW" )
   VIDEO_QUANT=26
#   VIDEO_QUANT=25
   VIDEO_MINQ=18
   VIDEO_MAXQ=57
   VIDEO_AQSTRENGTH=1.35
   VIDEO_QCOMP=0.45
   #X264_BITRATE="1800"
   #VIDEO_FILTERCHAINX="yadif,hqdn3d=luma_spatial=4.7:chroma_spatial=3.5:luma_tmp=4.2:chroma_tmp=4.2"
   VIDEO_FILTERCHAINX="yadif"
   VIDEO_FILTERCHAIN_SCALE="scale=width=1280:height=720:flags=lanczos"
   VIDEO_FILTERCHAIN_VAAPI_HEAD="format=nv12|vaapi,hwupload"
#   if test $USE_60FPS -ne 0 ; then
#      VIDEO_FILTERCHAIN_VAAPI="deinterlace_vaapi=mode=motion_adaptive:rate=2,scale_vaapi=w=1280:h=720"
#   else
#      VIDEO_FILTERCHAIN_VAAPI="deinterlace_vaapi=mode=motion_adaptive,scale_vaapi=w=1280:h=720"
#   fi
   if test $USE_60FPS -ne 0 ; then
      VIDEO_FILTERCHAIN_VAAPI="deinterlace_vaapi=mode=bob:rate=field,scale_vaapi=w=1280:h=720"
   else
      VIDEO_FILTERCHAIN_VAAPI="deinterlace_vaapi=mode=bob,scale_vaapi=w=1280:h=720"
   fi
   VIDEO_FILTERCHAIN_VAAPI_TAIL="hwdownload,format=yuv420p"
   VIDEO_FILTERCHAIN_NOSCALE=0
   VIDEO_FILTERCHAIN_NOCROP=1
   
   ;;
   "LIVE_LOW" | "LIVE_LOW_HW" )
   VIDEO_QUANT=30
   VIDEO_MINQ=19
   VIDEO_MAXQ=59
   VIDEO_AQSTRENGTH=1.90
   VIDEO_QCOMP=0.35
#   X264_BITRATE=1100
   VIDEO_FILTERCHAINX="yadif,hqdn3d=luma_spatial=5.0:chroma_spatial=3.9:luma_tmp=4.7:chroma_tmp=4.7"
   if test $USE_60FPS -ne 0 ; then
      VIDEO_FILTERCHAIN_VAAPI="deinterlace_vaapi=mode=bob:rate=2,scale_vaapi=w=1280:h=720"
   else
      VIDEO_FILTERCHAIN_VAAPI="deinterlace_vaapi=mode=bob,scale_vaapi=w=1280:h=720"
   fi
   VIDEO_FILTERCHAIN_NOCROP=1
   ;;
esac
if test $USE_60FPS -eq 0 ; then
   FRAMERATE=30000/1001
else
   FRAMERATE=60000/1001
fi
   
X264_PRESETS="--profile high --keyint 300 --min-keyint 24 --scenecut 30 --trellis 2"
#X264_QUANT="--crf $VIDEO_QUANT"
X264_QUANT=""
X264_AQPARAM="--aq-mode 3 --qpmin $VIDEO_MINQ --qpmax $VIDEO_MAXQ --qpstep 12 --aq-strength $VIDEO_AQSTRENGTH --qcomp $VIDEO_QCOMP"

# Modify encoding parameter(s) on ANIME/ANIME_HIGH
X264_DIRECT="--direct auto "
X264_BFRAMES="--bframes 5 --b-bias -2 --b-adapt 2"
x=$ENCMODE
case "$x" in
   ANIME )
     X264_DIRECT="--direct auto"
     X264_BFRAMES="--bframes 6 --b-bias -2 --b-adapt 2"
     X264_PRESETS="--profile high --keyint 300 --min-keyint 24 --scenecut 30 --trellis 2"
     X264_ENCPRESET="--preset slow --ref 6 --8x8dct --partitions all"
   ;;
   ANIME_HW )
     HWENC_PARAM="-profile:v main -level 51 \
		  -qp 25 -qmin 16 -qmax 30 \
		  -sc_threshold 40 \
		  -quality 1 -aspect 16:9"
     HW_SCALING="Yes"
     HWACCEL_DEC="vaapi"
     #HW_SCALING="No"
     #HWACCEL_DEC="NONE"
     FFMPEG_ENC=0
     HWENC=1
     HWDEC=0
   ;;

   ANIME_HIGH )
     X264_DIRECT="--direct auto"
     X264_BFRAMES="--bframes 5 --b-bias -2 --b-adapt 2"
     X264_PRESETS="--profile high --8x8dct --keyint 300 --min-keyint 24 --scenecut 40 --trellis 2"
     X264_ENCPRESET="--preset slow --ref 5 --8x8dct --partitions all"
     
     FFMPEG_X264_HEAD="-profile:v high -preset slow -direct-pred auto -crf ${VIDEO_QUANT} -bluray-compat 1"
     FFMPEG_X264_FRAMES1="-b-pyramid strict  -b-bias -2 -me_method umh -weightp smart"
     FFMPEG_X264_PARAM2="-x264-params aq-mode=3:aq-strength=${VIDEO_AQSTRENGTH}:"
     FFMPEG_X264_PARAM3="qcomp=${VIDEO_QCOMP}:trellis=2:8x8dct=1:scenecut=40:ref=5:bframes=5:b-adapt=2:qpstep=12:"
     FFMPEG_X264_PARAM4="keyint=300:min-keyint=24:qpmin=${VIDEO_MINQ}:qpmax=${VIDEO_MAXQ}"
     FFMPEG_X264_PARAM=${FFMPEG_X264_PARAM2}${FFMPEG_X264_PARAM3}${FFMPEG_X264_PARAM4}
     FFMPEG_X264_AQ="-trellis 2 -partitions all  -8x8dct 1 -mbtree 1 -psy-rd 0.8:0.4"
     
     HW_SCALING="Yes"
     HWACCEL_DEC="vaapi"
     #HW_SCALING="No"
     #HWACCEL_DEC="NONE"
     FFMPEG_ENC=1
     HWENC=0
     HWDEC=0
   ;;
   ANIME_HIGH_HW )
     HWENC_PARAM="-profile:v main -level 51 \
		  -qp 24 -qmin 14 -qmax 28 \
		  -maxrate 12000k -minrate 100k \
		  -qcomp 0.80  -quality 0 -qdiff 6 \
		  -sc_threshold 38 \
		  -aspect 16:9"
     HW_SCALING="Yes"
     HWACCEL_DEC="vaapi"
     #HW_SCALING="No"
     #HWACCEL_DEC="NONE"
     FFMPEG_ENC=0
     HWENC=1
     HWDEC=0
     if test $USE_60FPS -ne 0 ; then
        #VIDEO_FILTERCHAIN_SCALE="scale=width=1280:height=720:flags=spline"
        VIDEO_FILTERCHAIN_VAAPI_HEAD="yadif=mode=send_field,format=nv12|vaapi,hwupload"
        VIDEO_FILTERCHAIN_VAAPI="scale_vaapi=w=1280:h=720"
     else
        VIDEO_FILTERCHAIN_VAAPI_HEAD="yadif,format=nv12|vaapi,hwupload"
        VIDEO_FILTERCHAIN_VAAPI="scale_vaapi=w=1280:h=720"
     fi
   ;;
   LIVE_HD_HIGH )
     X264_DIRECT="--direct auto --aq-mode 3"
     X264_BFRAMES="--bframes 6 --b-bias -2 --b-adapt 2 --psy-rd 0.5:0.2"
     X264_PRESETS="--profile high --keyint 300 --min-keyint 24 --scenecut 40 --trellis 2"
     X264_ENCPRESET="--preset slow --ref 6 --8x8dct --partitions all"
   ;;
   LIVE_HD_MID )
#     X264_DIRECT="--direct spatial"
#    X264_BFRAMES="--bframes 5 --b-bias -1 --b-adapt 2 --psy-rd 1.2:0.4"
#     X264_PRESETS="--profile high --keyint 300 --min-keyint 24 --scenecut 47 --trellis 2"
#     X264_ENCPRESET="--preset slow --ref 5 --8x8dct --partitions all"
     X264_DIRECT="--direct auto"
     X264_BFRAMES="--bframes 5 --b-bias -1 --b-adapt 2 --psy-rd 0.5:0.2"
     X264_PRESETS="--profile high --keyint 300 --min-keyint 24 --scenecut 45 --trellis 2"
     X264_ENCPRESET="--preset slow --ref 5 --8x8dct --partitions all" 
     
     FFMPEG_X264_HEAD="-profile:v high -preset slow -direct-pred auto -crf ${VIDEO_QUANT} -bluray-compat 1"
     FFMPEG_X264_FRAMES1="-b-pyramid strict  -b-bias -1 -me_method umh -weightp smart"
     FFMPEG_X264_PARAM2="-x264-params aq-mode=3:aq-strength=${VIDEO_AQSTRENGTH}:"
     FFMPEG_X264_PARAM3="qcomp=${VIDEO_QCOMP}:8x8dct=1:scenecut=45:ref=5:bframes=5:b-adapt=2:qpstep=12:"
     FFMPEG_X264_PARAM4="keyint=300:min-keyint=24:qpmin=${VIDEO_MINQ}:qpmax=${VIDEO_MAXQ}"
     FFMPEG_X264_PARAM=${FFMPEG_X264_PARAM2}${FFMPEG_X264_PARAM3}${FFMPEG_X264_PARAM4}
     FFMPEG_X264_AQ="-trellis 2 -partitions all  -8x8dct 1 -mbtree 1 -psy-rd 0.8:0.4"
     
     HW_SCALING="Yes"
     HWACCEL_DEC="vaapi"
     #HW_SCALING="No"
     #HWACCEL_DEC="NONE"
     FFMPEG_ENC=1
     HWENC=0
     HWDEC=0
   ;;
   LIVE_HD_MID_HW )
     HWENC_PARAM="-profile:v main -level 51 \
		 -qp 25 -qmin 10 -qmax 32 \
		 -maxrate 14500k -minrate 100k \
		 -sc_threshold 45 -qdiff 8 -qcomp 0.40 \
                 -bufsize 32768 \
		 -quality 0 -aspect 16:9"
#		 -qp 25 -qmin 10 -qmax 40 \
#		 -maxrate 16500k -minrate 100k \
     HW_SCALING="Yes"
     HWACCEL_DEC="vaapi"
     #HW_SCALING="No"
     #HWACCEL_DEC="NONE"
     FFMPEG_ENC=0
     HWENC=1
     HWDEC=0
     if test $TESTMODE -ne 0; then
     if test $USE_60FPS -ne 0 ; then
#        VIDEO_FILTERCHAIN_VAAPI_HEAD="yadif=mode=send_field,hqdn3d=luma_spatial=2.2:luma_tmp=1.8:chroma_spatial=2.3:chroma_tmp=2.1,format=nv12|vaapi,hwupload"
        VIDEO_FILTERCHAIN_VAAPI_HEAD="yadif=mode=send_field,atadenoise=s=7,format=nv12|vaapi,hwupload"
        VIDEO_FILTERCHAIN_VAAPI="scale_vaapi=w=1440:h=1080"
     else
#        VIDEO_FILTERCHAIN_VAAPI_HEAD="yadif,hqdn3d=luma_spatial=2.3:luma_tmp=2.0:chroma_spatial=2.4:chroma_tmp=2.2,format=nv12|vaapi,hwupload"
        VIDEO_FILTERCHAIN_VAAPI_HEAD="yadif,atadenoise=s=9,format=nv12|vaapi,hwupload"
        VIDEO_FILTERCHAIN_VAAPI="scale_vaapi=w=1440:h=1080"
     fi
     else
     if test $USE_60FPS -ne 0 ; then
#        VIDEO_FILTERCHAIN_VAAPI_HEAD="yadif=mode=send_field,hqdn3d=luma_spatial=2.2:luma_tmp=1.8:chroma_spatial=2.3:chroma_tmp=2.1,format=nv12|vaapi,hwupload"
        VIDEO_FILTERCHAIN_VAAPI_HEAD="yadif=mode=send_field,format=nv12|vaapi,hwupload"
        VIDEO_FILTERCHAIN_VAAPI="scale_vaapi=w=1440:h=1080"
     else
#        VIDEO_FILTERCHAIN_VAAPI_HEAD="yadif,hqdn3d=luma_spatial=2.3:luma_tmp=2.0:chroma_spatial=2.4:chroma_tmp=2.2,format=nv12|vaapi,hwupload"
        VIDEO_FILTERCHAIN_VAAPI_HEAD="yadif,format=nv12|vaapi,hwupload"
        VIDEO_FILTERCHAIN_VAAPI="scale_vaapi=w=1440:h=1080"
     fi
     fi
   ;;
   LIVE1 )
     X264_DIRECT="--direct auto"
     X264_BFRAMES="--bframes 5 --b-bias -1 --b-adapt 2"
   ;;
   LIVE_HIGH )
     X264_DIRECT="--direct spatial --aq-mode 3"
     X264_BFRAMES="--bframes 5 --b-bias -1 --b-adapt 2 --psy-rd 1.2:0.4"
     X264_PRESETS="--profile high --keyint 300 --min-keyint 24 --scenecut 42 --trellis 2"
     X264_ENCPRESET="--preset slow --ref 5 --8x8dct --partitions all"
     FFMPEG_X264_HEAD="-profile:v high -preset slow -direct-pred auto -crf ${VIDEO_QUANT}"
     FFMPEG_X264_FRAMES1="-b-pyramid strict  -b-bias -1 -me_method umh -weightp smart"
     FFMPEG_X264_PARAM2="-x264-params aq-mode=3:aq-strength=${VIDEO_AQSTRENGTH}:"
     FFMPEG_X264_PARAM3="qcomp=${VIDEO_QCOMP}:trellis=2:scenecut=40:ref=5:bframes=5:b-adapt=2:qpstep=12:"
     FFMPEG_X264_PARAM4="keyint=300:min-keyint=24:qpmin=${VIDEO_MINQ}:qpmax=${VIDEO_MAXQ}"
     FFMPEG_X264_PARAM=${FFMPEG_X264_PARAM2}${FFMPEG_X264_PARAM3}${FFMPEG_X264_PARAM4}
     FFMPEG_X264_AQ="-trellis 2 -partitions all  -8x8dct 1 -mbtree 1 -psy-rd 1.2:0.6"
     HWENC_PARAM=" -coder cavlc -qp 23 -quality 2"
     FFMPEG_ENC=1
     HWENC=0
     HWDEC=0
     #HW_SCALING="No"
     #HWACCEL_DEC="NONE"
     HW_SCALING="Yes"
     HWACCEL_DEC="vaapi"
     
   ;;
   LIVE_HIGH_HW )
     HWENC_PARAM=" \
                   -profile:v main -aud 1 -level 51  \
 		   -qp 26 -qmin 10 -qmax 35 \
		   -qcomp 0.30 -qdiff 10 \
		   -sc_threshold 55 \
		   -bf 4 \
		   -maxrate 6000k -minrate 100k -bufsize 8192 \
		   -quality 0 \
		   -aspect 16:9"
#		   -qmin 10 -qmax 35 \

    FFMPEG_ENC=0
     HWENC=1
     HWDEC=0
     #HW_SCALING="No"
     #HWACCEL_DEC="NONE"
     HW_SCALING="Yes"
     HWACCEL_DEC="vaapi"
     if test $USE_60FPS -ne 0 ; then
        VIDEO_FILTERCHAIN_VAAPI_HEAD="yadif=mode=send_field,format=nv12|vaapi,hwupload"
        VIDEO_FILTERCHAIN_VAAPI="scale_vaapi=w=1280:h=720"
     else
        VIDEO_FILTERCHAIN_VAAPI_HEAD="yadif,format=nv12|vaapi,hwupload"
        VIDEO_FILTERCHAIN_VAAPI="scale_vaapi=w=1280:h=720"
     fi
     
   ;;
   LIVE_SD_HIGH )
     X264_DIRECT="--direct spatial --aq-mode 3"
     X264_BFRAMES="--bframes 5 --b-bias -1 --b-adapt 2 --psy-rd 1.2:0.4"
     X264_PRESETS="--profile high --keyint 300 --min-keyint 24 --scenecut 42 --trellis 2"
     X264_ENCPRESET="--preset slow --ref 5 --8x8dct --partitions all"
     FFMPEG_X264_HEAD="-profile:v high -preset slow -direct-pred auto -crf ${VIDEO_QUANT}"
     FFMPEG_X264_FRAMES1="-b-pyramid strict  -b-bias -1 -me_method umh -weightp smart -sar 32/27"
     FFMPEG_X264_PARAM2="-x264-params aq-mode=3:aq-strength=${VIDEO_AQSTRENGTH}:"
     FFMPEG_X264_PARAM3="qcomp=${VIDEO_QCOMP}:trellis=2:scenecut=40:ref=5:bframes=5:b-adapt=2:qpstep=8:"
     FFMPEG_X264_PARAM4="keyint=300:min-keyint=24:qpmin=${VIDEO_MINQ}:qpmax=${VIDEO_MAXQ}"
     FFMPEG_X264_PARAM=${FFMPEG_X264_PARAM2}${FFMPEG_X264_PARAM3}${FFMPEG_X264_PARAM4}
     FFMPEG_X264_AQ="-trellis 2 -partitions all  -8x8dct 1 -mbtree 1 -psy-rd 1.0:0.6"
     HWENC_PARAM=" -coder cavlc -aspect 16:9 -qp 21 -quality 4 "
     FFMPEG_ENC=1
     HWENC=0
     HWDEC=0
     #HW_SCALING="No"
     #HWACCEL_DEC="none"
     HW_SCALING="Yes"
     HWACCEL_DEC="vaapi"
   ;;
   LIVE_SD_HIGH_HW )
     HWENC_PARAM=" \
                  -profile:v main -level 51 \
		  -qp 22 -qmin 15 -qmax 29 \
		  -qdiff 9 -qcomp 0.70 \
		  -sc_threshold 42 \
  		  -maxrate 3500k -minrate 70k -bufsize 32768 \
		  -quality 0 \
		  -aspect 16:9"
     FFMPEG_ENC=0
     HWENC=1
     HWDEC=0
     VIDEO_FILTERCHAIN_NOSCALE=0
     if test $USE_60FPS -ne 0 ; then
        VIDEO_FILTERCHAIN_VAAPI_HEAD="yadif=mode=send_field,format=nv12|vaapi,hwupload"
        VIDEO_FILTERCHAIN_VAAPI="scale_vaapi=w=640:h=480"
     else
        VIDEO_FILTERCHAIN_VAAPI_HEAD="yadif,format=nv12|vaapi,hwupload"
        VIDEO_FILTERCHAIN_VAAPI="scale_vaapi=w=640:h=480"
     fi
     #HW_SCALING="No"
     #HWACCEL_DEC="NONE"
     HW_SCALING="Yes"
     HWACCEL_DEC="vaapi"
     
   ;;
   LIVE_SD_MID_HW )
     HWENC_PARAM=" \
                  -profile:v main -level 51 -aud 1 \
		  -maxrate 900k -minrate 20k \
		  -qp 28 -qmin 21 -qmax 55 -qcomp 0.4 \
		  -quality 4 \
		  -aspect 16:9"
     HW_SCALING="Yes"
     HWACCEL_DEC="vaapi"
     #HW_SCALING="No"
     #HWACCEL_DEC="NONE"
     FFMPEG_ENC=1
     HWENC=0
     HWDEC=0
   ;;
   LIVE_MID )
     X264_DIRECT="--direct auto"
     X264_BFRAMES="--bframes 5 --b-bias 0 --b-adapt 2"
     X264_PRESETS="--profile high --keyint 300 --min-keyint 24 --scenecut 48 --trellis 2"
     X264_ENCPRESET="--preset medium --ref 5 --8x8dct"
     FFMPEG_X264_HEAD="-profile:v high -preset slow -direct-pred auto -crf ${VIDEO_QUANT}"
     FFMPEG_X264_FRAMES1="-b-pyramid strict  -b-bias 0 -me_method hex -weightp smart"
     FFMPEG_X264_PARAM2="-x264-params aq-mode=3:aq-strength=${VIDEO_AQSTRENGTH}:"
     FFMPEG_X264_PARAM3="qcomp=${VIDEO_QCOMP}:scenecut=48:ref=5:bframes=5:b-adapt=2:"
     FFMPEG_X264_PARAM4="keyint=300:min-keyint=24:qpmin=${VIDEO_MINQ}:qpmax=${VIDEO_MAXQ}:qpstep=8"
     FFMPEG_X264_PARAM=${FFMPEG_X264_PARAM2}${FFMPEG_X264_PARAM3}${FFMPEG_X264_PARAM4}
     FFMPEG_X264_AQ="-trellis 2 -partitions all  -8x8dct 1 -mbtree 1 -psy-rd 0.6:0.2"
     HWENC_PARAM="-qp 27 -quality 4"
     FFMPEG_ENC=1
     HWENC=0
     HWDEC=0
     #HW_SCALING="No"
     #HWACCEL_DEC="NONE"
     HW_SCALING="Yes"
     HWACCEL_DEC="vaapi"
   ;;
   LIVE_MID_HW )
     HWENC_PARAM="-profile:v main -level 51 \
                 -aud 1 \
		 -qp 30 -qmin 21 -qmax 58 -qcomp 0.40 \
		 -maxrate 1500k -minrate 55k -bufsize 32768 \
		 -sc_threshold 65 -qdiff 10 \
		 -quality 3 \
		 -aspect 16:9"
     FFMPEG_ENC=0
     HWENC=1
     HWDEC=0
     #HW_SCALING="No"
     #HWACCEL_DEC="NONE"
     HW_SCALING="Yes"
     HWACCEL_DEC="vaapi"
     
   ;;
   LIVE_LOW )
     X264_DIRECT="--direct auto --aq-mode 3"
     X264_BFRAMES="--bframes 8 --b-bias 0 --b-adapt 2"
     X264_PRESETS="--profile high --keyint 300 --min-keyint 24 --scenecut 40 --trellis 2"
     X264_ENCPRESET="--preset medium --8x8dct --partitions all"
   ;;
   LIVE_LOW_HW )
     HWENC_PARAM="-profile:v main -level 51 \
 		 -maxrate 1000k -minrate 50k \
                 -qp 35 -qmin 23 -qmax 51 \
		 -qcomp 0.3 -quality 4 \
		 -aspect 16:9"
     FFMPEG_ENC=0
     HWENC=1
     HWDEC=0
     #HW_SCALING="No"
     #HWACCEL_DEC="NONE"
     HW_SCALING="Yes"
     HWACCEL_DEC="vaapi"
     ;;
esac

if test $USEOPENCL -ne 0; then
   USECL="--opencl"
else
   USECL=""
fi
if test $FASTENC -ne 0; then
  X264_FASTENC="--fast-pskip"
else
  X264_FASTENC="--no-fast-pskip"
fi
if test $X264_BITRATE -gt 0; then
  X264_OPT_BITRATE="--bitrate $X264_BITRATE"
  else 
  X264_OPT_BITRATE=""
fi  
#ffmpeg -loglevel panic $VIDEO_SKIP -i "$DIRNAME2/$SRC2"  -acodec pcm_s16be -f s16be -ar 48000 -ac 2 -y $AUDIOTMP  >/dev/null &
if test $HWENC -eq 0; then
ffmpeg -loglevel panic $VIDEO_SKIP -i "$DIRNAME2/$SRC2"  -acodec aac -ab 224k -ar 48000 -ac 2 -y "$TEMPDIR/a1.aac"  >/dev/null &
DEC_AUDIO_PID=$!
#faac -w -b $AUDIOBITRATE -c $AUDIOCUTOFF -B 32 -P -R 48000 -C 2 $AUDIOTMP -o $TEMPDIR/a1.m4a >/dev/null 2>/dev/null &
#ENC_AUDIO_PID=$!
fi

if test $FFMPEG_ENC -eq 0; then
if test $HWENC -eq 0; then 
if test $VIDEO_FILTERCHAIN_NOSCALE -ne 1; then
   x264 --sar 1:1 $X264_ENCPRESET  $X264_OPT_BITRATE \
     $X264_QUANT  $X264_PRESETS $X264_FASTENC \
     $X264_AQPARAM $X264_ENCPARAM $X264_DIRECT $X264_BFRAMES $X264_FILTPARAM \
     --threads $ENCTHREADS $USECL -o $TEMPDIR/v1tmp.mp4 $VIDEOTMP  &
   ENC_VIDEO_PID=$!
else
   x264 --sar 4:3 $X264_ENCPRESET  $X264_OPT_BITRATE \
     $X264_QUANT  $X264_PRESETS $X264_FASTENC \
     $X264_AQPARAM $X264_ENCPARAM $X264_DIRECT $X264_BFRAMES $X264_FILTPARAM \
     --threads $ENCTHREADS $USECL -o $TEMPDIR/v1tmp.mp4 $VIDEOTMP  &
   ENC_VIDEO_PID=$!
fi
fi
fi

if test $VIDEO_FILTERCHAIN_NOSCALE -ne 1; then
#  VIDEO_FILTERCHAIN="$VIDEO_FILTERCHAIN0","$VIDEO_FILTERCHAINX","$VIDEO_FILTERCHAIN_SCALE"
  VIDEO_FILTERCHAIN="$VIDEO_FILTERCHAINX","$VIDEO_FILTERCHAIN_SCALE"
else
#  VIDEO_FILTERCHAIN="$VIDEO_FILTERCHAIN0","$VIDEO_FILTERCHAINX"
  VIDEO_FILTERCHAIN="$VIDEO_FILTERCHAINX"
fi
echo "Filter chain = $VIDEO_FILTERCHAIN" 

DECODE_APPEND=""
case "$HWACCEL_DEC" in
  "VDPAU" | "vdpau" )
  DECODE_APPEND="-hwaccel vdpau"
  if test $HWDEC -ne 0 ; then
    DECODE_APPEND="${DECODE_APPEND}"
   if test $VIDEO_FILTER_NOCROP -ne 0 ; then
      VIDEO_FILTERCHAIN_HWACCEL="-vf ${VIDEO_FILTERCHAINX}"
   else
      VIDEO_FILTERCHAIN_HWACCEL="-vf ${VIDEO_FILTERCHAIN0},${VIDEO_FILTERCHAINX}"
   fi
   if test $VIDEO_FILTERCHAIN_NOSCALE -eq 0; then
      VIDEO_FILTERCHAIN_SCALE_HWACCEL="${VIDEO_FILTERCHAIN_SCALE_HWACCEL},scale=width=1280:height=720:flags=lanczos"
   fi    
    VIDEO_FILTERCHAIN_HWACCEL="${DECODE_APPEND} ${VIDEO_FILTERCHAIN_HWACCEL}"
  else
    VIDEO_FILTERCHAIN_HWACCEL="-vf ${VIDEO_FILTERCHAIN}"
  fi
  #echo "vdpau"
  ;;
  "VAAPI" | "vaapi" )
  HWDECODE_TAG=VAAPI_${MYPID}
  DECODE_APPEND="-vaapi_device:${HWDECODE_TAG} /dev/dri/renderD128" 
  if test $HWDEC -ne 0 ; then
    DECODE_APPEND="${DECODE_APPEND} -hwaccel:${HWDECODE_TAG} vaapi -hwaccel_output_format vaapi"
    VIDEO_FILTERCHAIN_HWACCEL="${VIDEO_FILTERCHAIN_VAAPI}"
    if test $FFMPEG_ENC -ne 0; then
       VIDEO_FILTERCHAIN_HWACCEL="${VIDEO_FILTERCHAIN_VAAPI_HEAD},${VIDEO_FILTERCHAIN_HWACCEL},hwdownload,format=yuv420p"
    fi
    VIDEO_FILTERCHAIN_HWACCEL="-filter_complex ${VIDEO_FILTERCHAIN_HWACCEL}"
  else
    VIDEO_FILTERCHAIN_HWACCEL="-filter_complex ${VIDEO_FILTERCHAIN_VAAPI_HEAD},${VIDEO_FILTERCHAIN_VAAPI},${VIDEO_FILTERCHAIN_VAAPI_TAIL}"
  fi
  VIDEO_FILTERCHAIN_HWACCEL_HEAD=${VIDEO_FILTERCHAIN_VAAPI_HEAD}
  VIDEO_FILTERCHAIN_HWACCEL_TAIL=${VIDEO_FILTERCHAIN_VAAPI_TAIL}
   if test $HWENC -ne 0 ; then 
      VIDEO_FILTERCHAIN_HWACCEL="-filter_complex ${VIDEO_FILTERCHAIN_VAAPI_HEAD},${VIDEO_FILTERCHAIN_VAAPI}"
   fi
  #echo "vaapi"
  ;;
  *)
   if test $HWENC -ne 0 ; then 
      VIDEO_FILTERCHAIN_HWACCEL="-filter_complex ${VIDEO_FILTERCHAIN_VAAPI_HEAD},${VIDEO_FILTERCHAIN_VAAPI}"
   else
      if test $VIDEO_FILTER_NOCROP -ne 0 ; then
         VIDEO_FILTERCHAIN_HWACCEL="-vf ${VIDEO_FILTERCHAINX}"
      else
         VIDEO_FILTERCHAIN_HWACCEL="-vf ${VIDEO_FILTERCHAIN0},${VIDEO_FILTERCHAINX}"
#         VIDEO_FILTERCHAIN_HWACCEL="-vf ${VIDEO_FILTERCHAINX}"
      fi
      if test $VIDEO_FILTERCHAIN_NOSCALE -eq 0 ; then
        VIDEO_FILTERCHAIN_HWACCEL="${VIDEO_FILTERCHAIN_HWACCEL},${VIDEO_FILTERCHAIN_SCALE}"
      fi
   fi
   ;;
esac
#FFMPEG_X264_PARAM=${FFMPEG_X264_PARAM}:threads=${ENCTHREADS}  
if test $FFMPEG_ENC -ne 0; then
    ffmpeg -loglevel info $VIDEO_SKIP $DECODE_APPEND -i "$DIRNAME2/$SRC2" -r 30000/1001 -aspect 16:9 \
    $VIDEO_FILTERCHAIN_HWACCEL \
    -c:v libx264 \
    -an \
    $FFMPEG_X264_HEAD \
    $FFMPEG_X264_FRAMES1 \
    $FFMPEG_X264_AQ \
    $FFMPEG_X264_PARAM \
    -filter_complex_threads 8 \
    -filter_threads 8 \
    -threads ${ENCTHREADS} \
    -f mp4 \
    $ARG_METADATA \
    -y $TEMPDIR/v1tmp.mp4  &

#    -filter_complex_threads 4 -filter_threads 4 \

elif test $HWENC -ne 0; then
logging ${ARG_METADATA}
    ffmpeg $VIDEO_SKIP $DECODE_APPEND -i "$DIRNAME2/$SRC2" \
    -r:v ${FRAMERATE} \
    $VIDEO_FILTERCHAIN_HWACCEL \
    -c:v hevc_vaapi \
    -filter_complex_threads 16 -filter_threads 16 \
    $HWENC_PARAM \
    -threads:0 4 \
    -c:a aac \
    -threads:1 4 \
    -r:v ${FRAMERATE} \
    -ab 224k -ar 48000 -ac 2 \
    -f mp4 \
    $ARG_METADATA \
    -y $TEMPDIR/v1tmp.mp4  \
    &
#    -c:v hevc_vaapi \

else
#ffmpeg -i "$DIRNAME2/$SRC2" -r 30000/1001 -aspect 16:9 -acodec null -vcodec rawvideo -f yuv4mpegpipe -vf $VIDEO_FILTERCHAIN -y $VIDEOTMP &
case "$HW_SCALING" in
  "Yes" | "yes" | "YES" )
    ffmpeg -loglevel panic $VIDEO_SKIP $DECODE_APPEND -i "$DIRNAME2/$SRC2" -r 30000/1001 -aspect 16:9 \
    -filter_complex_threads 16 -filter_threads 16 \
    -threads 4 \
    -f yuv4mpegpipe \
    $VIDEO_FILTERCHAIN_HWACCEL \
    -y $VIDEOTMP &
  ;;
  "No" | "no" | "NO" | "*")
    ffmpeg -loglevel panic $VIDEO_SKIP $DECODE_APPEND -i "$DIRNAME2/$SRC2" -r 30000/1001 -aspect 16:9  \
    -filter_complex_threads 16 -filter_threads 16 \
    -threads 4 \
    -f yuv4mpegpipe \
    -vf $VIDEO_FILTERCHAIN_HWACCEL \
    -y $VIDEOTMP &
;;
esac
fi

DEC_VIDEO_PID=$!

if test $HWENC -eq 0; then 
wait $DEC_AUDIO_PID
fi
#RESULT_DEC_AUDIO=$?

#wait $ENC_AUDIO_PID
#RESULT_ENC_AUDIO=$?

wait $DEC_VIDEO_PID
RESULT_DEC_VIDEO=$?


if test $HWENC -eq 0; then 
wait $ENC_VIDEO_PID
RESULT_ENC_VIDEO=$?
fi
fi

# Demux files to one video
ERRFLAGS=0
#if test $HWENC -eq 0; then
#if test $RESULT_DEC_AUDIO -ne 0 ; then
#  logging "Error: Error on decoding AUDIO."
#  ERRFLAGS=1
#fi
#fi
#if test $RESULT_ENC_AUDIO -ne 0 ; then
#  echo "Error: Error on encoding AUDIO."
#  ERRFLAGS=1
#fi
if test $RESULT_DEC_VIDEO -ne 0 ; then
  logging "Error: Error on decoding AUDIO."
  ERRFLAGS=1
fi

if test $FFMPEG_ENC -eq 0; then
if test $HWENC -eq 0; then 
if test $RESULT_ENC_VIDEO -ne 0 ; then
  logging "Error: Error on encoding AUDIO."
  ERRFLAGS=1
fi
fi
fi

if test $ERRFLAGS -ne 0; then
  cd ../..
  rm -rf $TEMPDIR
  logging "ERROR ${ERRFLAGS}"
  exit 2
fi

touch "$DIRNAME/test$BASENAME"
if [ ! -w "$DIRNAME/test$BASENAME" ] ; then 
   logging "Unable to Write encoded movie."
   exit 3
fi
rm "$DIRNAME/test$BASENAME"

if test $HWENC -ne 0; then
  #MP4Box -add $TEMPDIR/v1tmp.mp4 -add $TEMPDIR/a1.aac -new "$DIRNAME/$BASENAME"
  cp "$TEMPDIR/v1tmp.mp4" "$DIRNAME/$BASENAME"
#  ffmpeg \
#    -i "$TEMPDIR/v1tmp.mp4" \
#    -c:a copy -c:v copy \
#    -f mp4 \
#    $ARG_METADATA \
#    -y "$DIRNAME/$BASENAME"
#    echo "$DIRNAME/$BASENAME"
else
  MP4Box -add $TEMPDIR/v1tmp.mp4 -add $TEMPDIR/a1.aac -new "$DIRNAME/$BASENAME"
fi

RESULT_DEMUX=$?
#/if test $RESULT_DEMUX -ne 0; then
#  echo "Errror on DEMUXing."
#  cd ../..
#  rm -rf $TEMPDIR
#  exit 3
#fi



# update the database to point to the transcoded file and delete the original recorded show.
NEWFILESIZE=`du -b "$DIRNAME/$BASENAME" | cut -f1`
if test $NEWFILESIZE -le 0 ; then
  logging "Unknown Errot."
exit 4
fi

if test $USE_DATABASE -ne 0 ; then
  echo "UPDATE recorded SET basename='$BASENAME',filesize='$NEWFILESIZE',transcoded='1' WHERE chanid='$I_CHANID' AND starttime='$I_STARTTIME';" > update-database_$MYPID.sql
  logging `cat update-database_$MYPID.sql`
  logging `mysql -v -v -v --user=$DATABASEUSER --password=$DATABASEPASSWORD mythconverg < update-database_$MYPID.sql`
fi

# Remove 
if test $REMOVE_SOURCE -ne 0; then
 rm -f $SRC
 rm -f $SRC.-1.160x120.png
 rm -f $SRC.-1.100x75.png
 rm -f $SRC.png
 rm -f $SRC.tmp
fi
# cleanup temp files
sync
sleep 2
cd $TEMPDIR/..
rm -rf $TEMPDIR
logging "JOB COMPLETED."
exit 0
