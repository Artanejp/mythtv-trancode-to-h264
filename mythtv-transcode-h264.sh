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
# /usr/local/bin/mythtv-transcode-h264.sh -i "%DIR%/%FILE%" -o "%DIR%/%TITLE% %SUBTITLE% - %CHANID% %STARTTIME%.mkv" -c "%CHANID%" -t "%STARTTIMEISOUTC%" --otheroptions


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
POOLTHREADS=4
FRAME_THREADS=4
LOOKAHEAD_THREADS=8
FILTER_THREADS=8
FILTER_COMPLEX_THREADS=8
IS_CRF=1

VIDEO_MINQ=14
VIDEO_MAXQ=33
VIDEO_QUANT=22

VIDEO_AQSTRENGTH="1.1"
VIDEO_QCOMP="0.55"
VIDEO_QDIFF=3
VIDEO_MAXRATE=0
VIDEO_MINRATE=0
VIDEO_BUFSIZE=4096

VIDEO_SCENECUT=48
VIDEO_REF_FRAMES=3
VIDEO_BFRAMES=6
#X264_BITRATE=2500
VIDEO_ASPECT="16:9"

CMCUT=0
REMOVE_SOURCE=0
FASTENC=0
HWACCEL_DEC="NONE"
HWDEINT=0
VIDEO_FILTERCHAIN_NOSCALE=0
VIDEO_FILTERCHAIN_NOCROP=0
VIDEO_FILTER_NOCROP=0
USE_X265=0

X264_ENCPRESET="--preset slower --8x8dct --partitions all"
X264_BITRATE="2000"
X264_PROFILE="high"

X265_PROFILE="main"
X265_PRESET="fast"
X265_PARAMS=""
X265_AQ_STRENGTH=1.0
X265_QP_ADAPTATION_RANGE=1.0


FFMPEG_X265_HEAD="-profile:v ${X265_PROFILE} -preset medium"
FFMPEG_X265_FRAMES1=""
FFMPEG_X265_AQ=""
FFMPEG_X265_PARAMS=""
EXTRA_X265_PARAMS=""
HWENC_APPEND=""

VIDEO_SKIP="-ss 15"

FFMPEG_ENC=1
HWENC=0
HWDEC=0
HW_SCALING="No"

N_QUERY_ID=0;

NICE_VALUE=19
IONICE_ARGS="-n 7"

NICE_CMD=/usr/bin/nice
RENICE_CMD=/usr/bin/renice
IONICE_CMD=/usr/bin/ionice

EXECUTE_PREFIX_CMD=""
FFMPEG_CMD="/usr/bin/ffmpeg"
#FFMPEG_CMD="/usr/local/bin/ffmpeg-arib"
#FFMPEG_SUBTXT_CMD="/usr/local/bin/ffmpeg-arib"
FFMPEG_SUBTXT_CMD="${FFMPEG_CMD}"

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
	--10bit | --10BIT | --profile-10 | --PROFILE-10  )
	    X264_PROFILE="high10"
	    X265_PROFILE="main10"
	    shift
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
	--use-x265 | --USE-X265 | --x265 | --X265)
	    shift
	    USE_X265=1
	    ;;
	--use-x265-10 | --USE-X265-10 | --x265-10 | --X265-10)
	    shift
	    USE_X265=1
	    X265_PROFILE="main10"
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
	--live_mid_hw2 | --live-mid-hw2 )
	    # for Live, middle quality.
	    shift
	    ENCMODE="LIVE_MID_HW2"
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
	--live_mid_fast | --live-mid-fast)
	    # for Live, middle quality.
	    shift
	    ENCMODE="LIVE_MID_FAST"
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
	--nice )
	    shift
	    NICE_VALUE=$1
	    shift
	    ;;
	--ionice )
	    shift
	    IONICE_ARGS="$1"
	    shift
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
s/"\n"/"\\\n"/g
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
   ARG_METADATA="${ARG_METADATA} -metadata subtitle=\"${ARG_SUBTITLE}\""
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

  echo "SELECT recordedid from recorded where chanid=${__N_CHANID} and starttime=\"${__N_STARTTIME}\" ;" > "$TEMPDIR/getrecid.query.sql"
#  logging `cat "$TEMPDIR/getrecid.query.sql"`
  mysql -B -N  --user=$DATABASEUSER --password=$DATABASEPASSWORD mythconverg < "$TEMPDIR/getrecid.query.sql" > "$TEMPDIR/recid.txt" 
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

#  logging "TITLE:"
  echo "SELECT category from recorded where chanid=${__N_CHANID} and starttime=\"${__N_STARTTIME}\" ;" > "$TEMPDIR/getcategory.query.sql"
#  logging `cat "$TEMPDIR/getcategory.query.sql"`
  mysql -B -N  --user=$DATABASEUSER --password=$DATABASEPASSWORD mythconverg < "$TEMPDIR/getcategory.query.sql" > "$TEMPDIR/category.txt" 
#  logging `cat "$TEMPDIR/category.txt"`

echo "SELECT recordedid from recorded where chanid=${__N_CHANID} and starttime=\"${__N_STARTTIME}\" ;" > "$TEMPDIR/getrecid.query.sql"
mysql -B -N  --user=$DATABASEUSER --password=$DATABASEPASSWORD mythconverg < "$TEMPDIR/getrecid.query.sql" > "$TEMPDIR/recid.txt" 


  __N_DESC=`cat "$TEMPDIR/desc.txt"`
  __N_SUBTITLE=`cat "$TEMPDIR/subtitle.txt"`
  __N_TITLE=`cat "$TEMPDIR/title.txt"`
  __N_GENRE=`cat "$TEMPDIR/category.txt"`
  __N_RECID=`cat "$TEMPDIR/recid.txt"`
  
#    logging ${__N_TITLE}
#    if [ -n "${__N_TITLE}" ] ; then
#      change_arg_file "$TEMPDIR/title.txt"
      ARG_TITLE=$(change_arg_file "$TEMPDIR/title.txt")
      ARG_METADATA="${ARG_METADATA} -metadata real_title=\"${ARG_TITLE}\""
#      logging ${ARG_TITLE}
#    fi
    if [ -n "${__N_GENRE}" ] ; then
      ARG_GENRE=$(change_arg_file "$TEMPDIR/category.txt")
      ARG_METADATA="${ARG_METADATA} -metadata genre=\"${ARG_GENRE}\""
#      logging ${ARG_GENRE}
    fi
    if [ -n "${__N_DESC}" ] ; then
      ARG_DESC=$(change_arg_file "$TEMPDIR/desc.txt")
      ARG_METADATA="${ARG_METADATA} -metadata description=\"${ARG_DESC}\""
#      logging ${ARG_DESC}
    fi
    if [ -n "${__N_SUBTITLE}" ] ; then
      ARG_SUBTITLE=$(change_arg_file "$TEMPDIR/subtitle.txt")
