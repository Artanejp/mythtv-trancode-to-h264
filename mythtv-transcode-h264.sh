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
LOOKAHEAD_THREADS=8
FILTER_THREADS=8
FILTER_COMPLEX_THREADS=8
VIDEO_MINQ=14
VIDEO_MAXQ=33
VIDEO_QUANT=22

VIDEO_AQSTRENGTH="1.1"
VIDEO_QCOMP="0.55"

VIDEO_SCENECUT=48
VIDEO_REF_FRAMES=3
VIDEO_BFRAMES=6
#X264_BITRATE=2500

CMCUT=0
REMOVE_SOURCE=0
FASTENC=0
HWACCEL_DEC="NONE"
VIDEO_FILTERCHAIN_NOSCALE=0
VIDEO_FILTER_NOCROP=0

X264_ENCPRESET="--preset slower --8x8dct --partitions all"
X264_BITRATE="2000"

VIDEO_SKIP="-ss 15"

FFMPEG_ENC=1
HWENC=0
HWDEC=0
HW_SCALING="No"

N_QUERY_ID=0;

FFMPEG_CMD="/usr/bin/ffmpeg"
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
IS_HWENC_USE_HEVC=1

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
    --threads | --thread | -thread | -threads )
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
    --live_hd_mid_hw2 | --live-hd-mid-hw2)
    # for Live, HD, high quality.
    shift
    ENCMODE="LIVE_HD_MID_HW2"
    IS_HWENC_USE_HEVC=0
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
    --live_sd_high_hw2 | --live-sd-high-hw2 )
    # for Live, middle quality.
    shift
    ENCMODE="LIVE_SD_HIGH_HW2"
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
s/&/＆/g
s/\&/＆/g
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

#"
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
   "ANIME_HIGH_HW" | "LIVE_HIGH_HW" | "LIVE_HD_HIGH_HW" )
   AUDIOBITRATE=224
   AUDIOCUTOFF=22050
   ;;
   "LIVE_HD_MID_HW2" | "LIVE_SD_HIGH_HW2"  | "LIVE_HD_MID_HW" | "LIVE_SD_HIGH_HW" )
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
VIDEO_FILTERCHAINX=""
VIDEO_FILTERCHAIN_DEINT="yadif"
VIDEO_FILTERCHAIN_SCALE="scale=width=1280:height=720:flags=lanczos"

VIDEO_FILTERCHAIN_VAAPI_HEAD="format=nv12|vaapi,hwupload"
VIDEO_FILTERCHAIN_VAAPI_TAIL="hwdownload,format=yuv420p"
VAAPI_SCALER_MODE="default"

OUT_WIDTH=1280
OUT_HEIGHT=720
SCALER_MODE="bilinear"

#X264_FILTPARAM="--vf resize:width=1280,height=720,method=lanczos"
X264_FILTPARAM=""
# Live video (low motion)

X264_BITRATE=0
IS_CONSTANT_QUALITY=0
#Determine override presets when set to mode
x=$ENCMODE