#      __TMPARG_TITLE=`echo "${ARG_TITLE}"  |  tr -d "\n"`
#     __TMPARG_SUBTITLE=`echo "${ARG_SUBTITLE}"  |  tr -d "\n"`
#      __TMPARG_TITLE="${__TMPARG_SUBTITLE}"
#      __TMPARG_TITLE=`echo "${__TMPARG_TITLE}" | cut -c -16 -z`
        __TMPARG_TITLE="${ARG_TITLE}:${ARG_SUBTITLE}" 

      ARG_METADATA="${ARG_METADATA} -metadata title=\"${__TMPARG_TITLE}\""
      ARG_METADATA="${ARG_METADATA} -metadata subtitle=\"${ARG_SUBTITLE}\""
    else
      ARG_METADATA="${ARG_METADATA} -metadata title=\"${ARG_TITLE}\""
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
    if [ -n "${__N_RECID}" ] ; then
      ARG_RECID=${__N_RECID}
      ARG_METADATA="${ARG_METADATA} -metadata recorded_id=${ARG_RECID}"
#      logging ${ARG_GENRE}
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
   BASENAME="${ARG_TITLE}_${I_CHANID}_${ARG_STARTTIME}.mkv"
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
    echo " --live_mid_fast  : Set encode parameters for Live movies (faster and lower than standard)."
    echo " --live_low : Set encode parameters for Live movies (low-bitrate, low-quality)."
    echo " --encmode MODE : Set encode parameters to preset named MODE."
    echo " --remove-source | --remove       : Remove source after if transcoding is succeeded. (CAUTION!)"
    echo " --no-remove-source | --no-remove : DO NOT remove source after if transcoding is succeeded. (CAUTION!)"
    echo " --encpreset <std | fast | faster | slow> : Set x264's preset mode."
    echo "    std    = --preset slower"
    echo "    fast   = --preset slow"
    echo "    fast   = --preset medium"
    echo "    faster = --preset fast"
    echo " --nice VALUE : Set nice (process priority) value."
    echo " --ionice ARGS : Set argument(s) for ionice."
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
if [ -x "${RENICE_CMD}" ] ; then
    ${RENICE_CMD} ${NICE_VALUE} $MYPID
fi

if [ -x "${NICE_CMD}" ] ; then
    EXECUTE_PREFIX_CMD="${EXECUTE_PREFIX_CMD} ${NICE_CMD} -n ${NICE_VALUE} "
fi

if [ -x "${IONICE_CMD}" ] ; then
    if [ "__x__${IONICE_ARGS}" != "__x__" ] ; then
	${IONICE_CMD}  ${IONICE_ARGS} -p $MYPID
	EXECUTE_PREFIX_CMD="${EXECUTE_PREFIX_CMD}  ${IONICE_CMD} ${IONICE_ARGS}"
    fi
fi

if  [ "__x__${EXECUTE_PREFIX_CMD}"  !=  "__x__" ] ; then
    FFMPEG_CMD="${EXECUTE_PREFIX_CMD} ${FFMPEG_CMD}"
    FFMPEG_SUBTXT_CMD="${EXECUTE_PREFIX_CMD} ${FFMPEG_SUBTXT_CMD}"
fi

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
   * )
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
VIDEO_FILTERCHAIN_DEINT_VAAPI="deinterlace_vaapi"
VIDEO_FILTERCHAIN_SCALE="scale=width=1280:height=720:flags=lanczos"

VIDEO_FILTERCHAIN_VAAPI_HEAD="format=nv12|vaapi,hwupload"
VIDEO_FILTERCHAIN_VAAPI_TAIL="hwdownload,format=yuv420p"
#VAAPI_SCALER_MODE="default"
VAAPI_SCALER_MODE="hq"

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
   VIDEO_QUANT=22.2
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
   VIDEO_QUANT=21.5
   VIDEO_MINQ=13
   VIDEO_MAXQ=30
   VIDEO_AQSTRENGTH=0.36
   VIDEO_QCOMP=0.80
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
   VIDEO_QUANT=22.0
   VIDEO_MINQ=14
   VIDEO_MAXQ=33
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
   VIDEO_QUANT=20.5
   VIDEO_MINQ=12
   VIDEO_MAXQ=33
   VIDEO_AQSTRENGTH=0.75
   VIDEO_QCOMP=0.80
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
   VIDEO_QUANT=21.0
   VIDEO_MINQ=12
   VIDEO_MAXQ=29
   VIDEO_AQSTRENGTH=0.7
   VIDEO_QCOMP=0.70
   VIDEO_SCENECUT=42
   VIDEO_REF_FRAMES=4
   VIDEO_BFRAMES=3
   OUT_WIDTH=1280
   OUT_HEIGHT=720
   SCALER_MODE="spline"
   
   #X264_BITRATE=3500
   VIDEO_FILTERCHAINX=""
   #VIDEO_FILTERCHAINX="yadif,hqdn3d=luma_spatial=4.2:chroma_spatial=3.2:luma_tmp=3.8:chroma_tmp=3.8"
   VIDEO_FILTERCHAIN_NOCROP=1
   #VIDEO_FILTERCHAIN_VAAPI_TAIL="hwdownload"
   ;;
   "LIVE_SD_HIGH" | "LIVE_SD_HIGH_HW" | "LIVE_SD_HIGH_HW2" )
   VIDEO_QUANT=20.5
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
   VIDEO_FILTERCHAIN_NOCROP=1
   ;;
   "LIVE_MID" | "LIVE_MID_HW" | "LIVE_MID_HW2" | "LIVE_MID_FAST" )
#   VIDEO_QUANT=26
   VIDEO_QUANT=26.5
   VIDEO_MINQ=13
   VIDEO_MAXQ=57
   VIDEO_AQSTRENGTH=1.00
   VIDEO_QCOMP=0.40
   VIDEO_SCENECUT=48
   VIDEO_REF_FRAMES=3
   VIDEO_BFRAMES=6
   OUT_WIDTH=1280
   OUT_HEIGHT=720
   SCALER_MODE="lanczos"
   
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
#   VIDEO_FILTERCHAIN_DEINT_VAAPI="deinterlace_vaapi=mode=weave"
   VIDEO_FILTERCHAIN_DEINT_VAAPI="deinterlace_vaapi=mode=motion_adaptive"
else
   FRAMERATE=60000/1001
   VIDEO_FILTERCHAIN_DEINT="yadif=mode=send_field"
   VIDEO_FILTERCHAIN_DEINT_VAAPI="deinterlace_vaapi=rate=frame"
fi

VIDEO_FILTERCHAIN_VAAPI_SCALE="scale_vaapi=w=${OUT_WIDTH}:h=${OUT_HEIGHT}:mode=${VAAPI_SCALER_MODE}"
VIDEO_FILTERCHAIN_SCALE="scale=w=${OUT_WIDTH}:h=${OUT_HEIGHT}:flags=${SCALER_MODE}"