case "$x" in
   "ANIME" | "ANIME_HW" )
   VIDEO_QUANT=24
   VIDEO_MINQ=15
   VIDEO_MAXQ=28
   VIDEO_AQSTRENGTH=0.65
   VIDEO_QCOMP=0.70
   OUT_WIDTH=1280
   OUT_HEIGHT=720
   SCALER_MODE="spline"
   VIDEO_FILTERCHAINX="hqdn3d=luma_spatial=2.7:chroma_spatial=2.2:luma_tmp=2.5:chroma_tmp=2.5"
   VIDEO_FILTERCHAIN_NOCROP=1
   X264_BITRATE="2500"
   #X264_FILTPARAM="--vf resize:width=1280,height=720,method=bicubic"
   ;;
   "ANIME_HIGH" | "ANIME_HIGH_HW" )
   VIDEO_QUANT=23
   VIDEO_MINQ=14
   VIDEO_MAXQ=28
   VIDEO_AQSTRENGTH=0.36
   VIDEO_QCOMP=0.88
   VIDEO_SCENECUT=38
   VIDEO_REF_FRAMES=3
   VIDEO_BFRAMES=4
   #VIDEO_FILTERCHAINX="yadif,hqdn3d=luma_spatial=2.5:chroma_spatial=2.7:luma_tmp=2.8:chroma_tmp=2.9"
   VIDEO_FILTERCHAINX=""
   OUT_WIDTH=1280
   OUT_HEIGHT=720
   SCALER_MODE="spline"
   VIDEO_FILTERCHAIN_NOCROP=1

   ;;
   "LIVE1" )
   VIDEO_QUANT=23
   VIDEO_MINQ=17
   VIDEO_MAXQ=37
   VIDEO_AQSTRENGTH=1.00
   VIDEO_QCOMP=0.65
   VIDEO_SCENECUT=45
   VIDEO_REF_FRAMES=3
   VIDEO_BFRAMES=3
   X264_BITRATE=2500
   OUT_WIDTH=1280
   OUT_HEIGHT=720
   SCALER_MODE="lanczos"
   VIDEO_FILTERCHAINX="hqdn3d=luma_spatial=4.2:chroma_spatial=3.2:luma_tmp=3.8:chroma_tmp=3.8"
   VIDEO_FILTERCHAIN_NOCROP=1
   ;;
   "LIVE_HD_MID" | "LIVE_HD_MID_HW" | "LIVE_HD_MID_HW2" )
   VIDEO_QUANT=23
   VIDEO_MINQ=12
   VIDEO_MAXQ=35
   VIDEO_AQSTRENGTH=0.48
   VIDEO_QCOMP=0.70
   VIDEO_SCENECUT=60
   VIDEO_REF_FRAMES=3
   VIDEO_BFRAMES=4
   OUT_WIDTH=1280
   OUT_HEIGHT=720
   SCALER_MODE="bilinear"
   
   #X264_BITRATE=3500
   #VIDEO_FILTERCHAINX="yadif,hqdn3d=luma_spatial=3.0:chroma_spatial=3.0:luma_tmp=2.8:chroma_tmp=2.7"
   VIDEO_FILTERCHAINX=""

   VIDEO_FILTERCHAIN_NOCROP=1
   VIDEO_FILTERCHAIN_NOSCALE=1
   ;;
   "LIVE_HD_HIGH" | "LIVE_HD_HIGH_HW" )
   VIDEO_QUANT=23
   VIDEO_MINQ=14
   VIDEO_MAXQ=33
   VIDEO_AQSTRENGTH=0.75
   VIDEO_QCOMP=0.85
   VIDEO_SCENECUT=45
   VIDEO_REF_FRAMES=5
   VIDEO_BFRAMES=4
   OUT_WIDTH=1440
   OUT_HEIGHT=1080
   SCALER_MODE="spline"
   #X264_BITRATE=3500