X264_PRESETS="--profile:v ${X264_PROFILE} --keyint 300 --min-keyint 24 --scenecut 30 --trellis 2"
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
     X264_PRESETS="--profile ${X264_PROFILE} --keyint 300 --min-keyint 24 --scenecut 30 --trellis 2"
     X264_ENCPRESET="--preset slow --ref 6 --8x8dct --partitions all"
     X265_AQ_STRENGTH=0.9
     X265_QP_ADAPTATION_RANGE=1.25
   ;;
   ANIME_HW )
     HWENC_PARAM="-profile:v ${X265_PROFILE} -level 51 \
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
     X264_PRESETS="--profile:v ${X264_PROFILE} --8x8dct --keyint 300 --min-keyint 24 --scenecut 40 --trellis 2"
     X264_ENCPRESET="--preset slow --ref 5 --8x8dct --partitions all"
     
     FFMPEG_X264_HEAD="-profile:v ${X264_PROFILE} -preset slow -direct-pred auto -crf ${VIDEO_QUANT} -bluray-compat 1"
     FFMPEG_X264_AQ="-trellis 2 -partitions all  -8x8dct 1 -mbtree 1 -psy-rd 0.8:0.4"
     
     X265_AQ_STRENGTH=0.70
     X265_QP_ADAPTATION_RANGE=1.10