#   VIDEO_FILTERCHAINX="hqdn3d=luma_spatial=2.5:chroma_spatial=2.4:luma_tmp=3.1:chroma_tmp=3.0"
   VIDEO_FILTERCHAINX=""
   VIDEO_FILTERCHAIN_NOSCALE=1
   VIDEO_FILTERCHAIN_NOCROP=1

   ;;
   "LIVE_HIGH" | "LIVE_HIGH_HW" )
   VIDEO_QUANT=23
   VIDEO_MINQ=12
   VIDEO_MAXQ=34
   VIDEO_AQSTRENGTH=1.05
   VIDEO_QCOMP=0.70
   VIDEO_SCENECUT=42
   VIDEO_REF_FRAMES=5
   VIDEO_BFRAMES=5
   OUT_WIDTH=1280
   OUT_HEIGHT=720
   SCALER_MODE="lanczos"
   
   #X264_BITRATE=3500
   VIDEO_FILTERCHAINX=""
   #VIDEO_FILTERCHAINX="yadif,hqdn3d=luma_spatial=4.2:chroma_spatial=3.2:luma_tmp=3.8:chroma_tmp=3.8"
   VIDEO_FILTERCHAIN_NOCROP=1
   #VIDEO_FILTERCHAIN_VAAPI_TAIL="hwdownload"
   ;;
   "LIVE_SD_HIGH" | "LIVE_SD_HIGH_HW" | "LIVE_SD_HIGH_HW2" )
   VIDEO_QUANT=21
   VIDEO_MINQ=12
   VIDEO_MAXQ=27
   VIDEO_AQSTRENGTH=0.95
   VIDEO_QCOMP=0.75
   VIDEO_SCENECUT=40
   VIDEO_REF_FRAMES=5
   VIDEO_BFRAMES=5
   OUT_WIDTH=640
   OUT_HEIGHT=480
   SCALER_MODE="lanczos"
   
  #X264_BITRATE=3500
   VIDEO_FILTERCHAIN0="crop=out_w=640:out_h=480:y=480:keep_aspect=1,"
   VIDEO_FILTERCHAINX=""
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
   VIDEO_SCENECUT=48
   VIDEO_REF_FRAMES=3
   VIDEO_BFRAMES=6
   OUT_WIDTH=1280
   OUT_HEIGHT=720
   SCALER_MODE="bilinear"
   
   #X264_BITRATE="1800"
   #VIDEO_FILTERCHAINX="yadif,hqdn3d=luma_spatial=4.7:chroma_spatial=3.5:luma_tmp=4.2:chroma_tmp=4.2"
   VIDEO_FILTERCHAINX=""
   VIDEO_FILTERCHAIN_NOSCALE=0
   VIDEO_FILTERCHAIN_NOCROP=1
   
   ;;
   "LIVE_LOW" | "LIVE_LOW_HW" )
   VIDEO_QUANT=30
   VIDEO_MINQ=19
   VIDEO_MAXQ=59
   VIDEO_AQSTRENGTH=1.90
   VIDEO_QCOMP=0.35
   VIDEO_SCENECUT=48
   VIDEO_REF_FRAMES=3
   VIDEO_BFRAMES=6
#   X264_BITRATE=1100
   OUT_WIDTH=1280
   OUT_HEIGHT=720
   SCALER_MODE="bilinear"
   
   VIDEO_FILTERCHAINX="hqdn3d=luma_spatial=5.0:chroma_spatial=3.9:luma_tmp=4.7:chroma_tmp=4.7"
   VIDEO_FILTERCHAIN_NOCROP=1
   ;;
esac



if test $USE_60FPS -eq 0 ; then
   FRAMERATE=30000/1001
   VIDEO_FILTERCHAIN_DEINT="yadif"
else
   FRAMERATE=60000/1001
   VIDEO_FILTERCHAIN_DEINT="yadif=mode=send_field"
fi

VIDEO_FILTERCHAIN_VAAPI_SCALE="scale=width=${OUT_WIDTH}:height=${OUT_WIDTH}:mode=${VAAPI_SCALER_MODE}"
VIDEO_FILTERCHAIN_SCALE="scale=w=${OUT_WIDTH}:h=${OUT_HEIGHT}:flags=${SCALER_MODE}"


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
     FFMPEG_X264_AQ="-trellis 2 -partitions all  -8x8dct 1 -mbtree 1 -psy-rd 0.8:0.4"
     
     #HW_SCALING="Yes"
     #HWACCEL_DEC="vaapi"
     HW_SCALING="No"
     HWACCEL_DEC="NONE"
     FFMPEG_ENC=1
     HWENC=0
     HWDEC=0
   ;;
   ANIME_HIGH_HW )
     HWENC_PARAM="-profile:v main -level 51 \
		  -quality 0	\
		  -qp 22 -qmin 10 -qmax 27 \
		  -qcomp 0.75   -qdiff 8 \
		  -sc_threshold 38 \
		  -bufsize 32768 \
		  -aspect 16:9"