#     X265_PARAMS="ref=4"
     #HW_SCALING="Yes"
     #HWACCEL_DEC="vaapi"
     HW_SCALING="No"
     HWACCEL_DEC="NONE"
     FFMPEG_ENC=1
     HWENC=0
     HWDEC=0
   ;;
   ANIME_HIGH_HW )
     IS_CRF=0
     VIDEO_QUANT=22
     VIDEO_MINQ=10
     VIDEO_MAXQ=27
     VIDEO_QCOMP=0.75
     VIDEO_QDIFF=8
     VIDEO_BFRAMES=4
     VIDEO_QUALITY=0
     VIDEO_SCENECUT=38
     VIDEO_BUFSIZE=32768
     VIDEO_ASPECT="16:9"

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
     X264_PRESETS="--profile:v ${X264_PROFILE} --keyint 300 --min-keyint 24 --scenecut 40 --trellis 2"
     X264_ENCPRESET="--preset slow --ref 6 --8x8dct --partitions all"
     X265_PRESET="veryfast"

     FFMPEG_X264_HEAD="-profile:v ${X264_PROFILE} -preset slow -direct-pred auto -crf ${VIDEO_QUANT} -bluray-compat 1"
     FFMPEG_X264_AQ="-trellis 2 -partitions all  -8x8dct 1 -mbtree 1 -psy-rd 0.8:0.4"
     X265_AQ_STRENGTH=0.80
     X265_QP_ADAPTATION_RANGE=1.20
     
     HW_SCALING="No"
     HWACCEL_DEC="NONE"
     FFMPEG_ENC=1
     HWENC=0
     HWDEC=0
     
   ;;
   LIVE_HD_MID )
     IS_CRF=1
     
     X264_DIRECT="--direct auto"
     X264_BFRAMES="--bframes 5 --b-bias -1 --b-adapt 2 --psy-rd 0.5:0.2"
     X264_PRESETS="--profile:v ${X264_PROFILE} --keyint 300 --min-keyint 24 --scenecut 45 --trellis 2"
     X264_ENCPRESET="--preset slow --ref 5 --8x8dct --partitions all" 
     X265_PRESET="veryfast"

     FFMPEG_X264_HEAD="-profile:v ${X264_PROFILE} -preset slow -direct-pred auto -crf ${VIDEO_QUANT} -bluray-compat 1"
     FFMPEG_X264_AQ="-trellis 2 -partitions all  -8x8dct 1 -mbtree 1 -psy-rd 0.8:0.4"

     X265_AQ_STRENGTH=0.90
     X265_QP_ADAPTATION_RANGE=1.25
     
     #HW_SCALING="No"
     #HWACCEL_DEC="vaapi"
     HW_SCALING="No"
     HWACCEL_DEC="NONE"
     FFMPEG_ENC=1
     HWENC=0
     HWDEC=0
   ;;
   LIVE_HD_MID_HW )
     IS_CRF=0
     VIDEO_QUANT=25
     VIDEO_MINQ=14
     VIDEO_MAXQ=36
     VIDEO_QCOMP=0.40
     VIDEO_QDIFF=6
     VIDEO_BFRAMES=4
     VIDEO_QUALITY=0
     VIDEO_SCENECUT=45
     VIDEO_MAXRATE=14500k
     VIDEO_MINRATE=100k
     VIDEO_BUFSIZE=32768
     VIDEO_ASPECT="16:9"
     HWENC_APPEND="-b:v 3500k -rc_mode VBR"
     
     #HW_SCALING="Yes"
     HWACCEL_DEC="vaapi"
     HW_SCALING="No"
     #HWACCEL_DEC="NONE"
     FFMPEG_ENC=0
     HWENC=1
     HWDEC=0
     VIDEO_FILTERCHAIN_NOSCALE=1
     HWDEINT=1
     IS_HWENC_USE_HEVC=1
     
   ;;
   LIVE_HD_MID_HW2 )
     IS_CRF=1
     VIDEO_QCOMP=0.40
     VIDEO_QDIFF=8
     VIDEO_BFRAMES=4
     VIDEO_QUALITY=0
     VIDEO_MAXRATE=6000k
     VIDEO_MINRATE=100k
     VIDEO_BUFSIZE=32768


     HWACCEL_DEC="vaapi"
     HW_SCALING="No"
     #HWACCEL_DEC="NONE"
     FFMPEG_ENC=0
     HWENC=1
     HWDEC=0
     VIDEO_FILTERCHAIN_NOSCALE=1
     HWDEINT=1
     IS_HWENC_USE_HEVC=1
   ;;
   
   LIVE1 )
     X264_DIRECT="--direct auto"
     X264_BFRAMES="--bframes 5 --b-bias -1 --b-adapt 2"
   ;;
   LIVE_HIGH )
     X264_DIRECT="--direct spatial --aq-mode 3"
     X264_BFRAMES="--bframes 5 --b-bias -1 --b-adapt 2 --psy-rd 1.2:0.4"
     X264_PRESETS="--profile ${X264_PROFILE} --keyint 300 --min-keyint 24 --scenecut 42 --trellis 2"
     X264_ENCPRESET="--preset slow --ref 5 --8x8dct --partitions all"
     FFMPEG_X264_HEAD="-profile:v ${X264_PROFILE} -preset slow -direct-pred auto -crf ${VIDEO_QUANT}"
     FFMPEG_X264_FRAMES1="-b-pyramid strict  -b-bias -1 -me_method umh -weightp smart"
     FFMPEG_X264_AQ="-trellis 2 -partitions all  -8x8dct 1 -mbtree 1 -psy-rd 1.2:0.6"
     
     X265_AQ_STRENGTH=0.75
     X265_QP_ADAPTATION_RANGE=1.2
     
     HWENC_PARAM=" -coder cavlc -qp 23 -quality 2"
     FFMPEG_ENC=1
     X265_PARAMS="ref=4"
     HWENC=0
     HWDEC=0
     HW_SCALING="No"
     HWACCEL_DEC="NONE"
     #HW_SCALING="Yes"
     #HWACCEL_DEC="vaapi"
     
   ;;
   LIVE_HIGH_HW )
     IS_CRF=0
     VIDEO_QUANT=26
     VIDEO_MINQ=10
     VIDEO_MAXQ=35
     VIDEO_QCOMP=0.30
     VIDEO_QDIFF=10
     VIDEO_BFRAMES=4
     VIDEO_QUALITY=0
     VIDEO_MAXRATE=6000k
     VIDEO_MINRATE=100k
     VIDEO_BUFSIZE=8192
     VIDEO_ASPECT="16:9"

     FFMPEG_ENC=0
     HWENC=1
     HWDEC=0
     HWDEINT=0
     HW_SCALING="No"
     #HWACCEL_DEC="NONE"
     #HW_SCALING="Yes"
     HWACCEL_DEC="vaapi"
   ;;
   LIVE_SD_HIGH )
     X264_DIRECT="--direct spatial --aq-mode 3"
     X264_BFRAMES="--bframes 5 --b-bias -1 --b-adapt 2 --psy-rd 1.2:0.4"
     X264_PRESETS="--profile ${X264_PROFILE} --keyint 300 --min-keyint 24 --scenecut 42 --trellis 2"
     X264_ENCPRESET="--preset slow --ref 5 --8x8dct --partitions all"
     FFMPEG_X264_HEAD="-profile:v ${X264_PROFILE} -preset slow -direct-pred auto -crf ${VIDEO_QUANT}  -sar 32/27"
     FFMPEG_X264_FRAMES1="-b-pyramid strict  -b-bias -1 -me_method umh -weightp smart"
     FFMPEG_X264_AQ="-trellis 2 -partitions all  -8x8dct 1 -mbtree 1 -psy-rd 1.0:0.6"
     
     X265_AQ_STRENGTH=0.70
     X265_QP_ADAPTATION_RANGE=1.05
     
     HWENC_PARAM=" -coder cavlc -aspect ${VIDEO_ASPECT} -qp 21 -quality 4 "
     HW_SCALING="No"
     HWACCEL_DEC="NONE"
     FFMPEG_ENC=1
     HWENC=0
     HWDEC=0
   ;;
   LIVE_SD_HIGH_HW )
     IS_CRF=0
     VIDEO_QUANT=22
     VIDEO_MINQ=10
     VIDEO_MAXQ=28
     VIDEO_QCOMP=0.70
     VIDEO_QDIFF=9
     VIDEO_AQSTRENGTH=0.48
     VIDEO_SCENECUT=38
     VIDEO_QUALITY=0
     VIDEO_BUFSIZE=32768
     VIDEO_ASPECT="16:9"
     
     IS_HWENC_USE_HEVC=0
     FFMPEG_ENC=0
     HWENC=1
     HWDEC=0
     VIDEO_FILTERCHAIN_NOSCALE=0
     HW_SCALING="No"
     #HWACCEL_DEC="NONE"
     #HW_SCALING="Yes"
     HWACCEL_DEC="vaapi"
     
   ;;
   LIVE_SD_HIGH_HW2 )
     IS_CRF=0
     VIDEO_QUANT=22
     VIDEO_MINQ=15
     VIDEO_MAXQ=28
     VIDEO_QCOMP=0.70
     VIDEO_QDIFF=9
     VIDEO_AQSTRENGTH=0.48
     VIDEO_SCENECUT=38
     VIDEO_REF_FRAMES=3
     VIDEO_QUALITY=0
     VIDEO_BUFSIZE=32768
     VIDEO_ASPECT="16:9"

     FFMPEG_ENC=0
     HWENC=1
     HWDEC=0
     VIDEO_FILTERCHAIN_NOSCALE=0
     #HW_SCALING="Yes"
     HW_SCALING="NO"
     HWACCEL_DEC="vaapi"
     #HWACCEL_DEC="NONE"
     IS_HWENC_USE_HEVC=1
   ;;
   LIVE_SD_MID_HW )
     IS_CRF=0
     VIDEO_QUANT=28
     VIDEO_MINQ=21
     VIDEO_MAXQ=55
     VIDEO_QCOMP=0.40
     VIDEO_BFRAMES=4
     VIDEO_QUALITY=4
     VIDEO_MAXRATE=900k
     VIDEO_MINRATE=20k
     VIDEO_BUFSIZE=8192
     VIDEO_ASPECT="16:9"
		  
     #HW_SCALING="Yes"
     #HWACCEL_DEC="vaapi"
     HW_SCALING="No"
     HWACCEL_DEC="NONE"
     FFMPEG_ENC=1
     HWENC=0
     HWDEC=0
   ;;
   LIVE_MID | LIVE_MID_FAST )
     IS_CRF=1

     X264_DIRECT="--direct auto"
     X264_BFRAMES="--bframes 5 --b-bias 0 --b-adapt 2"
     X264_PRESETS="--profile ${X264_PROFILE} --keyint 300 --min-keyint 24 --scenecut 48 --trellis 2"
     X264_ENCPRESET="--preset medium --ref 5 --8x8dct"
     FFMPEG_X264_HEAD="-profile:v ${X264_PROFILE} -preset slow -direct-pred auto -crf ${VIDEO_QUANT}"
     FFMPEG_X264_AQ="-trellis 2 -partitions all  -8x8dct 1 -mbtree 1 -psy-rd 0.6:0.2"
     
     if test "__n__${x}" = "__n__LIVE_MID_FAST" ; then
         X265_PRESET="veryfast"
     else
         X265_PRESET="faster"
     fi
     X265_AQ_STRENGTH=${VIDEO_AQSTRENGTH}
     X265_QP_ADAPTATION_RANGE=1.50
     
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
     IS_CRF=1
     FFMPEG_ENC=0
     HWENC=1
     HWDEC=0
     HW_SCALING="No"
     #HWDEINT=1
     #HWACCEL_DEC="NONE"
     #HW_SCALING="Yes"
     HWACCEL_DEC="vaapi"
     
     VIDEO_QUANT=23
     X264_BITRATE="1600k"

     VIDEO_MINQ=21
     VIDEO_MAXQ=58
     VIDEO_QCOMP=0.40
     VIDEO_QDIFF=10
     VIDEO_AQSTRENGTH=0.48
     VIDEO_SCENECUT=65
     VIDEO_REF_FRAMES=3
     VIDEO_BFRAMES=4
     VIDEO_QUALITY=2
     VIDEO_MAXRATE=2200k
     VIDEO_MINRATE=55k
     VIDEO_BUFSIZE=8192
     VIDEO_ASPECT="16:9"
     
   ;;
   LIVE_MID_HW2 )
     IS_CRF=0
     FFMPEG_ENC=0
     HWENC=1
     HWDEC=0
#     HW_SCALING="No"
     HWDEINT=1
     #HWACCEL_DEC="NONE"
     HW_SCALING="Yes"
     HWACCEL_DEC="vaapi"
     HWDEINT=1
     
     #Re-Define QP params
     VIDEO_QUANT=30
     VIDEO_MINQ=22
     VIDEO_MAXQ=58
     VIDEO_QCOMP=0.40
     VIDEO_QDIFF=10
     VIDEO_AQSTRENGTH=0.48
     VIDEO_SCENECUT=65
     VIDEO_REF_FRAMES=3
     VIDEO_BFRAMES=4
     VIDEO_QUALITY=2
     VIDEO_MAXRATE=1500k
     VIDEO_MINRATE=55k
     VIDEO_BUFSIZE=8192
     VIDEO_ASPECT="16:9"
     
   ;;
   LIVE_LOW )
     X264_DIRECT="--direct auto --aq-mode 3"
     X264_BFRAMES="--bframes 8 --b-bias 0 --b-adapt 2"
     X264_PRESETS="--profile ${X264_PROFILE} --keyint 300 --min-keyint 24 --scenecut 40 --trellis 2"
     X264_ENCPRESET="--preset medium --8x8dct --partitions all"
   ;;
   LIVE_LOW_HW )
     IS_CRF=0
     VIDEO_QUANT=35
     VIDEO_MINQ=23
     VIDEO_MAXQ=51
     VIDEO_QCOMP=0.30
     VIDEO_BFRAMES=4
     VIDEO_QUALITY=4
     VIDEO_MAXRATE=1000k
     VIDEO_MINRATE=50k
     VIDEO_BUFSIZE=8192
     VIDEO_ASPECT="16:9"
     
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

VAAPI_EPILOGUE=""
case "$HWACCEL_DEC" in
#    "VDPAU" | "vdpau" )
#    ;;
    "VAAPI" | "vaapi" )
	if test $HWDEINT -ne 0; then
	    if test $VIDEO_FILTERCHAIN_NOSCALE -eq 0; then
		# Scaling
		case "$HW_SCALING" in
		    "Yes" | "yes" | "YES" )
			VAAPI_EPILOGUE="${VIDEO_FILTERCHAIN_DEINT_VAAPI},${VIDEO_FILTERCHAIN_VAAPI_SCALE}"
			;;
		    * )
			VAAPI_EPILOGUE="${VIDEO_FILTERCHAIN_DEINT_VAAPI}"
			;;
		esac
	    else
		    VAAPI_EPILOGUE="${VIDEO_FILTERCHAIN_DEINT_VAAPI}"
	    fi
	    
	else
	    # NOT HARDWARE DEINT
	    if test $VIDEO_FILTERCHAIN_NOSCALE -eq 0; then
		# scaling
		case "$HW_SCALING" in
		    "Yes" | "yes" | "YES" )
			VAAPI_EPILOGUE="${VIDEO_FILTERCHAIN_VAAPI_SCALE}"
			;;
		    * )
			VAAPI_EPILOGUE=""
			;;
		esac
	    fi
	fi
	if test $HWDEC -ne 0; then
	    if test $HWENC -eq 0; then
		# HWDEC ONLY
		if test "__n__${VAAPI_EPILOGUE}" = "__n__" ; then
		   VIDEO_FILTERCHAIN_HWACCEL="${VIDEO_FILTERCHAIN_VAAPI_TAIL}"
		else
		   VIDEO_FILTERCHAIN_HWACCEL="${VAAPI_EPILOGUE},${VIDEO_FILTERCHAIN_VAAPI_TAIL}"
		fi
    	    else
		   VIDEO_FILTERCHAIN_HWACCEL="${VAAPI_EPILOGUE}"
	    fi
	else
	    if test $HWENC -eq 0; then
	    # NOT BOTH HWDEC AND HWENC
		VIDEO_FILTERCHAIN_HWACCEL=""
	    else
	    # HWENC ONLY
		if test "__n__${VAAPI_EPILOGUE}" = "__n__" ; then
		   VIDEO_FILTERCHAIN_HWACCEL="${VIDEO_FILTERCHAIN_VAAPI_HEAD}"
		else
		   VIDEO_FILTERCHAIN_HWACCEL="${VIDEO_FILTERCHAIN_VAAPI_HEAD},${VAAPI_EPILOGUE}"
		fi
	    fi
	fi
	;;
    *)
	;;
esac
# CORRECT VIDEO_FILTERCHAIN_HWACCEL
if test $HWDEINT -ne 0; then
    if test $VIDEO_FILTERCHAIN_NOSCALE -eq 0; then
	# Scaling
	case "$HW_SCALING" in
	    "Yes" | "yes" | "YES" )
		VIDEO_FILTERCHAIN_HWACCEL="${VIDEO_FILTERCHAIN_HWACCEL}"
		;;
	    * )
		if test "__n__${VIDEO_FILTERCHAIN_HWACCEL}" = "__n__" ; then
		    VIDEO_FILTERCHAIN_HWACCEL="${VIDEO_FILTERCHAIN_SCALE}"
		else
		    VIDEO_FILTERCHAIN_HWACCEL="${VIDEO_FILTERCHAIN_SCALE},${VIDEO_FILTERCHAIN_HWACCEL}"
		fi
		;;
	esac
    else
	# NOT SCALING AND NOT DEINT
	VIDEO_FILTERCHAIN_HWACCEL="${VIDEO_FILTERCHAIN_HWACCEL}"
    fi
else
    # NOT HWDEINT
    if test $VIDEO_FILTERCHAIN_NOSCALE -eq 0; then
	# Scaling
	case "$HW_SCALING" in
	    "Yes" | "yes" | "YES" )
		VIDEO_FILTERCHAIN_HWACCEL="${VIDEO_FILTERCHAIN_DEINT},${VIDEO_FILTERCHAIN_HWACCEL}"
		;;
	    * )
		if test "__n__${VIDEO_FILTERCHAIN_HWACCEL}" = "__n__" ; then
		    VIDEO_FILTERCHAIN_HWACCEL="${VIDEO_FILTERCHAIN_DEINT},${VIDEO_FILTERCHAIN_SCALE}"
		else
		    VIDEO_FILTERCHAIN_HWACCEL="${VIDEO_FILTERCHAIN_DEINT},${VIDEO_FILTERCHAIN_SCALE},${VIDEO_FILTERCHAIN_HWACCEL}"
		fi
		;;
	esac
    else
	# NOT SCALING AND NOT HWDEINT
	if test "__n__${VIDEO_FILTERCHAIN_HWACCEL}" = "__n__" ; then
	    VIDEO_FILTERCHAIN_HWACCEL="${VIDEO_FILTERCHAIN_DEINT}"
	else
	    VIDEO_FILTERCHAIN_HWACCEL="${VIDEO_FILTERCHAIN_DEINT},${VIDEO_FILTERCHAIN_HWACCEL}"
	fi
    fi