#		  -maxrate 12000k -minrate 100k \
     HW_SCALING="Yes"
     HWACCEL_DEC="vaapi"
     #HW_SCALING="No"
     #HWACCEL_DEC="NONE"
     FFMPEG_ENC=0
     HWENC=1
     HWDEC=0
     IS_HWENC_USE_HEVC=0
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
     FFMPEG_X264_AQ="-trellis 2 -partitions all  -8x8dct 1 -mbtree 1 -psy-rd 0.8:0.4"
     
     #HW_SCALING="No"
     #HWACCEL_DEC="vaapi"
     HW_SCALING="No"
     HWACCEL_DEC="NONE"
     FFMPEG_ENC=1
     HWENC=0
     HWDEC=0
   ;;
   LIVE_HD_MID_HW )
      HWENC_PARAM="-profile:v main -level 51 \
		 -crf 25 -qmin 12 -qmax 35 \
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
   ;;
   LIVE_HD_MID_HW2 )
     VIDEO_QCOMP=0.40
     HWENC_PARAM="-profile:v main -level 51 \
		 -crf ${VIDEO_QUANT} -qmin ${VIDEO_MINQ} -qmax ${VIDEO_MAXQ} \
		 -sc_threshold ${VIDEO_SCENECUT} -qdiff 8 -qcomp ${VIDEO_QCOMP} \
                 -bufsize 32768 \
		  -aspect 16:9"
#		 -quality 0 -aspect 16:9"
#		 -crf 24 -qmin 10 -qmax 39 \
#		 -qp 25 -qmin 10 -qmax 36 \
#		 -maxrate 14500k -minrate 100k \
#		 -maxrate 16500k -minrate 100k \
     HW_SCALING="Yes"
     HWACCEL_DEC="vaapi"
     #HW_SCALING="No"
     #HWACCEL_DEC="NONE"
     FFMPEG_ENC=0
     HWENC=1
     HWDEC=0
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
     FFMPEG_X264_AQ="-trellis 2 -partitions all  -8x8dct 1 -mbtree 1 -psy-rd 1.2:0.6"
     HWENC_PARAM=" -coder cavlc -qp 23 -quality 2"
     FFMPEG_ENC=1
     HWENC=0
     HWDEC=0
     #HW_SCALING="No"
     HWACCEL_DEC="NONE"
     HW_SCALING="Yes"
     #HWACCEL_DEC="vaapi"
     
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
   ;;
   LIVE_SD_HIGH )
     X264_DIRECT="--direct spatial --aq-mode 3"
     X264_BFRAMES="--bframes 5 --b-bias -1 --b-adapt 2 --psy-rd 1.2:0.4"
     X264_PRESETS="--profile high --keyint 300 --min-keyint 24 --scenecut 42 --trellis 2"
     X264_ENCPRESET="--preset slow --ref 5 --8x8dct --partitions all"
     FFMPEG_X264_HEAD="-profile:v high -preset slow -direct-pred auto -crf ${VIDEO_QUANT}  -sar 32/27"
     FFMPEG_X264_FRAMES1="-b-pyramid strict  -b-bias -1 -me_method umh -weightp smart"
     FFMPEG_X264_AQ="-trellis 2 -partitions all  -8x8dct 1 -mbtree 1 -psy-rd 1.0:0.6"
     HWENC_PARAM=" -coder cavlc -aspect 16:9 -qp 21 -quality 4 "
     HW_SCALING="No"
     HWACCEL_DEC="NONE"
     FFMPEG_ENC=1
     HWENC=0
     HWDEC=0
   ;;
   LIVE_SD_HIGH_HW )
     HWENC_PARAM=" \
                  -profile:v main -level 51 \
		  -qp 22 -qmin 10 -qmax 28 \
		  -qdiff 9 -qcomp 0.70 \
		  -sc_threshold 38 \
		  -quality 0 \
		  -aspect 16:9"
#		  -rc_mode auto \
#		  -b_depth 3 \
#		  -qp 22 -qmin 10 -qmax 28 \
#  		  -maxrate 3500k -minrate 70k -bufsize 32768 \
		  
    IS_HWENC_USE_HEVC=0
     FFMPEG_ENC=0
     HWENC=1
     HWDEC=0
     VIDEO_FILTERCHAIN_NOSCALE=0
     #HW_SCALING="No"
     #HWACCEL_DEC="NONE"
     HW_SCALING="Yes"
     HWACCEL_DEC="vaapi"
     
   ;;
   LIVE_SD_HIGH_HW2 )
     HWENC_PARAM=" \
                  -profile:v main -level 51 \
		  -qp 22 -qmin 15 -qmax 28 \
		  -qdiff 9 -qcomp 0.70 \
		  -sc_threshold 40 \
		  -rc_mode auto \
		  -b_depth 4 \
  		  -bufsize 32768 \
		  -quality 0 \
		  -aspect 16:9"
		  # -qp 22
#  		  -maxrate 3500k -minrate 70k -bufsize 32768 
     FFMPEG_ENC=0
     HWENC=1
     HWDEC=0
     VIDEO_FILTERCHAIN_NOSCALE=0
     HW_SCALING="Yes"
     HWACCEL_DEC="vaapi"
     #HWACCEL_DEC="NONE"
     IS_HWENC_USE_HEVC=1
   ;;
   LIVE_SD_MID_HW )
     HWENC_PARAM=" \
                  -profile:v main -level 51 -aud 1 \
		  -maxrate 900k -minrate 20k \
		  -qp 28 -qmin 21 -qmax 55 -qcomp 0.4 \
		  -quality 4 \
		  -aspect 16:9"
     HW_SCALING="Yes"
     #HWACCEL_DEC="vaapi"
     #HW_SCALING="No"
     HWACCEL_DEC="NONE"
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
     FFMPEG_X264_AQ="-trellis 2 -partitions all  -8x8dct 1 -mbtree 1 -psy-rd 0.6:0.2"
     HWENC_PARAM="-qp 27 -quality 4"
     FFMPEG_ENC=1
     HWENC=0
     HWDEC=0
     HW_SCALING="No"
     HWACCEL_DEC="NONE"
     #HW_SCALING="Yes"
     #HWACCEL_DEC="vaapi"
   ;;
   LIVE_MID_HW )
     FFMPEG_ENC=0
     HWENC=1
     HWDEC=0
     #HW_SCALING="No"
     #HWACCEL_DEC="NONE"
     HW_SCALING="Yes"
     HWACCEL_DEC="vaapi"
     HWENC_PARAM=" \
                   -profile:v main -aud 1 -level 51  \
 		   -qp 30 -qmin 21 -qmax 58 \
		   -qcomp 0.40 -qdiff 10 \
		   -sc_threshold 65 \
		   -bf 4 \
		   -maxrate 1500k -minrate 55k -bufsize 8192 \
		   -quality 2 \
		   -aspect 16:9"
#		   -qmin 10 -qmax 35 \
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


#FFMPEG_X264_HEAD="-profile:v high -preset slow -direct-pred auto -crf ${VIDEO_QUANT}"

FFMPEG_X264_FRAMES1="-b-pyramid strict  -b-bias -1 -me_method umh -weightp smart"
FFMPEG_X264_PARAM2="8x8dct=1:aq-mode=3:aq-strength=${VIDEO_AQSTRENGTH}:"
FFMPEG_X264_PARAM3="trellis=2:scenecut=${VIDEO_SCENECUT}:ref=${VIDEO_REF_FRAMES}:bframes=${VIDEO_BFRAMES}:b-adapt=2:"
FFMPEG_X264_PARAM4="keyint=300:min-keyint=24:qpmin=${VIDEO_MINQ}:qpmax=${VIDEO_MAXQ}:qcomp=${VIDEO_QCOMP}:qpstep=8"

if test $IS_CONSTANT_QUALITY -ne 0; then
   FFMPEG_X264_QP_PARAM="qp=${VIDEO_QUANT}:"
else
   FFMPEG_X264_QP_PARAM=""
fi


if test $USEOPENCL -ne 0; then
   USECL="--opencl"
   FFMPEG_X264_USE_OPENCL=":opencl=1:lookahead_threads=`expr ${LOOKAHEAD_THREADS} \* 1`:sync_lookahead=`expr ${LOOKAHEAD_THREADS} \* 2`"
else
   USECL=""
   FFMPEG_X264_USE_OPENCL=":lookahead_threads=`expr ${LOOKAHEAD_THREADS} \* 1`:sync_lookahead=`expr ${LOOKAHEAD_THREADS} \* 1`"
#   FFMPEG_X264_USE_OPENCL=""
fi