fi

if test $VIDEO_FILTERCHAIN_NOSCALE -eq 0; then
    # Scaling
    VIDEO_FILTERCHAIN="${VIDEO_FILTERCHAIN_DEINT},${VIDEO_FILTERCHAIN_SCALE}"
else
    # Not scaling
    VIDEO_FILTERCHAIN="${VIDEO_FILTERCHAIN_DEINT}"
fi
echo "Filter chain = $VIDEO_FILTERCHAIN" 


if test $VIDEO_FILTERCHAIN_NOCROP -eq 0 ; then
    VIDEO_FILTERCHAIN="${VIDEO_FILTERCHAIN0},${VIDEO_FILTERCHAIN}"
    #ToDo: HWCROP
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
#	  DECODE_APPEND="${DECODE_APPEND} -hwaccel:${HWDECODE_TAG} vaapi -hwaccel_output_format vaapi"
	  DECODE_APPEND="${DECODE_APPEND} -hwaccel:${HWDECODE_TAG} vaapi"
      else
	  VIDEO_FILTERCHAIN_HWACCEL="${VIDEO_FILTERCHAIN_HWACCEL}"
      fi
      #echo "vaapi"
      ;;
  *)
      if test $HWENC -ne 0 ; then 
	  VIDEO_FILTERCHAIN_HWACCEL="${VIDEO_FILTERCHAIN_HWACCEL}"
      else
          VIDEO_FILTERCHAIN_HWACCEL="${VIDEO_FILTERCHAIN}"
	  if test $USE_X265 -ne 0 ; then
	 	if test "__n__${X265_PROFILE}" = "__n__main10" ; then
			VIDEO_FILTERCHAIN_HWACCEL="${VIDEO_FILTERCHAIN_HWACCEL},format=yuv420p10le"
	 	fi
	 fi
      fi
      ;;
esac


echo ${VIDEO_FILTERCHAIN_HWACCEL}
#FFMPEG_X264_PARAM=${FFMPEG_X264_PARAM}:threads=${ENCTHREADS}  

#${FFMPEG_SUBTXT_CMD} -loglevel info  -txt_format text \
#       $VIDEO_SKIP -i "$DIRNAME2/$SRC2"  \
#       -c:s webvtt \
#       -y $TEMPDIR/v1tmp.srt 

${FFMPEG_SUBTXT_CMD} -loglevel info  -aribb24-skip-ruby-text false \
       -fix_sub_duration $VIDEO_SKIP  -i "$DIRNAME2/$SRC2"  \
       -c:s ass -f ass \
       -y $TEMPDIR/v1tmp.ass

ARG_METADATA="${ARG_METADATA} -metadata:s:a:0 language=jpn -metadata:s:a:0 real_encoder=aac"

DISPLAY_SINK_PARAM="filter_threads=${FILTER_THREADS}:filter_complex_threads=${FILTER_COMPLEX_THREADS}"
DISPLAY_SINK_PARAM="-metadata:s:v:0 encode_threads=\"${DISPLAY_SINK_PARAM}\""
ARG_METADATA="${ARG_METADATA}  -metadata:g source=\"${SRC2}\""

__ENCODE_START_DATE=`date --rfc-3339=ns`

DISPLAY_FILTERCHAIN="${VIDEO_FILTERCHAIN_HWACCEL}"
if test $FFMPEG_ENC -ne 0; then
    DISPLAY_FILTERCHAIN="-metadata:s:v:0 filterchains=\"vf:${DISPLAY_FILTERCHAIN}\""
    
    if test ${USE_X265} -ne 0; then
    
	if [ ${IS_CRF} -ne 0 ] ; then
	   __QUANT_TYPE="crf"
	   FFMPEG_X265_HEAD="-profile:v ${X265_PROFILE}  -preset ${X265_PRESET} -crf ${VIDEO_QUANT}"
	else
	   __QUANT_TYPE="qp"
           FFMPEG_X265_HEAD="-profile:v ${X265_PROFILE}  -preset ${X265_PRESET} -qp ${VIDEO_QUANT}"
	fi
	X265_THREAD_PARAMS="frame-threads=${FRAME_THREADS}:pools=${POOLTHREADS}"
	#X265_THREAD_PARAMS="${X265_THREAD_PARAMS}:pme=true:pmode=true"
	
	X265_AQ_PARAMS="hevc-aq=true:aq-mode=4"
	X265_AQ_PARAMS="${X265_AQ_PARAMS}:aq-strength=${X265_AQ_STRENGTH}"
	X265_AQ_PARAMS="${X265_AQ_PARAMS}:qp-adaptation-range=${X265_QP_ADAPTATION_RANGE}"
	#X265_AQ_PARAMS="${X265_AQ_PARAMS}:aq-motion=true"
	if test "__n__${X265_PARAMS}" != "__n__"; then
		X265_PARAMS="${X265_PARAMS}:"
	fi
	if test "__n__${X265_AQ_PARAMS}" != "__n__"; then
		X265_PARAMS="${X265_PARAMS}${X265_AQ_PARAMS}:"
	fi
		
	if test "__n__${X265_PARAMS}" != "__n__"; then
		X265_PARAMS="${X265_PARAMS}:${X265_THREAD_PARAMS}"
	else
		X265_PARAMS="${X265_THREAD_PARAMS}"
	fi 
	if test "__n__${EXTRA_X265_PARAMS}" != "__n__"; then
		if test "__n__${X265_PARAMS}" != "__n__"; then
			X265_PARAMS="${X265_PARAMS}:${EXTRA_X265_PARAMS}"
		else
			X265_PARAMS="${EXTRA_X265_PARAMS}"
		fi
	fi
	if test "__n__${X265_PARAMS}" != "__n__"; then
	    FFMPEG_X265_PARAMS="-x265-params ${X265_PARAMS}"
	fi
	DISPLAY_FFMPEG_ENCODER="-metadata:s:v:0 real_encoder=libx265"
	
	DISPLAY_ENCODER_PARAMS="-metadata:s:v:0 encode_params="
	DISPLAY_ENCODER_PARAMS="${DISPLAY_ENCODER_PARAMS}\"profile=${X265_PROFILE}"
	DISPLAY_ENCODER_PARAMS="${DISPLAY_ENCODER_PARAMS}:preset=${X265_PRESET}"
	DISPLAY_ENCODER_PARAMS="${DISPLAY_ENCODER_PARAMS}:${__QUANT_TYPE}=${VIDEO_QUANT}"
	DISPLAY_ENCODER_PARAMS="${DISPLAY_ENCODER_PARAMS}:${X265_PARAMS}\""

	ARG_METADATA="${ARG_METADATA} ${DISPLAY_FFMPEG_ENCODER}"
	ARG_METADATA="${ARG_METADATA} ${DISPLAY_SINK_PARAM}"
	ARG_METADATA="${ARG_METADATA} ${DISPLAY_ENCODER_PARAMS}"
	ARG_METADATA="${ARG_METADATA} ${DISPLAY_FILTERCHAIN}"
	logging ${ARG_METADATA}
	
	${FFMPEG_CMD} -loglevel info $VIDEO_SKIP $DECODE_APPEND -i "$DIRNAME2/$SRC2" \
	              -r:v ${FRAMERATE} -aspect ${VIDEO_ASPECT} \
		      -vf ${VIDEO_FILTERCHAIN_HWACCEL} \
		      -c:v libx265 \
		      -filter_complex_threads ${FILTER_COMPLEX_THREADS} -filter_threads ${FILTER_THREADS} \
		      ${FFMPEG_X265_HEAD} \
		      ${FFMPEG_X265_FRAMES1} \
		      ${FFMPEG_X265_AQ} \
		      ${FFMPEG_X265_PARAMS} \
		      -threads ${ENCTHREADS} \
		      -c:a aac \
		      -ab 224k -ar 48000 -ac 2 \
		      -af aresample=async=1:min_hard_comp=0.100000:first_pts=0 \
		      ${ARG_METADATA} \
		      -metadata:g enc_start="${__ENCODE_START_DATE}" \
		      -y $TEMPDIR/v1tmp.mkv  
    else
	DISPLAY_FFMPEG_ENCODER="-metadata:s:v:0 real_encoder=libx264"
	DISPLAY_ENCODER_PARAMS="-metadata:s:v:0 encode_params=\"profile=${X264_PROFILE}:${FFMPEG_X264_PARAM}\""

	ARG_METADATA="${ARG_METADATA} ${DISPLAY_FFMPEG_ENCODER}"
	ARG_METADATA="${ARG_METADATA} ${DISPLAY_SINK_PARAM}"
	ARG_METADATA="${ARG_METADATA} ${DISPLAY_ENCODER_PARAMS}"
	ARG_METADATA="${ARG_METADATA} ${DISPLAY_FILTERCHAIN}"
	logging ${ARG_METADATA}
    
	${FFMPEG_CMD} -loglevel info $VIDEO_SKIP $DECODE_APPEND -i "$DIRNAME2/$SRC2" \
	          -r:v ${FRAMERATE} -aspect ${VIDEO_ASPECT} \
		  -vf ${VIDEO_FILTERCHAIN_HWACCEL} \
		  -c:v libx264 \
		  -filter_complex_threads ${FILTER_COMPLEX_THREADS} -filter_threads ${FILTER_THREADS} \
		  $FFMPEG_X264_HEAD \
		  $FFMPEG_X264_FRAMES1 \
		  $FFMPEG_X264_AQ \
		  -x264-params $FFMPEG_X264_PARAM \
		  -threads ${ENCTHREADS} \
		  -c:a aac \
		  -ab 224k -ar 48000 -ac 2 \
		  -af aresample=async=1:min_hard_comp=0.100000:first_pts=0 \
		  $ARG_METADATA \
      		  -metadata:g enc_start="${__ENCODE_START_DATE}" \
		  -y $TEMPDIR/v1tmp.mkv 

    #    -filter_complex_threads 4 -filter_threads 4 \
	fi