FFMPEG_X264_PARAM=${FFMPEG_X264_PARAM2}${FFMPEG_X264_PARAM3}${FFMPEG_X264_QP_PARAM}${FFMPEG_X264_PARAM4}${FFMPEG_X264_USE_OPENCL}


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

if test $VIDEO_FILTERCHAIN_NOSCALE -eq 0; then
    #  VIDEO_FILTERCHAIN="$VIDEO_FILTERCHAIN0","$VIDEO_FILTERCHAINX","$VIDEO_FILTERCHAIN_SCALE"
#    if test -n ${VIDEO_FILTERCHAINX} ; then
#	VIDEO_FILTERCHAIN="${VIDEO_FILTERCHAIN_DEINT},${VIDEO_FILTERCHAINX}","$VIDEO_FILTERCHAIN_SCALE"
#	VIDEO_FILTERCHAIN_HWACCEL="${VIDEO_FILTERCHAIN_DEINT},${VIDEO_FILTERCHAINX},${VIDEO_FILTERCHAIN_SCALE},${VIDEO_FILTERCHAIN_VAAPI_HEAD}"
#    else
	VIDEO_FILTERCHAIN="${VIDEO_FILTERCHAIN_DEINT}","$VIDEO_FILTERCHAIN_SCALE"
	VIDEO_FILTERCHAIN_HWACCEL="${VIDEO_FILTERCHAIN_DEINT},${VIDEO_FILTERCHAIN_SCALE},${VIDEO_FILTERCHAIN_VAAPI_HEAD}"
#    fi
else
    # Not scaling
#    if test -n ${VIDEO_FILTERCHAINX} ; then
#	VIDEO_FILTERCHAIN="${VIDEO_FILTERCHAIN_DEINT},${VIDEO_FILTERCHAINX}"
#	VIDEO_FILTERCHAIN_HWACCEL="${VIDEO_FILTERCHAIN_DEINT},${VIDEO_FILTERCHAINX},${VIDEO_FILTERCHAIN_SCALE},${VIDEO_FILTERCHAIN_VAAPI_HEAD}"
#    else
	VIDEO_FILTERCHAIN="${VIDEO_FILTERCHAIN_DEINT}"
	VIDEO_FILTERCHAIN_HWACCEL="${VIDEO_FILTERCHAIN_DEINT},${VIDEO_FILTERCHAIN_VAAPI_HEAD}"
#    fi
fi
echo "Filter chain = $VIDEO_FILTERCHAIN" 
if test $VIDEO_FILTERCHAIN_NOCROP -eq 0 ; then
    VIDEO_FILTERCHAIN="${VIDEO_FILTERCHAIN0},${VIDEO_FILTERCHAIN}"
    VIDEO_FILTERCHAIN_HWACCEL="${VIDEO_FILTERCHAIN0},${VIDEO_FILTERCHAIN_HWACCEL}"
fi
echo "Filter chain = $VIDEO_FILTERCHAIN" 

DECODE_APPEND=""


case "$HWACCEL_DEC" in
    "VDPAU" | "vdpau" )
	DECODE_APPEND="-hwaccel vdpau"
	;;
  "VAAPI" | "vaapi" )
      HWDECODE_TAG=VAAPI_${MYPID}
      DECODE_APPEND="-vaapi_device:${HWDECODE_TAG} /dev/dri/renderD128" 
      if test $HWDEC -ne 0 ; then
	  DECODE_APPEND="${DECODE_APPEND} -hwaccel:${HWDECODE_TAG} vaapi -hwaccel_output_format vaapi"
	  if test $FFMPEG_ENC -ne 0; then
	      VIDEO_FILTERCHAIN_HWACCEL="${VIDEO_FILTERCHAIN_VAAPI_HEAD},hwdownload,format=yuv420p"
	  fi
	  VIDEO_FILTERCHAIN_HWACCEL="-filter_complex ${VIDEO_FILTERCHAIN_HWACCEL}"
      else
	  VIDEO_FILTERCHAIN_HWACCEL="-filter_complex ${VIDEO_FILTERCHAIN_HWACCEL}"
      fi
      VIDEO_FILTERCHAIN_HWACCEL_HEAD=${VIDEO_FILTERCHAIN_VAAPI_HEAD}
      VIDEO_FILTERCHAIN_HWACCEL_TAIL=${VIDEO_FILTERCHAIN_VAAPI_TAIL}
      #echo "vaapi"
      ;;
  *)
      if test $HWENC -ne 0 ; then 
	  VIDEO_FILTERCHAIN_HWACCEL="-filter_complex ${VIDEO_FILTERCHAIN_HWACCEL}"
      else
          VIDEO_FILTERCHAIN_HWACCEL="-vf ${VIDEO_FILTERCHAIN}"
      fi
      ;;
esac


echo ${VIDEO_FILTERCHAIN_HWACCEL}
#FFMPEG_X264_PARAM=${FFMPEG_X264_PARAM}:threads=${ENCTHREADS}  

if test $FFMPEG_ENC -ne 0; then
    logging ${ARG_METADATA}
    ${FFMPEG_CMD} -loglevel info $VIDEO_SKIP $DECODE_APPEND -i "$DIRNAME2/$SRC2" -r:v 30000/1001 -aspect 16:9 \
		  ${VIDEO_FILTERCHAIN_HWACCEL} \
		  -c:v libx264 \
		  -filter_complex_threads ${FILTER_COMPLEX_THREADS} -filter_threads ${FILTER_THREADS} \
		  $FFMPEG_X264_HEAD \
		  $FFMPEG_X264_FRAMES1 \
		  $FFMPEG_X264_AQ \
		  -x264-params $FFMPEG_X264_PARAM \
		  -threads ${ENCTHREADS} \
		  -c:a aac \
		  -ab 224k -ar 48000 -ac 2 \
		  -f mp4 \
		  $ARG_METADATA \
		  -y $TEMPDIR/v1tmp.mp4  &

    #    -filter_complex_threads 4 -filter_threads 4 \

elif test $HWENC -ne 0; then
    if test $IS_HWENC_USE_HEVC -eq 0; then
	logging ${ARG_METADATA}
	${FFMPEG_CMD}  $VIDEO_SKIP $DECODE_APPEND -i "$DIRNAME2/$SRC2" \
		       -r:v ${FRAMERATE} \
		       $VIDEO_FILTERCHAIN_HWACCEL \
		       -c:v h264_vaapi \
		       -filter_threads ${FILTER_THREADS} \
		       -filter_complex_threads ${FILTER_COMPLEX_THREADS} \
		       $HWENC_PARAM \
		       -threads:0 8 \
		       -c:a aac \
		       -threads:1 8 \
		       -r:v ${FRAMERATE} \
		       -ab 224k -ar 48000 -ac 2 \
		       -f mp4 \
		       $ARG_METADATA \
		       -y $TEMPDIR/v1tmp.mp4  \
	    &
	    #    -c:v hevc_vaapi \
    else
	logging ${ARG_METADATA}
	${FFMPEG_CMD}  $VIDEO_SKIP $DECODE_APPEND -i "$DIRNAME2/$SRC2" \
		       -r:v ${FRAMERATE} \
		       $VIDEO_FILTERCHAIN_HWACCEL \
		       -c:v hevc_vaapi \
		       -filter_threads ${FILTER_THREADS} \
		       -filter_complex_threads ${FILTER_COMPLEX_THREADS} \
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
    fi
fi

DEC_VIDEO_PID=$!

#if test $HWENC -eq 0; then 
#wait $DEC_AUDIO_PID
#fi
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
#  ${FFMPEG_CMD}  \
#    -i "$TEMPDIR/v1tmp.mp4" \
#    -c:a copy -c:v copy \
#    -f mp4 \
#    $ARG_METADATA \
#    -y "$DIRNAME/$BASENAME"
#    echo "$DIRNAME/$BASENAME"
else
#  MP4Box -add $TEMPDIR/v1tmp.mp4 -add $TEMPDIR/a1.aac -new "$DIRNAME/$BASENAME"
  cp "$TEMPDIR/v1tmp.mp4" "$DIRNAME/$BASENAME"
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