elif test $HWENC -ne 0; then
    DISPLAY_FILTERCHAIN="-metadata:s:v:0 filterchains=\"filter_complex:${DISPLAY_FILTERCHAIN}\""
    __HWENC_AWK=" 
    BEGIN { 
    } 
    
    NR==1 {
              i=1;
	      for(x=1; x<= NF; x++) {
	          __token[i]=\$x;
		  i++;
	      }
	      __OUTSTR=\"\";
	      for(j=1; j<i; j+=2) {
 	          gsub(/^-/, \"\", __token[j]);
	          __OUTSTR=__OUTSTR  __token[j] \"=\" __token[j+1] \":\";	
	      }
	 }
    END  {
             printf(\"%s\", __OUTSTR);
	 }
	 "
    if test $IS_HWENC_USE_HEVC -eq 0; then

        HWENC_PARAM=""
        HWENC_PARAM="${HWENC_PARAM} -aud 1 -level 51"
	# Will FIX
	if [ ${IS_CRF} -ne 0 ] ; then
	   __QUANT_TYPE="crf"
           HWENC_PARAM="${HWENC_PARAM} -crf ${VIDEO_QUANT} -qmin ${VIDEO_MINQ} -qmax ${VIDEO_MAXQ}"
	else
	   __QUANT_TYPE="qp"
           HWENC_PARAM="${HWENC_PARAM} -qp ${VIDEO_QUANT} -qmin ${VIDEO_MINQ} -qmax ${VIDEO_MAXQ}"
        fi	
	if test "__n__${HWENC_APPEND}" != "__n__" ; then
        	HWENC_PARAM="${HWENC_PARAM} ${HWENC_APPEND}"
	fi
        HWENC_PARAM="${HWENC_PARAM} -qcomp ${VIDEO_QCOMP} -qdiff ${VIDEO_QDIFF}"
        HWENC_PARAM="${HWENC_PARAM} -sc_threshold ${VIDEO_SCENECUT} -bf ${VIDEO_BFRAMES}"
        HWENC_PARAM="${HWENC_PARAM} -quality ${VIDEO_QUALITY}"
        HWENC_PARAM="${HWENC_PARAM} -maxrate ${VIDEO_MAXRATE} -minrate ${VIDEO_MINRATE}"
	HWENC_PARAM="${HWENC_PARAM} -bufsize ${VIDEO_BUFSIZE}"
	
	DISPLAY_HWENC_PARAM=`echo "${HWENC_PARAM}" | gawk "${__HWENC_AWK}"`
	DISPLAY_ENCODER_PARAMS="-metadata:s:v:0 encode_params=\"profile=${X265_PROFILE}:${DISPLAY_HWENC_PARAM}\""

	DISPLAY_FFMPEG_ENCODER="-metadata:s:v:0 real_encoder=h264_vaapi"
	ARG_METADATA="${ARG_METADATA} ${DISPLAY_FFMPEG_ENCODER}"
	ARG_METADATA="${ARG_METADATA} ${DISPLAY_SINK_PARAM}"
	ARG_METADATA="${ARG_METADATA} ${DISPLAY_ENCODER_PARAMS}"
	ARG_METADATA="${ARG_METADATA} ${DISPLAY_FILTERCHAIN}"
	logging ${ARG_METADATA}
	
	${FFMPEG_CMD}  $VIDEO_SKIP $DECODE_APPEND -i "$DIRNAME2/$SRC2" \
		       -r:v ${FRAMERATE} \
		       -filter_complex ${VIDEO_FILTERCHAIN_HWACCEL} \
		       -c:v h264_vaapi \
		       -filter_threads ${FILTER_THREADS} \
		       -filter_complex_threads ${FILTER_COMPLEX_THREADS} \
		       $HWENC_PARAM \
		       -aspect ${VIDEO_ASPECT} \
		       -threads:0 8 \
		       -c:a aac \
		       -threads:1 8 \
		       -r:v ${FRAMERATE} \
		       -ab 224k -ar 48000 -ac 2 \
		       -af aresample=async=1:min_hard_comp=0.100000:first_pts=0 \
		       $ARG_METADATA \
		      -metadata:g enc_start="${__ENCODE_START_DATE}" \
		       -y $TEMPDIR/v1tmp.mkv  \
	    
	    #    -c:v hevc_vaapi \
    else
	DISPLAY_FFMPEG_ENCODER="-metadata:s:v:0 real_encoder=hevc_vaapi"
        HWENC_PARAM=""
	# Will FIX
        HWENC_PARAM="${HWENC_PARAM} -aud 1 -level 51"
	if [ ${IS_CRF} -ne 0 ] ; then
	   __QUANT_TYPE="global_quality"
           HWENC_PARAM="${HWENC_PARAM} -global_quality ${VIDEO_QUANT} -b:v ${X264_BITRATE} -rc_mode VBR"
	else
	   __QUANT_TYPE="qp"
           HWENC_PARAM="${HWENC_PARAM} -qp ${VIDEO_QUANT} -qmin ${VIDEO_MINQ} -qmax ${VIDEO_MAXQ}"
        fi	

	if test "__n__${HWENC_APPEND}" != "__n__" ; then
        	HWENC_PARAM="${HWENC_PARAM} ${HWENC_APPEND}"
	fi
        HWENC_PARAM="${HWENC_PARAM} -qcomp ${VIDEO_QCOMP} -qdiff ${VIDEO_QDIFF}"
        HWENC_PARAM="${HWENC_PARAM} -sc_threshold ${VIDEO_SCENECUT} -bf ${VIDEO_BFRAMES}"
        HWENC_PARAM="${HWENC_PARAM} -quality ${VIDEO_QUALITY}"
        HWENC_PARAM="${HWENC_PARAM} -maxrate ${VIDEO_MAXRATE} -minrate ${VIDEO_MINRATE}"
	HWENC_PARAM="${HWENC_PARAM} -bufsize ${VIDEO_BUFSIZE}"
	
	DISPLAY_HWENC_PARAM=`echo "${HWENC_PARAM}" | gawk "${__HWENC_AWK}"`
	DISPLAY_ENCODER_PARAMS="-metadata:s:v:0 encode_params=\"profile=${X265_PROFILE}:${DISPLAY_HWENC_PARAM}\""

	
	DISPLAY_SINK_PARAM="${DISPLAY_SINK_PARAM}:threads(0)=4:threads(1)=4"
	echo
	echo "${DISPLAY_HWENC_PARAM}"
	echo
	
	DISPLAY_FFMPEG_ENCODER="-metadata:s:v:0 real_encoder=hevc_vaapi"
	ARG_METADATA="${ARG_METADATA} ${DISPLAY_FFMPEG_ENCODER}"
	ARG_METADATA="${ARG_METADATA} ${DISPLAY_SINK_PARAM}"
	ARG_METADATA="${ARG_METADATA} ${DISPLAY_ENCODER_PARAMS}"
	ARG_METADATA="${ARG_METADATA} ${DISPLAY_FILTERCHAIN}"
	logging ${ARG_METADATA}

	
	${FFMPEG_CMD}  $VIDEO_SKIP $DECODE_APPEND -i "$DIRNAME2/$SRC2" \
	               -profile:v ${X265_PROFILE} \
		       -aud 1 -level 51 \
		       -r:v ${FRAMERATE} \
		       -filter_complex $VIDEO_FILTERCHAIN_HWACCEL \
		       -c:v hevc_vaapi \
		       -filter_threads ${FILTER_THREADS} \
		       -filter_complex_threads ${FILTER_COMPLEX_THREADS} \
		       $HWENC_PARAM \
		       -aspect ${VIDEO_ASPECT} \
		       -threads:0 4 \
		       -c:a aac \
		       -threads:1 4 \
		       -r:v ${FRAMERATE} \
		       -ab 224k -ar 48000 -ac 2 \
		       -af aresample=async=1:min_hard_comp=0.100000:first_pts=0 \
		       ${ARG_METADATA} \
		      -metadata:g enc_start="${__ENCODE_START_DATE}" \
		       -y $TEMPDIR/v1tmp.mkv  \
	    
	    #    -c:v hevc_vaapi \
    fi
fi

#DEC_VIDEO_PID=$!

#if test $HWENC -eq 0; then 
#wait $DEC_AUDIO_PID
#fi
#RESULT_DEC_AUDIO=$?

#wait $ENC_AUDIO_PID
#RESULT_ENC_AUDIO=$?

#wait $DEC_VIDEO_PID
RESULT_DEC_VIDEO=$?


if test $HWENC -eq 0; then 
wait $ENC_VIDEO_PID
RESULT_ENC_VIDEO=$?
fi
fi

#exit 1
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


if test -s "$TEMPDIR/v1tmp.ass" ; then
    ARG_SUBTXT="-f ass -i $TEMPDIR/v1tmp.ass "
    ARG_SUBTXT2="-c:s copy -c:a copy -c:v copy -map:v 0:0 \
                 -map:a 0:1 -map:s 1:0 -metadata:s:s:0 language=jpn \
		 -metadata:s:a:0 language=jpn"
    ${FFMPEG_CMD} -i $TEMPDIR/v1tmp.mkv \
                  ${ARG_SUBTXT} \
		  ${ARG_SUBTXT2} \
		  -y $TEMPDIR/v2tmp.mkv
else
    mv $TEMPDIR/v1tmp.mkv $TEMPDIR/v2tmp.mkv
fi   

touch "$DIRNAME/test$BASENAME"
if [ ! -w "$DIRNAME/test$BASENAME" ] ; then 
   logging "Unable to Write encoded movie."
   exit 3
fi
rm "$DIRNAME/test$BASENAME"

if test $HWENC -ne 0; then
  cp "$TEMPDIR/v2tmp.mkv" "$DIRNAME/$BASENAME"
else
  cp "$TEMPDIR/v2tmp.mkv" "$DIRNAME/$BASENAME"
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
