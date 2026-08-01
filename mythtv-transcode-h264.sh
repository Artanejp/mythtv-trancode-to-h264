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

#### For quantization ( crf / qp )
VIDEO_QUANT=22
VIDEO_MINQ=14
VIDEO_MAXQ=33

# Special quant variables for SVTAV1 (using --av1 without hwenc or another coder libs).
# If not set, crf/qp calculates automatically from VIDEO_QUANT etc...
SVTAV1_VIDEO_QUANT=""
typeset -i SVTAV1_VIDEO_MINQ
typeset -i SVTAV1_VIDEO_MAXQ
SVTAV1_VIDEO_MINQ=-1
SVTAV1_VIDEO_MAXQ=-1

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
typeset -i USE_X265
USE_X265=0

typeset -i USE_SVTAV1
USE_SVTAV1=0
SVTAV1_PRESET="faster"
SVTAV1_TUNE="nograin"

typeset -i SVTAV1_AQ_MODE
SVTAV1_AQ_MODE=2
typeset -i SVTAV1_RC_MODE
SVTAV1_RC_MODE=-1
SVTAV1_AQ_STRENGTH=1.25
typeset -i SVTAV1_SHARPNESS
SVTAV1_SHARPNESS=-255

typeset -i SVTAV1_DISABLE_TEMPORAL_FILTERING
SVTAV1_DISABLE_TEMPORAL_FILTERING=0
typeset -i SVTAV1_TEMPORAL_FILTERING_STRENGTH
SVTAV1_TEMPORAL_FILTERING_STRENGTH=1

typeset -i SVTAV1_ENABLE_QM
typeset -i SVTAV1_QM_MIN
typeset -i SVTAV1_QM_MAX
SVTAV1_ENABLE_QM=1
SVTAV1_QM_MIN=3
SVTAV1_QM_MAX=15

typeset -i SVTAV1_DETAIL_BOOST
SVTAV1_DETAIL_BOOST=1

declare -a SVTAV1_HEAD_VALUES
unset SVTAV1_HEAD_VALUES[@]

typeset -i TARGET_BITRATE_KBIT
TARGET_BITRATE_KBIT=-1

X264_ENCPRESET="--preset slower --8x8dct --partitions all"
X264_BITRATE="2000"
X264_PROFILE="high"

X265_PROFILE="main"
X265_PRESET="faster"
X265_PARAMS=""
X265_AQ_STRENGTH=1.0
X265_QP_ADAPTATION_RANGE=1.0
typeset -i X265_AQ_MODE
X265_AQ_MODE=3



typeset -i IS_DROP_ERROR_FRAMES
typeset -i USE_ADVANCED_ERROR_DETECT
# Decoder
IS_DROP_ERROR_FRAMES=0
USE_ADVANCED_ERROR_DETECT=0
PREFETCH_MB=0

declare -a FFMPEG_X265_HEAD
unset FFMPEG_X265_HEAD[@]

#FFMPEG_X265_HEAD="-profile:v ${X265_PROFILE} -preset medium"
FFMPEG_X265_FRAMES1=""
FFMPEG_X265_AQ=""
FFMPEG_X265_PARAMS=""
EXTRA_X265_PARAMS=""

declare -a FFMPEG_X264_HEAD
unset FFMPEG_X264_HEAD[@]

declare -a FFMPEG_X264_AQ
unset FFMPEG_X264_AQ[@]

HWENC_APPEND=""

VIDEO_SKIP="15"

typeset -i USE_HDR_DEFAULT
typeset -i USE_HDR
USE_HDR_DEFAULT=0

typeset -i FFMPEG_ENC
typeset -i HWENC
typeset -i HWDEC

FFMPEG_ENC=1
HWENC=0
HWDEC=0
HW_SCALING="No"

N_QUERY_ID=0

IGNORE_DECODE_ERRORS=0

typeset -i IS_COPY_SUB_AS_RAW_ARIB
IS_COPY_SUB_AS_RAW_ARIB=1

typeset -i NICE_VALUE
typeset -i IONICE_VALUE

IONICE_CLASS=""
NICE_VALUE=17
IONICE_VALUE=7

NICE_CMD=/usr/bin/nice
IONICE_CMD=/usr/bin/ionice

EXECUTE_PREFIX_CMD=""
FFMPEG_CMD="/usr/bin/ffmpeg"
FFPROBE_CMD="/usr/bin/ffprobe"
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
IS_VFR=0
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

USE_HDR=${USE_HDR_DEFAULT}
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
	--ignore-errors | --ignore-decode-errors )
	    IGNORE_DECODE_ERRORS=1
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
	--copy_arib_sub | --copy-arib-sub | --rawsub )
	    IS_COPY_SUB_AS_RAW_ARIB=1
	    shift
	    ;;
	---no-copy_arib_sub | --no-copy-arib-sub | --no-rawsub | --ssasub )
	    IS_COPY_SUB_AS_RAW_ARIB=0
	    shift
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
	--skip_sec | --skip-sec | --skip_seconds | --skip-seconds )
	    shift
	    VIDEO_SKIP="$1"
	    shift
	    ;;
	--threads | --thread | -thread | -threads )
	    shift
	    ENCTHREADS="$1"
	    POOLTHREADS="$1"
	    FRAME_THREADS="$1"
	    shift
	    ;;
	--pool-threads | --pool-thread | --pools | -pools | -pool-thread | -pool-threads )
	    shift
	    POOLTHREADS="$1"
	    shift
	    ;;
	--frame-threads | --frame-thread | --frames | -frames | -frame-thread | -frame-threads )
	    shift
	    FRAME_THREADS="$1"
	    shift
	    ;;
	--db | --use-db | --with-db )
	    shift
	    USE_DATABASE=1
	    ;;
	--prefetch-mb | --prefetch | -pf | --pf )
	    shift
	    PREFETCH_MB=$1
	    shift
	    ;;
	--drop-broken | --drop-broken-frames | --drop-corrupts | -d_b | --d_b )
	    IS_DROP_ERROR_FRAMES=1
	    shift
	    ;;
	--no-drop-broken | --no-drop-broken-frames | --no-drop-corrupts | -nd_b | --nd_b )
	    IS_DROP_ERROR_FRAMES=0
	    shift
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
	--hdr | --HDR | --hdr10 | --HDR10 | --hdr12 | --HDR12 )
	    shift
	    USE_HDR=1
	    ;;
	--no-hdr | --NO-HDR | --no-hdr10 | --NO-HDR10 | --no-hdr12 | --NO-HDR12 )
	    shift
	    USE_HDR=0
	    ;;
	--default-hdr | --DEFAULT-HDR | --defaulut-hdr10 | --DEFAULT-HDR10 | --default-hdr12 | --DEFAAULT-HDR12 )
	    shift
	    USE_HDR=${USE_HDR_DEFAULT}
	    ;;
	--use-x265 | --USE-X265 | --x265 | --X265 | --hevc )
	    shift
	    USE_X265=1
	    ;;
	--use-x265-10 | --use-x265_10 | --USE-X265-10 | --USE-X265_10 | --x265-10 | --x265_10 | --X265_10 | --X265-10 )
	    shift
	    USE_X265=1
	    X265_PROFILE="main10"
	    ;;
	--use-x265-hdr10 | --use-x265_hdr10 | --USE-X265-HDR10 | --USE-X265_HDR10 | --x265-hdr10 | --x265_HDR10 | --X265_10 | --X265-HDR10 )
	    shift
	    USE_X265=1
	    USE_HDR=1
	    X265_PROFILE="main10"
	    ;;
	--use-svtav1 | --USE-SVTAV1 | --svtav1 | --SVTAV1 | --av1 | --AV1 )
	    shift
	    USE_SVTAV1=1
	    ;;
	--use-svtav1-10 | --USE-SVTAV1-10 | --svtav1-10 | --SVTAV1-10 | --av1-10 | --AV1-10 )
	    # Backward compatibility
	    shift
	    USE_SVTAV1=1
	    ;;
	--no-opencl | --no-OpenCL | --NO-OpenCL | --NO-OPENCL )
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
	--anime_sd_high | --anime-sd-high )
	    # Optimize for anime
	    shift
	    ENCMODE="ANIME_SD_HIGH"
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
	--vfr | --vfr60 )
	    shift
	    USE_60FPS=1
	    IS_VFR=1
	    ;;
	--vfr30 )
	    shift
	    USE_60FPS=0
	    IS_VFR=1
	    ;;
	--cfr )
	    shift
	    IS_VFR=0
	    ;;
	--cfr30 )
	    shift
	    USE_60FPS=0
	    IS_VFR=0
	    ;;
	--cfr60 )
	    shift
	    USE_60FPS=1
	    IS_VFR=0
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
	--ionice | --ionice-value )
	    shift
	    IONICE_VALUE=$1
	    shift
	    ;;
	--ionice-class )
	    shift
	    IONICE_CLASS=$1
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
s/[[:blank:]]/　/g
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
s/[[:blank:]]/　/g
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
function change_arg_description() {
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
s/\//／/g
s/=/＝/g
s/[[:blank:]]/　/g
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
EOF

__tmpv1=`cat ${__SRCFILE} | sed -f "${TEMPDIR}/__tmpscript12"`
#rm ${TEMPDIR}/__tmpscript12
echo "${__tmpv1}"
}

declare -a  ARG_METADATA
unset ARG_METADATA[@]

ARG_DESC=""
ARG_SUBTITLE=""
ARG_EPISODE=""
ARG_ONAIR=""

__N_TITLE=""



printf "" > "$TEMPDIR/desc.txt"
if [ -n "${VIDEO_DESC}" ] ; then
#   ARG_DESC=`change_arg_nonpath "${VIDEO_DESC}"`
#   ARG_METADATA+=(-metadata:g)
#   ARG_METADATA+=(description="${ARG_DESC}")
   echo ${VIDEO_DESC} >> "$TEMPDIR/desc.txt"
   echo " " >> "$TEMPDIR/desc.txt"
fi
if [ -n "${VIDEO_EPISODE}" ] ; then
   ARG_EPISODE=`change_arg_nonpath "${VIDEO_EPISODE}"`
   ARG_METADATA+=(-metadata:g)
   ARG_METADATA+=("episode=${ARG_EPISODE}")
fi
if [ -n "${VIDEO_SUBTITLE}" ] ; then
   ARG_SUBTITLE=`change_arg_nonpath "${VIDEO_SUBTITLE}"`
   ARG_METADATA+=(-metadata:g)
   ARG_METADATA+=("subtitle=${ARG_SUBTITLE}")
fi
if [ -n "${VIDEO_ONAIR}" ] ; then
   ARG_ONAIR="${VIDEO_ONAIR}"
   ARG_METADATA+=(-metadata:g)
   ARG_METADATA+=("date=${ARG_ONAIR}")
fi
if test $N_QUERY_ID -gt 0 ; then
  logging "QUERY JOBQUEUE id ${N_QUERY_ID}"
  
#  echo "SELECT * from jobqueue where id=${N_QUERY_ID} ;" > "$TEMPDIR/jobqueue.query.sql"
  #logging `cat "$TEMPDIR/jobqueue.query.sql"`
#  logging `mysql -v -v -v --user=$DATABASEUSER --password=$DATABASEPASSWORD mythconverg < "$TEMPDIR/jobqueue.query.sql"`

  echo "SELECT chanid from jobqueue where id=${N_QUERY_ID} ;" > "$TEMPDIR/getchanid.query.sql"
  #logging `cat "$TEMPDIR/getchanid.query.sql"`
  mysql -B -N --user=$DATABASEUSER --password=$DATABASEPASSWORD mythconverg < "$TEMPDIR/getchanid.query.sql" >"$TEMPDIR/chanid.txt"
  logging "SID:"
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
  mysql -B -N --raw  --user=$DATABASEUSER --password=$DATABASEPASSWORD mythconverg < "$TEMPDIR/getdesc.query.sql" >> "$TEMPDIR/desc.txt"
#  logging `cat "$TEMPDIR/desc.txt"`

#  logging "TITLE:"
  echo "SELECT category from recorded where chanid=${__N_CHANID} and starttime=\"${__N_STARTTIME}\" ;" > "$TEMPDIR/getcategory.query.sql"
#  logging `cat "$TEMPDIR/getcategory.query.sql"`
  mysql -B -N  --user=$DATABASEUSER --password=$DATABASEPASSWORD mythconverg < "$TEMPDIR/getcategory.query.sql" > "$TEMPDIR/category.txt" 
#  logging `cat "$TEMPDIR/category.txt"`

echo "SELECT recordedid from recorded where chanid=${__N_CHANID} and starttime=\"${__N_STARTTIME}\" ;" > "$TEMPDIR/getrecid.query.sql"
mysql -B -N  --user=$DATABASEUSER --password=$DATABASEPASSWORD mythconverg < "$TEMPDIR/getrecid.query.sql" > "$TEMPDIR/recid.txt" 

fi

__N_DESC=""
__N_TITLE=""
__N_SUBTITLE=""
__N_GENRE=""
__N_RECID=""

if [ -e "$TEMPDIR/desc.txt" ] ; then
    __N_DESC=`cat "$TEMPDIR/desc.txt"`
fi

if [ -e "$TEMPDIR/subtitle.txt" ] ; then
    __N_SUBTITLE=`cat "$TEMPDIR/subtitle.txt"`
fi    
if [ -e "$TEMPDIR/title.txt" ] ; then
    __N_TITLE=`cat "$TEMPDIR/title.txt"`
fi
if [ -e "$TEMPDIR/category.txt" ] ; then
    __N_GENRE=`cat "$TEMPDIR/category.txt"`
fi
if [ -e "$TEMPDIR/recid.txt" ] ; then
    __N_RECID=`cat "$TEMPDIR/recid.txt"`
fi
#    logging ${__N_TITLE}
#    if [ -n "${__N_TITLE}" ] ; then
#      change_arg_file "$TEMPDIR/title.txt"
#ARG_TITLE=$(change_arg_file "$TEMPDIR/title.txt")
#ARG_METADATA+=(-metadata:g)
#ARG_METADATA+=(real_title="${ARG_TITLE}")
if [ __xxx__"${__N_TITLE}" != __xxx__ ] ; then
    #ARG_TITLE=$(change_arg_file "$TEMPDIR/title.txt")
    #ARG_METADATA+=(-metadata:g)
    #ARG_METADATA+=(real_title="${ARG_TITLE}")
    __N_TITLE=`echo ${__N_TITLE} | sed s/\"/”/g `
    ARG_TITLE="${__N_TITLE}"
    ARG_METADATA+=(-metadata:g)
    ARG_METADATA+=("real_title=${__N_TITLE}")
fi
#      logging ${ARG_TITLE}
#    fi
if [ -n "${__N_GENRE}" ] ; then
    ARG_GENRE=$(change_arg_file "$TEMPDIR/category.txt")
    ARG_METADATA+=(-metadata:g)
    ARG_METADATA+=("genre=${__N_GENRE}")
    #      logging ${ARG_GENRE}
fi
if [ -n "${__N_SUBTITLE}" ] ; then
    #ARG_SUBTITLE=$(change_arg_file "$TEMPDIR/subtitle.txt")
    #__TMPARG_TITLE="${ARG_TITLE}:${ARG_SUBTITLE}" 
    __N_SUBTITLE=`echo ${__N_SUBTITLE} | sed s/\"/”/g `
    __TMPARG_TITLE="${__N_TITLE}: ${__N_SUBTITLE}" 

    ARG_METADATA+=(-metadata:g)
    ARG_METADATA+=("title=${__TMPARG_TITLE}")
    ARG_METADATA+=(-metadata:g)
    #ARG_METADATA+=(subtitle="${ARG_SUBTITLE}")
    ARG_METADATA+=("subtitle=${__N_SUBTITLE}")
else
    ARG_METADATA+=(-metadata:g)
    #ARG_METADATA+=(title="${ARG_TITLE}")
    ARG_METADATA+=("title=${__N_TITLE}")
    #      logging ${ARG_SUBTITLE}
fi
if [ __xxx__"${__N_DESC}" != __xxx__ ] ; then
    #      ARG_DESC=$(change_arg_description "$TEMPDIR/desc.txt")
    #      ARG_METADATA+=(-metadata:g)
    #      ARG_METADATA+=(description="${ARG_DESC}")
    __N_DESC=`echo ${__N_DESC} | sed s/\"/”/g `
    ARG_METADATA+=(-metadata:g)
    ARG_METADATA+=("DESCRIPTION=${__N_DESC}")
    #      logging ${ARG_DESC}
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

if [ -z "${ARG_STARTTIME}" ] ; then
    ARG_STARTTIME="${I_STARTTIME}"
fi
if	 [ -n "${__N_RECID}" ] ; then
      ARG_RECID=${__N_RECID}
      ARG_METADATA+=(-metadata:g)
      ARG_METADATA+=("recorded_id=${ARG_RECID}")
#      logging ${ARG_GENRE}
fi


logging "TITLE:"
logging "${__N_TITLE}"
logging "START:"
logging "${ARG_STARTTIME}"
logging "SUBTITLE:"
logging "${__N_SUBTITLE}"
#logging "DESCRIPTION:"
#logging "${ARG_DESC}"

#if [ "__x__${ARG_DESC}" = "__x__" ] ; then
#   ARG_DESC=" "
#fi
#ARG_DESC2=`echo -e "${ARG_DESC}"`

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
    echo " "
    echo " --ignore-decode-errors | --ignore-errors : Make movie even some errors happened."
    echo " --drop-broken | -d_b                     : Drop corrupt (broken) frame(s) when encoding."
    echo " --no-drop-broken | -nd_b                 : Dont drop corrupt (broken) frame(s) when encoding (default)."
    echo " --10bit                                  : Encode 10bit per pixel encoding (default disabled)."
    echo " --x265                                   : Use X265 for encoding (default x264)."
    echo " --x265-10                                : Use X265 (HEVC) 10bit per pixel encoding (default disabled)."
    echo " --av1                                    : Use SVT-AV1 (AV1) 10bit per pixel encoding ."
    echo " --noskip   | --no-skip                   : Not skip (mostly 15Sec.) from head of source."
    echo " --skip_sec | --skip-sec sec              : Skip sec  from head of source."
    echo " --prefetch MB | --prefetch-mb MB         : Prefetch source video up to MB mega bytes.(default 0)." 
    echo " --jobid [MYTHTV's JOBID]                 : Set JOBID from MythTV.Query some metadatas from MythTV's Database."
    echo " --title 'title'                          : Set title for output movie,"
    echo " --desc 'DESCRIPTION'                     : Set DESCRIPTION for output movie,"
    echo " --subtitle 'SUBTITLE'                    : Set SUB TITLE for output movie,"
    echo " --onair 'TIME'                           : Set on air time  for output movie,"
    echo " --cmcut : Perform CM CUT.(DANGER!) Seems to be imcomplete audio(s) at ISDB/Japan"
    echo " --no-cmcut : DO NOT Perform CM CUT.(Default)"
    echo " --db    : Use MythTV's database to manage trancoded video.(Default)"
    echo " --nodb  : Don't use MythTV's database and not manage trancoded video.(not default, useful for manual transcoding)"
    echo " --threads threads : Set threads for x264/x265 video encoder. (Default = 4)"
    echo " --pool-threads threads : Set pool threads for x265 video encoder. (Default = 4)"
    echo " --frame-threads threads : Set frame threads for x265 video encoder. (Default = 4)"
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
logging "`printf "BASENAME=%s STARTTIME=%s" ${BASENAME} ${I_STARTTIME}`"

# play nice with other processes
EXECUTE_PREFIX_COMMANDS=""

if [ -x "${NICE_CMD}" ] ; then
    if [ ${NICE_VALUE} -ge -20 ] ; then
        if [ ${NICE_VALUE} -le 20 ] ; then
	    EXECUTE_PREFIX_COMMANDS="${EXECUTE_PREFIX_COMMANDS} ${NICE_CMD} -n ${NICE_VALUE}"
	fi
    fi
fi


IONICE_ARGS=""
if [ -x "${IONICE_CMD}" ] ; then
    if [ __xxx__ != __xxx__${IONICE_CLASS} ] ; then
        IONICE_ARGS="${IONICE_ARGS} -c ${IONICE_CLASS}"
    fi
    if [ ${IONICE_VALUE} -gt 0 ] ; then
        if [ ${IONICE_VALUE} -le 7 ] ; then
            IONICE_ARGS="${IONICE_ARGS} -n ${IONICE_VALUE}"
	fi
    fi
    if [ "__xxx__${IONICE_ARGS}" != __xxx__ ] ; then
        EXECUTE_PREFIX_COMMANDS="${EXECUTE_PREFIX_COMMANDS} ${IONICE_CMD} ${IONICE_ARGS} -t"
    fi
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

## Check soruce
X_FFPROBE_STREAM=`${FFPROBE_CMD} -i "$DIRNAME2/$SRC2" 2>&1 | grep Stream`
declare -a __STREAMS
declare -a _AUDIO_ARGS
declare -a _VIDEO_ARGS

readarray __STREAMS <<< ${X_FFPROBE_STREAM}
declare -a __TMP_X

_AUDIO_STREAMS=1
_VIDEO_STREAMS=0

## Check stream(s)
case "$ENCMODE" in
   "ANIME" | "LIVE_MID" )
   AUDIOBITRATE=192
   AUDIOCUTOFF=22050
   ;;
   "ANIME_HIGH" | "LIVE_HIGH" | "LIVE_HD_HIGH"  | "LIVE_HD_MID" | "LIVE_SD_HIGH" | "ANIME_SD_HIGH" )
   AUDIOBITRATE=224
   AUDIOCUTOFF=23000
   ;;
   "ANIME_HIGH_HW" | "LIVE_HIGH_HW" | "LIVE_HD_HIGH_HW" )
   AUDIOBITRATE=224
   AUDIOCUTOFF=23000
   ;;
   "LIVE_HD_MID_HW2" | "LIVE_SD_HIGH_HW2"  | "LIVE_HD_MID_HW" | "LIVE_SD_HIGH_HW" )
   AUDIOBITRATE=224
   AUDIOCUTOFF=23000
   ;;
   * )
   AUDIOBITRATE=192
   AUDIOCUTOFF=22050
   ;;
esac
for _x in "${__STREAMS[@]}" ; do
    __IS_AUDIO=`echo "${_x}" | grep Audio`
    if [ "__x__${__IS_AUDIO}" != "__x__" ] ; then
        readarray -d "," __TMP_X <<< ${__IS_AUDIO}
	__TMP_AUDIO_CH=`echo ${__TMP_X[2]}`
	case "$__TMP_AUDIO_CH" in
	    "5.1," )
	       _AUDIO_ARGS+=(-c:a:$_AUDIO_STREAMS)
	       _AUDIO_ARGS+=(aac)
	       _AUDIO_ARGS+=(-ar:$_AUDIO_STREAMS)
	       _AUDIO_ARGS+=(48000)
	       _AUDIO_ARGS+=(-ac:$_AUDIO_STREAMS)
	       _AUDIO_ARGS+=(6)
	       _AUDIO_ARGS+=(-ab:$_AUDIO_STREAMS)
	       typeset -i __TMP_ABITRATE
	       __TMP_ABITRATE=`calc -d ${AUDIOBITRATE} * 3 | tr -d [:space:]`
	       _AUDIO_ARGS+=("${__TMP_ABITRATE}k")
	       ;;
           *)
	       _AUDIO_ARGS+=(-c:a:$_AUDIO_STREAMS)
	       _AUDIO_ARGS+=(aac)
	       _AUDIO_ARGS+=(-ar:$_AUDIO_STREAMS)
	       _AUDIO_ARGS+=(48000)
	       _AUDIO_ARGS+=(-ac:$_AUDIO_STREAMS)
	       _AUDIO_ARGS+=(2)
	       _AUDIO_ARGS+=(-ab:$_AUDIO_STREAMS)
	       _AUDIO_ARGS+=("${AUDIOBITRATE}k")
	       ;;
	esac
	let _AUDIO_STREAMS++
    fi
done
_AUDIO_ARGS+=(-af)
_AUDIO_ARGS+=(aresample=async=1:min_hard_comp=0.1:first_pts=0)

__AUDIO_ARGS=`echo ${_AUDIO_ARGS[@]}`

if test $NOENCODE -eq 0; then


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
   VIDEO_QUANT=23.0
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
   VIDEO_QUANT=22.0
   VIDEO_MINQ=13
   VIDEO_MAXQ=30
   SVTAV1_VIDEO_QUANT=33.0
   SVTAV1_VIDEO_MINQ=0
   SVTAV1_VIDEO_MAXQ=46
   
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
   VIDEO_QUANT=22.7
   VIDEO_MINQ=14
   VIDEO_MAXQ=35
   SVTAV1_VIDEO_QUANT=36.0
   SVTAV1_VIDEO_MINQ=8
   SVTAV1_VIDEO_MAXQ=53
   
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
   VIDEO_QUANT=21.0
   VIDEO_MINQ=12
   VIDEO_MAXQ=33
   SVTAV1_VIDEO_QUANT=28.0
   SVTAV1_VIDEO_MINQ=0
   SVTAV1_VIDEO_MAXQ=45
   
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
   SVTAV1_VIDEO_QUANT=28.0
   SVTAV1_VIDEO_MINQ=0
   SVTAV1_VIDEO_MAXQ=45

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
   OUT_WIDTH=720
   OUT_HEIGHT=480
   SCALER_MODE="lanczos"
   
  #X264_BITRATE=3500
   VIDEO_FILTERCHAIN0="crop=out_w=640:out_h=480:y=480:keep_aspect=1,"
   VIDEO_FILTERCHAINX=""
   VIDEO_FILTERCHAIN_NOSCALE=0
   VIDEO_FILTERCHAIN_NOCROP=1
   ;;
   "ANIME_SD_HIGH" )
   VIDEO_QUANT=20.5
   VIDEO_MINQ=12
   VIDEO_MAXQ=28
   VIDEO_AQSTRENGTH=0.70
   VIDEO_QCOMP=0.75
   VIDEO_SCENECUT=25
   VIDEO_REF_FRAMES=6
   VIDEO_BFRAMES=4
   OUT_WIDTH=720
   OUT_HEIGHT=480
   SCALER_MODE="lanczos"
   
  #X264_BITRATE=3500
   VIDEO_FILTERCHAIN0="crop=out_w=640:out_h=480:y=480:keep_aspect=1,"
   VIDEO_FILTERCHAINX=""
   VIDEO_FILTERCHAIN_NOSCALE=0
   VIDEO_FILTERCHAIN_NOCROP=1
   ;;
   "LIVE_SD_MID" )
   VIDEO_QUANT=22.0
   VIDEO_MINQ=12
   VIDEO_MAXQ=27
   VIDEO_AQSTRENGTH=1.00
   VIDEO_QCOMP=0.75
   VIDEO_SCENECUT=40
   VIDEO_REF_FRAMES=5
   VIDEO_BFRAMES=5
   OUT_WIDTH=720
   OUT_HEIGHT=480
   SCALER_MODE="lanczos"
   
  #X264_BITRATE=3500
   VIDEO_FILTERCHAIN0="crop=out_w=640:out_h=480:y=480:keep_aspect=1,"
   VIDEO_FILTERCHAINX=""
   VIDEO_FILTERCHAIN_NOSCALE=0
   VIDEO_FILTERCHAIN_NOCROP=1
   ;;
   "LIVE_MID" | "LIVE_MID_HW" | "LIVE_MID_HW2" | "LIVE_MID_FAST" )
#   VIDEO_QUANT=26.5
   VIDEO_QUANT=26.5
   VIDEO_MINQ=13
   VIDEO_MAXQ=40
   SVTAV1_VIDEO_QUANT=37.0
   SVTAV1_VIDEO_MINQ=10
   SVTAV1_VIDEO_MAXQ=55
   
   VIDEO_AQSTRENGTH=1.10
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
   SVTAV1_VIDEO_QUANT=43.0
   SVTAV1_VIDEO_MINQ=10
   #SVTAV1_VIDEO_MAXQ=-1
   
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




if test $IS_VFR -eq 0; then
    if test $USE_60FPS -eq 0 ; then
        FRAMERATE="-r:v 30000/1001"
        VIDEO_FILTERCHAIN_DEINT="yadif"
        VIDEO_FILTERCHAIN_DEINT_VAAPI="deinterlace_vaapi=mode=motion_adaptive"
    else
        FRAMERATE="-r:v 60000/1001"
        VIDEO_FILTERCHAIN_DEINT="yadif=mode=send_field"
        VIDEO_FILTERCHAIN_DEINT_VAAPI="deinterlace_vaapi=rate=frame"
    fi
else
    if test $USE_60FPS -eq 0 ; then
        FRAMERATE="-fps_mode vfr"
        VIDEO_FILTERCHAIN_DEINT="yadif,vfrdet"
        VIDEO_FILTERCHAIN_DEINT_VAAPI="deinterlace_vaapi=mode=motion_adaptive,vfrdet"
    else
        FRAMERATE="-fps_mode vfr"
        VIDEO_FILTERCHAIN_DEINT="yadif=mode=send_field,vfrdet"
        VIDEO_FILTERCHAIN_DEINT_VAAPI="deinterlace_vaapi=rate=frame,vfrdet"
    fi
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

typeset -i __X264_BLURAY_COMPAT
__X264_BLURAY_COMPAT=0

__X264_DIRECT_PRED="auto"
__X264_PRESET="slow"

typeset -i __X264_AQ_MODE
__X264_AQ_MODE=-1

__X264_PSY_RD=""
typeset -i __X264_MBTREE
__X264_MBTREE=-1
typeset -i __X264_8x8DCT
__X264_8x8DCT=-1
typeset -i __X264_TRELLIS
__X264_TRELLIS=-1
__X264_PARTITIONS="all"

__FORCE_SAR=""

case "$x" in
   ANIME )
     #X264_DIRECT="--direct auto"
     #X264_BFRAMES="--bframes 6 --b-bias -2 --b-adapt 2"
     #X264_PRESETS="--profile ${X264_PROFILE} --keyint 300 --min-keyint 24 --scenecut 30 --trellis 2"
     #X264_ENCPRESET="--preset slow --ref 6 --8x8dct --partitions all"
     
     __X264_BLURAY_COMPAT=1
     __X264_TRELLIS=2
     __X264_8x8DCT=1
     VIDEO_REF_FRAMES=6
     
     X265_AQ_STRENGTH=0.9
     X265_QP_ADAPTATION_RANGE=1.25
     if [ $USE_60FPS -ne 0 ] ; then
         X265_PRESET="superfast"
	 SVTAV1_PRESET="fast"
	 #TARGET_BITRATE_KBIT=1500
     else
         X265_PRESET="veryfast"
	 SVTAV1_PRESET="medium"
	 #TARGET_BITRATE_KBIT=1300
     fi
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
     if [ ${USE_SVTAV1} -ne 0 ] ; then
	 IS_CRF=1
	 if [ ${IS_CRF} -ne 0 ] ; then
	      # ACT AS LIMITER.
	      SVTAV1_VIDEO_QUANT=`calc -d "${SVTAV1_VIDEO_QUANT} * 1.25" | tr -d [:space:]`
	      SVTAV1_TUNE="anime_grain"
	      SVTAV1_DISABLE_TEMPORAL_FILTERING=1
	      if [ $USE_60FPS -ne 0 ] ; then
	      	 TARGET_BITRATE_KBIT=2300
	      else
	      	 TARGET_BITRATE_KBIT=1350    
	      fi
	else      
	      # ACT AS AVERAGE bitrate.
	      SVTAV1_TUNE="nograin"
	      #SVTAV1_DISABLE_TEMPORAL_FILTERING=1
	      if [ $USE_60FPS -ne 0 ] ; then
	      	 TARGET_BITRATE_KBIT=1650
	      else
	      	 TARGET_BITRATE_KBIT=1100    
	      fi
	 fi
     else
	 IS_CRF=0
     fi
     #X264_DIRECT="--direct auto"
     #X264_BFRAMES="--bframes 5 --b-bias -2 --b-adapt 2"
     #X264_PRESETS="--profile:v ${X264_PROFILE} --8x8dct --keyint 300 --min-keyint 24 --scenecut 40 --trellis 2"
     #X264_ENCPRESET="--preset slow --ref 5 --8x8dct --partitions all"

     __X264_BLURAY_COMPAT=1
     __X264_TRELLIS=2
     VIDEO_REF_FRAMES=5
     __X264_8x8DCT=1
     SVTAV1_AQ_STRENGTH=1.15

     if [ $USE_60FPS -ne 0 ] ; then
         X265_PRESET="veryfast"
	 #SVTAV1_PRESET="fast"
	 SVTAV1_PRESET="veryfast"
     else
         X265_PRESET="faster"
	 #SVTAV1_PRESET="fast"
	 SVTAV1_PRESET="veryfast"
     fi
     X265_AQ_STRENGTH=0.95
     X265_QP_ADAPTATION_RANGE=1.15
     #X265_AQ_MODE=4
     X265_AQ_MODE=3
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
     #X264_DIRECT="--direct auto --aq-mode 3"
     #X264_BFRAMES="--bframes 6 --b-bias -2 --b-adapt 2 --psy-rd 0.5:0.2"
     #X264_PRESETS="--profile:v ${X264_PROFILE} --keyint 300 --min-keyint 24 --scenecut 40 --trellis 2"
     #X264_ENCPRESET="--preset slow --ref 6 --8x8dct --partitions all"
     __X264_BLURAY_COMPAT=1
     
     __X264_AQ_MODE=3
     __X264_TRELLIS=2
     VIDEO_REF_FRAMES=5
     __X264_8x8DCT=1
     __X264_MBTREE=1
     __X264_PSY_RD="0.8:0.4"
     SVTAV1_AQ_STRENGTH=1.2
     if [ $USE_60FPS -ne 0 ] ; then
         X265_PRESET="veryfast"
	 SVTAV1_PRESET="medium"
	 #TARGET_BITRATE_KBIT=15000    
     else
         X265_PRESET="faster"
	 SVTAV1_PRESET="medium"
	 #TARGET_BITRATE_KBIT=10000    
     fi
     X265_AQ_STRENGTH=0.80
     X265_QP_ADAPTATION_RANGE=1.20
     
     HW_SCALING="No"
     HWACCEL_DEC="NONE"
     FFMPEG_ENC=1
     HWENC=0
     HWDEC=0
     
   ;;
   LIVE_HD_MID )
     if [ ${USE_SVTAV1} -ne 0 ] ; then
	 IS_CRF=0
	 if [ ${IS_CRF} -ne 0 ] ; then
	      # ACT AS LIMITER.
	      SVTAV1_VIDEO_QUANT=`calc -d "${SVTAV1_VIDEO_QUANT} * 1.15" | tr -d [:space:]`
	      SVTAV1_TUNE=NO_GRAIN_MS_SSIM
	      if [ $USE_60FPS -ne 0 ] ; then
	      	 TARGET_BITRATE_KBIT=6000
	      else
	      	 TARGET_BITRATE_KBIT=3200    
	      fi
	else      
	      # ACT AS AVERAGE bitrate.
	      if [ $USE_60FPS -ne 0 ] ; then
	      	 TARGET_BITRATE_KBIT=2600
	      else
	      	 TARGET_BITRATE_KBIT=1800    
	      fi
	 fi
     else
	 IS_CRF=1
     fi
     #IS_CRF=0
     #X264_DIRECT="--direct auto"
     #X264_BFRAMES="--bframes 5 --b-bias -1 --b-adapt 2 --psy-rd 0.5:0.2"
     #X264_PRESETS="--profile:v ${X264_PROFILE} --keyint 300 --min-keyint 24 --scenecut 45 --trellis 2"
     #X264_ENCPRESET="--preset slow --ref 5 --8x8dct --partitions all" 
     SVTAV1_AQ_STRENGTH=1.3
     
     SVTAV1_TEMPORAL_FILTERING_STRENGTH=1

     if [ $USE_60FPS -ne 0 ] ; then
         X265_PRESET="superfast"
	 SVTAV1_PRESET="faster"
     else
         X265_PRESET="veryfast"
	 SVTAV1_PRESET="faster"
     fi
     
     __X264_BLURAY_COMPAT=1
     
     __X264_TRELLIS=2
     __X264_8x8DCT=1
     __X264_MBTREE=1
     __X264_PSY_RD="0.8:0.4"

     X265_AQ_STRENGTH=1.00
     X265_QP_ADAPTATION_RANGE=1.35
     X265_AQ_MODE=3
     
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
     VIDEO_MAXQ=40
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
     #X264_DIRECT="--direct auto"
     #X264_BFRAMES="--bframes 5 --b-bias -1 --b-adapt 2"
     SVTAV1_AQ_STRENGTH=1.5
     if [ $USE_60FPS -ne 0 ] ; then
         X265_PRESET="superfast"
	 SVTAV1_PRESET="ultrafast"
     else
         X265_PRESET="veryfast"
	 SVTAV1_PRESET="superfast"
	 #TARGET_BITRATE_KBIT=1250     
     fi
     SVTAV1_TEMPORAL_FILTERING_STRENGTH=3
   ;;
   LIVE_HIGH )
     #X264_DIRECT="--direct spatial --aq-mode 3"
     #X264_BFRAMES="--bframes 5 --b-bias -1 --b-adapt 2 --psy-rd 1.2:0.4"
     #X264_PRESETS="--profile ${X264_PROFILE} --keyint 300 --min-keyint 24 --scenecut 42 --trellis 2"
     #X264_ENCPRESET="--preset slow --ref 5 --8x8dct --partitions all"
     #FFMPEG_X264_HEAD="-profile:v ${X264_PROFILE} -preset slow -direct-pred auto -crf ${VIDEO_QUANT}"
     #FFMPEG_X264_AQ="-trellis 2 -partitions all  -8x8dct 1 -mbtree 1 -psy-rd 1.2:0.6"
     #__X264_BLURAY_COMPAT=1
     __X264_AQ_MODE=3
     __X264_TRELLIS=2
     __X264_8x8DCT=1
     __X264_MBTREE=1
     __X264_PSY_RD="1.2:0.6"
     
     X265_AQ_STRENGTH=0.75
     X265_QP_ADAPTATION_RANGE=1.2
     SVTAV1_AQ_STRENGTH=1.3 
     if [ $USE_60FPS -ne 0 ] ; then
         X265_PRESET="veryfast"
	 SVTAV1_PRESET="fast"
     else
         X265_PRESET="faster"
	 SVTAV1_PRESET="medium"
     fi
     #TARGET_BITRATE_KBIT=2500     
     SVTAV1_TEMPORAL_FILTERING_STRENGTH=3
     
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
     #X264_DIRECT="--direct spatial --aq-mode 3"
     #X264_BFRAMES="--bframes 5 --b-bias -1 --b-adapt 2 --psy-rd 1.2:0.4"
     #X264_PRESETS="--profile ${X264_PROFILE} --keyint 300 --min-keyint 24 --scenecut 42 --trellis 2"
     #X264_ENCPRESET="--preset slow --ref 5 --8x8dct --partitions all"
     #FFMPEG_X264_HEAD="-profile:v ${X264_PROFILE} -preset slow -direct-pred auto -crf ${VIDEO_QUANT}  -sar 32/27"
     #FFMPEG_X264_AQ="-trellis 2 -partitions all  -8x8dct 1 -mbtree 1 -psy-rd 1.0:0.6"
     __FORCE_SAR="32/27"
     __X264_AQ_MODE=3
     __X264_TRELLIS=2
     __X264_8x8DCT=1
     __X264_MBTREE=1
     __X264_PSY_RD="1.0:0.6"
     VIDEO_REF_FRAMES=5
     #TARGET_BITRATE_KBIT=900     

     X265_AQ_STRENGTH=0.70
     X265_QP_ADAPTATION_RANGE=1.05
     X265_PRESET="faster"
     SVTAV1_AQ_STRENGTH=1.2
     SVTAV1_PRESET="medium"

     HWENC_PARAM=" -coder cavlc -aspect ${VIDEO_ASPECT} -qp 21 -quality 4 "
     HW_SCALING="No"
     HWACCEL_DEC="NONE"
     FFMPEG_ENC=1
     HWENC=0
     HWDEC=0
   ;;
   ANIME_SD_HIGH )
       #X264_DIRECT="--direct spatial --aq-mode 3"
       #X264_BFRAMES="--bframes 5 --b-bias -1 --b-adapt 2 --psy-rd 1.2:0.4"
       #X264_PRESETS="--profile ${X264_PROFILE} --keyint 300 --min-keyint 24 --scenecut 25 --trellis 2"
       #X264_ENCPRESET="--preset slow --ref 5 --8x8dct --partitions all"
       #FFMPEG_X264_HEAD="-profile:v ${X264_PROFILE} -preset slow -direct-pred auto -crf ${VIDEO_QUANT}  -sar 32/27"
       #FFMPEG_X264_AQ="-trellis 2 -partitions all  -8x8dct 1 -mbtree 1 -psy-rd 1.0:0.6"
       __X264_DIRECT_PRED="spatial"
       __FORCE_SAR="32/27"
       #__X264_AQ_MODE=3
       __X264_TRELLIS=2
       __X264_8x8DCT=1
       #__X264_MBTREE=1
       __X264_PSY_RD="1.0:0.6"
       VIDEO_REF_FRAMES=5
     
       X265_AQ_STRENGTH=0.70
       X265_QP_ADAPTATION_RANGE=1.30
       X265_PRESET="fast"
       
       SVTAV1_TUNE="anime"
       SVTAV1_AQ_STRENGTH=1.2
       SVTAV1_PRESET="medium"
       #TARGET_BITRATE_KBIT=800     
       
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
   LIVE_SD_MID )
     #X264_DIRECT="--direct spatial --aq-mode 3"
     #X264_BFRAMES="--bframes 5 --b-bias -1 --b-adapt 2 --psy-rd 1.2:0.4"
     #X264_PRESETS="--profile ${X264_PROFILE} --keyint 300 --min-keyint 24 --scenecut 42 --trellis 2"
     #X264_ENCPRESET="--preset slow --ref 5 --8x8dct --partitions all"
     #FFMPEG_X264_HEAD="-profile:v ${X264_PROFILE} -preset slow -direct-pred auto -crf ${VIDEO_QUANT}  -sar 32/27"
     #FFMPEG_X264_AQ="-trellis 2 -partitions all  -8x8dct 1 -mbtree 1 -psy-rd 1.0:0.6"
     
     #__X264_DIRECT_PRED="spatial"
     __FORCE_SAR="32/27"
     #__X264_AQ_MODE=3
     __X264_TRELLIS=2
     __X264_8x8DCT=1
     __X264_MBTREE=1
     __X264_PSY_RD="1.2:0.4"
     VIDEO_REF_FRAMES=5
     #TARGET_BITRATE_KBIT=600     
     
     X265_AQ_STRENGTH=1.00
     X265_QP_ADAPTATION_RANGE=1.25
     X265_PRESET="faster"
     
     #SVTAV1_TUNE="anime"
     SVTAV1_AQ_STRENGTH=1.2
     SVTAV1_PRESET="medium"
     
     HWENC_PARAM=" -coder cavlc -aspect ${VIDEO_ASPECT} -qp 21 -quality 4 "
     HW_SCALING="No"
     HWACCEL_DEC="NONE"
     FFMPEG_ENC=1
     HWENC=0
     HWDEC=0
   ;;
   LIVE_MID | LIVE_MID_FAST )
     if [ ${USE_SVTAV1} -ne 0 ] ; then
	 IS_CRF=0
     else
	 IS_CRF=1
     fi
     #X264_DIRECT="--direct auto"
     #X264_BFRAMES="--bframes 5 --b-bias 0 --b-adapt 2"
     #X264_PRESETS="--profile ${X264_PROFILE} --keyint 300 --min-keyint 24 --scenecut 48 --trellis 2"
     #X264_ENCPRESET="--preset medium --ref 5 --8x8dct"
     #FFMPEG_X264_HEAD="-profile:v ${X264_PROFILE} -preset slow -direct-pred auto -crf ${VIDEO_QUANT}"
     #FFMPEG_X264_AQ="-trellis 2 -partitions all  -8x8dct 1 -mbtree 1 -psy-rd 0.6:0.2"

     #__X264_DIRECT_PRED="spatial"
     #__X264_AQ_MODE=3
     __X264_TRELLIS=2
     __X264_8x8DCT=1
     __X264_MBTREE=1
     __X264_PSY_RD="0.6:0.2"
     VIDEO_REF_FRAMES=5
     #TARGET_BITRATE_KBIT=900     
     if test "__n__${x}" = "__n__LIVE_MID_FAST" ; then
         X265_PRESET="superfast"
	 SVTAV1_PRESET="veryfast"
	 #SVTAV1_PRESET="faster"
	 #SVTAV1_ENABLE_QM=0
     else
         X265_PRESET="veryfast"
	 SVTAV1_PRESET="medium"
	 #SVTAV1_ENABLE_QM=0
     fi
     if [ $USE_60FPS -ne 0 ] ; then
	 #TARGET_BITRATE_KBIT=1800
	 TARGET_BITRATE_KBIT=1350
     else
	 #TARGET_BITRATE_KBIT=1000
	 TARGET_BITRATE_KBIT=750
     fi
     X265_AQ_STRENGTH=${VIDEO_AQSTRENGTH}
     X265_QP_ADAPTATION_RANGE=1.50
     X265_AQ_MODE=3

     SVTAV1_DETAIL_BOOST=0
     SVTAV1_AQ_STRENGTH=3.0
     SVTAV1_TEMPORAL_FILTERING_STRENGTH=3
     
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
     #X264_DIRECT="--direct auto --aq-mode 3"
     #X264_BFRAMES="--bframes 8 --b-bias 0 --b-adapt 2"
     #X264_PRESETS="--profile ${X264_PROFILE} --keyint 300 --min-keyint 24 --scenecut 40 --trellis 2"
     #X264_ENCPRESET="--preset medium --8x8dct --partitions all"
     __X264_AQ_MODE=3
     __X264_PRESET="medium"
     __X264_TRELLIS=2
     __X264_8x8DCT=1
     #__X264_MBTREE=1
     #__X264_PSY_RD="0.6:0.2"
     #VIDEO_REF_FRAMES=5
     VIDEO_SCENECUT=40
     SVTAV1_DETAIL_BOOST=0
     
     X265_PRESET="ultrafast"
     SVTAV1_PRESET="ultrafast"
     SVTAV1_AQ_STRENGTH="`calc -d ${VIDEO_AQSTRENGTH}+0.5 | tr -d [:space:]`"
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

######### x264 HEAD
FFMPEG_X264_HEAD+=(-profile:v)
FFMPEG_X264_HEAD+=("${X264_PROFILE}")

if [ __xxx__${__X264_PRESET} != __xxx__ ] ; then
    FFMPEG_X264_HEAD+=(-preset)
    FFMPEG_X264_HEAD+=(${__X264_PRESET})
fi
if [ __xxx__${__X264_DIRECT_PRED} != __xxx__ ] ; then
    FFMPEG_X264_HEAD+=(-direct-pred)
    FFMPEG_X264_HEAD+=(${__X264_DIRECT_PRED})
fi
if [ ${IS_CRF} -ne 0 ] ; then
    FFMPEG_X264_HEAD+=(-crf)
    FFMPEG_X264_HEAD+=("${VIDEO_QUANT}")
else
    FFMPEG_X264_HEAD+=(-qp)
    FFMPEG_X264_HEAD+=("${VIDEO_QUANT}")
fi
if [ ${__X264_BLURAY_COMPAT} -ne 0 ] ; then
    FFMPEG_X264_HEAD+=(-bluray-compat)
    FFMPEG_X264_HEAD+=(1)
fi

if [ "__xxx__${__FORCE_SAR}" != "__xxx__" ] ; then
    FFMPEG_X264_HEAD+=(-sar)
    FFMPEG_X264_HEAD+=("${__FORCE_SAR}")
fi


FFMPEG_X264_PARAM2=""
if [ ${__X264_AQ_MODE} -ge 0 ] ; then
    FFMPEG_X264_AQ+=(-aq-mode)
    FFMPEG_X264_AQ+=(${__X264_AQ_MODE})
    if [ "__xxx__${FFMPEG_X264_PARAM2}" != "__xxx__" ] ; then
	FFMPEG_X264_PARAM2="${FFMPEG_X264_PARAM2}:"
    fi
    FFMPEG_X264_PARAM2="${FFMPEG_X264_PARAM2}aq-mode=${__X264_AQ_MODE}"
fi
if [ "__xxx__${VIDEO_AQSTRENGTH}" != "__xxx__" ] ; then
    FFMPEG_X264_AQ+=(-aq-strength)
    FFMPEG_X264_AQ+=("${VIDEO_AQSTRENGTH}")
    if [ "__xxx__${FFMPEG_X264_PARAM2}" != "__xxx__" ] ; then
	FFMPEG_X264_PARAM2="${FFMPEG_X264_PARAM2}:"
    fi
    FFMPEG_X264_PARAM2="${FFMPEG_X264_PARAM2}aq-strength=${VIDEO_AQSTRENGTH}"
fi
if [ ${__X264_TRELLIS} -ge 0 ] ; then
    FFMPEG_X264_AQ+=(-trellis)
    FFMPEG_X264_AQ+=(${__X264_TRELLIS})
    if [ "__xxx__${FFMPEG_X264_PARAM2}" != "__xxx__" ] ; then
	FFMPEG_X264_PARAM2="${FFMPEG_X264_PARAM2}:"
    fi
    FFMPEG_X264_PARAM2="${FFMPEG_X264_PARAM2}trellis=${__X264_TRELLIS}"
fi
if [ ${VIDEO_SCENECUT} -ge -1 ] ; then
    FFMPEG_X264_AQ+=(-sc_threshold)
    FFMPEG_X264_AQ+=(${VIDEO_SCENECUT})
    if [ "__xxx__${FFMPEG_X264_PARAM2}" != "__xxx__" ] ; then
	FFMPEG_X264_PARAM2="${FFMPEG_X264_PARAM2}:"
    fi
    FFMPEG_X264_PARAM2="${FFMPEG_X264_PARAM2}scenecut=${VIDEO_SCENECUT}"
fi    
if [ ${VIDEO_REF_FRAMES} -ge 0 ] ; then
    FFMPEG_X264_AQ+=(-ref)
    FFMPEG_X264_AQ+=(${VIDEO_REF_FRAMES})
    if [ "__xxx__${FFMPEG_X264_PARAM2}" != "__xxx__" ] ; then
	FFMPEG_X264_PARAM2="${FFMPEG_X264_PARAM2}:"
    fi
    FFMPEG_X264_PARAM2="${FFMPEG_X264_PARAM2}scenecut=${VIDEO_REF_FRAMES}"
fi
if [ "__xxx__${__X264_PARTITIONS}" != "__xxx__" ] ; then
    FFMPEG_X264_AQ+=(-partitions)
    FFMPEG_X264_AQ+=("${__X264_PARTITIONS}")
fi
if [ ${__X264_8x8DCT} -ge 0 ] ; then
    FFMPEG_X264_AQ+=(-8x8dct)
    FFMPEG_X264_AQ+=(${__X264_8x8DCT})
fi
if [ "__xxx__${__X264_PSY_RD}" != "__xxx__" ] ; then
    FFMPEG_X264_AQ+=(-psy-rd)
    FFMPEG_X264_AQ+=("${__X264_PSY_RD}")
fi


#FFMPEG_X264_HEAD="-profile:v high -preset slow -direct-pred auto -crf ${VIDEO_QUANT}"

FFMPEG_X264_FRAMES1="-b-pyramid strict  -b-bias -1 -me_method umh -weightp smart"
if [ "__xxx__${FFMPEG_X264_PARAM2}" != "__xxx__" ] ; then
    FFMPEG_X264_PARAM3=":"
else
    FFMPEG_X264_PARAM3=""
fi
FFMPEG_X264_PARAM3="${FFMPEG_X264_PARAM3}bframes=${VIDEO_BFRAMES}:b-adapt=2:"
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

######### x265 HEAD
FFMPEG_X265_HEAD+=(-profile:v)
FFMPEG_X265_HEAD+=("${X265_PROFILE}")
if [ __xxx__${X265_PRESET} != __xxx__ ] ; then
    FFMPEG_X265_HEAD+=(-preset)
    FFMPEG_X265_HEAD+=(${X265_PRESET})
fi
if [ ${IS_CRF} -ne 0 ] ; then
    FFMPEG_X265_HEAD+=(-crf)
    FFMPEG_X265_HEAD+=("${VIDEO_QUANT}")
else
    FFMPEG_X265_HEAD+=(-qp)
    FFMPEG_X265_HEAD+=("${VIDEO_QUANT}")
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

DECODE_APPEND="-resync_size 5242880"

declare -a  ARG_DECODE_GENERAL_FLAGS
unset ARG_DECODE_GENERAL_FLAGS[@]

declare -a  ARG_DECODE_GENERAL_SKIP_FLAGS
unset ARG_DECODE_GENERAL_SKIP_FLAGS[@]

declare -a ARG_DECODE_SUB_FLAGS
unset ARG_DECODE_SUB_FLAGS[@]

declare -a  ARG_DECODE_SUB_SKIP_FLAGS
unset ARG_DECODE_SUB_SKIP_FLAGS[@]

declare -a  ARG_ENCODE_GENERAL_FLAGS
unset ARG_ENCODE_GENERAL_FLAGS[@]

declare -a ARG_ENCODE_SUB_FLAGS
unset ARG_ENCODE_SUB_FLAGS[@]

declare -a ARG_ENCODE_SUB_CODEC_FLAGS
unset ARG_ENCODE_SUB_CODEC_FLAGS[@]

declare -a ARG_ENCODE_SUB_DELAY_FLAGS
unset ARG_ENCODE_SUB_DELAY_FLAGS[@]

declare -a ARG_ENCODE_STREAMS
unset ARG_ENCODE_STREAMS[@]

declare -a ARG_ENCODE_VIDEO_ARGS
unset ARG_ENCODE_VIDEO_ARGS[@]

declare -a ARG_MUX_SUB_STREAM
unset ARG_MUX_SUB_STREAM[@]

declare -a ARG_MUX_SUB_TXT2
unset ARG_MUX_SUB_TXT2[@]


# Basic STREAM
ARG_ENCODE_STREAMS+=(-map:v)
ARG_ENCODE_STREAMS+=(0:0)
ARG_ENCODE_STREAMS+=(-map:a)
ARG_ENCODE_STREAMS+=(0:1)


# MUX
ARG_ENCODE_SUB_TXT2+=(-c:v)
ARG_ENCODE_SUB_TXT2+=(copy)
ARG_ENCODE_SUB_TXT2+=(-c:a)
ARG_ENCODE_SUB_TXT2+=(copy)
ARG_MUX_SUB_TXT2+=(-metadata:s:a:0)
ARG_MUX_SUB_TXT2+=(language=jpn)

# Add audio if exists.
if [ ${IS_DROP_ERROR_FRAMES} -ne 0 ] ; then
    ARG_DECODE_GENERAL_FLAGS+=(-fflags)
    ARG_DECODE_GENERAL_FLAGS+=(+discardcorrupt)
    ARG_DECODE_GENERAL_FLAGS+=(-err_detect)
    ARG_DECODE_GENERAL_FLAGS+=(+compliant)
    ARG_DECODE_GENERAL_FLAGS+=(-drop_changed)
    ARG_DECODE_GENERAL_FLAGS+=(1)
fi
if [ ${PREFETCH_MB} -gt 0 ] ; then
    __XXXTMPS=`calc -d "1024 * 1024 * ${PREFETCH_MB}"`
    if [ "___xxx___${__XXXTMPS}" != "___xxx___" ] ; then
	ARG_ENCODE_GENERAL_FLAGS+=(-read_ahead_limit)
        ARG_ENCODE_GENERAL_FLAGS+=(${__XXXTMPS})
    fi
elif [ ${PREFETCH_MB} -lt 0 ] ; then
    ARG_ENCODE_GENERAL_FLAGS+=(-read_ahead_limit)
    ARG_ENCODE_GENERAL_FLAGS+=(-1)
fi

if [ "___xxx___${VIDEO_SKIP}" != "___xxx___" ] ; then
    ARG_DECODE_GENERAL_SKIP_FLAGS+=(-ss)
    ARG_DECODE_GENERAL_SKIP_FLAGS+=(${VIDEO_SKIP})
    ARG_DECODE_SUB_SKIP_FLAGS+=(-itsoffset)
    ARG_DECODE_SUB_SKIP_FLAGS+=(${VIDEO_SKIP})
    if test $IS_COPY_SUB_AS_RAW_ARIB -ne 0 ; then
        ARG_ENCODE_SUB_DELAY_FLAGS+=(-ss)
        ARG_ENCODE_SUB_DELAY_FLAGS+=(${VIDEO_SKIP})
    else
        ARG_ENCODE_SUB_DELAY_FLAGS+=(-itsoffset)
        ARG_ENCODE_SUB_DELAY_FLAGS+=(-${VIDEO_SKIP})
    fi
fi

echo ${ARG_DECODE_GENERAL_FLAGS[@]}
echo 
echo ${ARG_DECODE_SUB_FLAGS[@]}

#ARG_DECODE_SUB_FLAGS+=(-aribb24-skip-ruby-text)
#ARG_DECODE_SUB_FLAGS+=(0)



case "$HWACCEL_DEC" in
    "VDPAU" | "vdpau" )
	DECODE_APPEND="${DECODE_APPEND} -hwaccel vdpau"
	;;
    "VAAPI" | "vaapi" )
      HWDECODE_TAG=VAAPI_${MYPID}
      DECODE_APPEND="${DECODE_APPEND} -vaapi_device:${HWDECODE_TAG} /dev/dri/renderD128" 
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
	  if [ ${USE_SVTAV1} -ne 0 ] ; then
	      # For SVT-AV1, force to encode by 10bit.
	      VIDEO_FILTERCHAIN_HWACCEL="${VIDEO_FILTERCHAIN_HWACCEL},format=yuv420p10le"
	  elif test $USE_X265 -ne 0 ; then
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
#       $ARG_DECODE_GENERAL_FLAGS[@]  ${ARG_DECODE_SUB_SKIP_FLAGS[@]} -i "$DIRNAME2/$SRC2"  \
#       -c:s webvtt \
#       -y $TEMPDIR/v1tmp.srt 

__SUB_FILE_NAME=""
if test $IS_COPY_SUB_AS_RAW_ARIB -ne 0 ; then
    __SUB_FILE_NAME="v1sub.mkv"
    ARG_ENCODE_SUB_FLAGS+=(-map:s)
    ARG_ENCODE_SUB_FLAGS+=(0:s)
    ARG_ENCODE_SUB_FLAGS+=(-c:s)
    ARG_ENCODE_SUB_FLAGS+=(copy)
else
    __SUB_FILE_NAME="v1sub.ssa"
    ARG_DECODE_SUB_FLAGS+=(-aribb24-skip-ruby-text)
    ARG_DECODE_SUB_FLAGS+=(1)
    ARG_ENCODE_SUB_FLAGS+=(-c:s)
    ARG_ENCODE_SUB_FLAGS+=(ssa)
    ARG_ENCODE_SUB_CODEC_FLAGS+=(-f)
    ARG_ENCODE_SUB_CODEC_FLAGS+=(ass)
fi    

$EXECUTE_PREFIX_COMMANDS ${FFMPEG_SUBTXT_CMD} -loglevel info \
       ${ARG_DECODE_GENERAL_SKIP_FLAGS[@]} -fix_sub_duration \
       ${ARG_DECODE_GENERAL_FLAGS[@]}  \
       ${ARG_DECODE_SUB_FLAGS[@]} \
       ${ARG_DECODE_SUB_SKIP_FLAGS[@]} \
       -i "$DIRNAME2/$SRC2"  \
       ${ARG_ENCODE_GENERAL_FLAGS[@]} \
       ${ARG_ENCODE_SUB_FLAGS[@]} \
       ${ARG_ENCODE_SUB_CODEC_FLAGS[@]} \
       -y $TEMPDIR/${__SUB_FILE_NAME}


ARG_METADATA+=(-metadata:s:a:0)
ARG_METADATA+=(language=jpn)
ARG_METADATA+=(-metadata:s:a:0)
ARG_METADATA+=(real_encoder=aac)
ARG_METADATA+=(-metadata:s:a:0)
ARG_METADATA+=(DESCRIPTION=主音声)

# ADD METADATA around AUDIO, if additional track exists.

DISPLAY_SINK_PARAM="filter_threads=${FILTER_THREADS}:filter_complex_threads=${FILTER_COMPLEX_THREADS}"

ARG_METADATA+=(-metadata:g)
ARG_METADATA+=("source=${SRC2}")

__TMPS_DECODER="${ARG_DECODE_GENERAL_SKIP_FLAGS[@]} ${ARG_DECODE_GENERAL_FLAGS[@]}"
__TMPS_DECODER_SUB="${ARG_DECODE_GENERAL_SKIP_FLAGS[@]} -fix_sub_duration ${ARG_DECODE_GENERAL_FLAGS[@]} ${ARG_DECODE_SUB_FLAGS[@]} ${ARG_DECODE_SUB_SKIP_FLAGS[@]}"
__TMPS_ENCODER="${ARG_ENCODE_GENERAL_FLAGS[@]}"

ARG_METADATA_GENERAL_DEC_OPTS=""
ARG_METADATA_VIDEO_ENC_OPTS=""

echo "${__TMPS_DECODER}" > $TEMPDIR/general_decoder_opts.txt
#if [ "___xxx___${__TMPS_DECODER}" != "___xxx___" ] ; then
#   __TMPS_X=`echo ${__TMPS_DECODER} | sed -e s/[[:blank:]]/　/g`
#   __TMPS_X=`echo ${__TMPS_X} | sed -e s/\;/；/g`
#   ARG_METADATA+=(-metadata:g)
#   ARG_METADATA+=(decoder_options=${__TMPS_X})
#   #ARG_METADATA_GENERAL_DEC_OPTS="-metadata:g decoder_opts=\"${__TMPS_DECODER}\""
#fi

echo "${__TMPS_ENCODER}" > $TEMPDIR/v_encoder_options.txt

#if [ "___xxx___${__TMPS_ENCODER}" != "___xxx___" ] ; then
#   __TMPS_X=`echo ${__TMPS_ENCODER} | sed -e s/[[:blank:]]/　/g`
#   __TMPS_X=`echo ${__TMPS_X} | sed -e s/\;/；/g`
#   ARG_METADATA+=(-metadata:s:v)
#   ARG_METADATA+=(v_encoder_options=${__TMPS_X})
#   #ARG_METADATA_VIDEO_ENC_OPTS="-metadata:s:v v_endoder_options=\"${__TMPS_ENCODER}\""
#fi
#echo "${ARG_METADATA[@]}"
#exit
__ENCODE_START_DATE=`date --rfc-3339=ns`

DISPLAY_FILTERCHAIN="${VIDEO_FILTERCHAIN_HWACCEL}"


if [ $FFMPEG_ENC -ne 0 ]; then
    if [ ${USE_SVTAV1} -ne 0 ] ; then
	
	declare -a __APPEND_ARGS_PRE
	unset __APPEND_ARGS_PRE[@]
	declare -a __APPEND_ARGS_POST
	unset __APPEND_ARGS_POST[@]
	__VCODEC_PARAMS=""
	if [ ${POOLTHREADS} -gt 0 ] ; then
	    __APPEND_ARGS_PRE+=(-threads:v)
	    __APPEND_ARGS_PRE+=(${POOLTHREADS})
	fi
	# Convert tune value from x265 to svt-av1
	__T_PRESET_VALUE="`echo ${SVTAV1_PRESET} | tr '[:upper:]' '[:lower:]'`"
	typeset -i _N_PRESET_VALUE
	_N_PRESET_VALUE=0
	case "${__T_PRESET_VALUE}" in
	    "ultrafast" )
		_N_PRESET_VALUE=13
		;;
	    "superfast" )
		_N_PRESET_VALUE=11
		;;
	    "veryfast" )
		_N_PRESET_VALUE=9
		;;
	    "faster" )
		_N_PRESET_VALUE=8
		;;
	    "fast" )
		_N_PRESET_VALUE=7
		;;
	    "medium" )
		_N_PRESET_VALUE=6
		;;
	    "slow" )
		_N_PRESET_VALUE=4
		;;
	    "slower" )
		_N_PRESET_VALUE=3
		;;
	    "veryslow" )
		_N_PRESET_VALUE=1
		;;
	    "placebo" )
		_N_PRESET_VALUE=0
		;;
	    * )
		_N_PRESET_VALUE=${SVTAV1_PRESET}
		#_N_PRESET_VALUE=7
		;;
	esac
	if [ "${SVTAV1_AQ_MODE}" -lt 0 ] ; then
		SVTAV1_AQ_MODE=0
	elif [ "${SVTAV1_AQ_MODE}" -gt 2 ]; then
		SVTAV1_AQ_MODE=2
	fi
	__VCODEC_PARAMS="aq-mode=${SVTAV1_AQ_MODE}"
	if [ ${SVTAV1_RC_MODE} -lt 0 ] ; then
	    if [ ${IS_CRF} -ne 0 ] ; then
		SVTAV1_RC_MODE=0
	    else
		SVTAV1_RC_MODE=1 # VBR
	    fi
	else
	    if [ ${SVTAV1_RC_MODE} -eq 0 ] ; then
		IS_CRF=1
		SVTAV1_RC_MODE=0
	    else
		if [ ${SVTAV1_RC_MODE} -gt 2 ] ; then
		    SVTAV1_RC_MODE=2
		fi
		IS_CRF=0
	    fi
	fi
	SVTAV1_HEAD_VALUES+=(-preset)
	SVTAV1_HEAD_VALUES+=(${_N_PRESET_VALUE})
	if [ "__xxx__${SVTAV1_VIDEO_QUANT}" != "__xxx__" ] ; then
	    SVTAV1_QUANT_VALUE=${SVTAV1_VIDEO_QUANT}
	else
	    SVTAV1_QUANT_VALUE=`calc -d "(${VIDEO_QUANT} * 1.5) + 2.0" | tr -d [:space:]`
	fi
	#echo ${SVTAV1_QUANT_VALUE}
	#exit 0
	if [ ${IS_CRF} -eq 0 ] ; then
	    SVTAV1_HEAD_VALUES+=(-qp)
	    __VCODEC_DISP_PARAMS="qp="
	else
	    SVTAV1_HEAD_VALUES+=(-crf)
	    __VCODEC_DISP_PARAMS="crf="
	fi
	SVTAV1_HEAD_VALUES+=("${SVTAV1_QUANT_VALUE}")
	__VCODEC_DISP_PARAMS="${__VCODEC_DISP_PARAMS}${SVTAV1_QUANT_VALUE}"
	if [ ${TARGET_BITRATE_KBIT} -gt 0 ] ; then
	    if [ ${IS_CRF} -eq 0 ] ; then
		__VCODEC_PARAMS="${__VCODEC_PARAMS}:tbr=${TARGET_BITRATE_KBIT}:undershoot-pct=95:overshoot-pct=90"
		__VCODEC_DISP_PARAMS="${__VCODEC_DISP_PARAMS}:target_bitrate=${TARGET_BITRATE_KBIT}kbit"
	    else
		__VCODEC_PARAMS="${__VCODEC_PARAMS}:mbr=${TARGET_BITRATE_KBIT}:undershoot-pct=95:mbr-overshoot-pct=85"
		__VCODEC_DISP_PARAMS="${__VCODEC_DISP_PARAMS}:maximum_bitrate=${TARGET_BITRATE_KBIT}kbit"
	    fi
	fi
	typeset -i __SET_CRF_MIN
	typeset -i __SET_CRF_MAX
	typeset -i __CRF_MIN
	typeset -i __CRF_MAX
	typeset -i __CRF_LIMIT
	__IS_SET_CRF_MIN=0
	__IS_SET_CRF_MAX=0
	__CRF_MIN=-1
	if [ ${IS_CRF} -ne 0 ] ; then
	    __CRF_LIMIT=70
	else
	    __CRF_LIMIT=63
	fi
	__CRF_MAX=-1
	
	typeset -i __QP_INT
	__QP_INT=`calc -d "int( ${SVTAV1_QUANT_VALUE} )" | tr -d [:space:]`

	if [ ${SVTAV1_VIDEO_MINQ} -ge 0 ] ; then
	    __CRF_MIN=${SVTAV1_VIDEO_MINQ}
	elif [ "__n__${VIDEO_MINQ}" != "__n__" ] ; then
	    __CRF_MIN=`calc -d "int( ${VIDEO_MINQ} * 0.90 )" | tr -d [:space:]`
	    if [ ${__CRF_MIN} -ge ${__QP_INT} ] ; then
		__CRF_MIN=`calc -d ${__QP_INT} - 2 | tr -d [:space:]`
	    fi
	fi
	if [ ${SVTAV1_VIDEO_MAXQ} -ge 0 ] ; then
	    __CRF_MAX=${SVTAV1_VIDEO_MAXQ}
	elif [ "__n__${VIDEO_MAXQ}" != "__n__" ] ; then
	    __CRF_MAX=`calc -d "int( ${VIDEO_MAXQ} * 1.2 + 1.5 )" | tr -d [:space:]`
	    if [ ${__CRF_MAX} -le ${__QP_INT} ] ; then
		__CRF_MAX=`calc -d ${__QP_INT} + 4 | tr -d [:space:]`
	    fi
	fi
	if [ ${__CRF_MIN} -ge 0 ] ; then
	    __IS_SET_CRF_MIN=1
	fi
	if [ ${__CRF_MAX} -ge 0 ] ; then
	    __IS_SET_CRF_MAX=1
	fi
	if [ ${__IS_SET_CRF_MAX} -ne 0 ] ; then
	    if [ ${__IS_SET_CRF_MIN} -ne 0 ] ; then
		if [ ${__CRF_MIN} -gt ${__CRF_MAX} ] ; then
		    # SWAP VALUE
		    typeset -i __TMP_I
		    __TMP_I=${__CRF_MIN}
		    __CRF_MIN=${__CRF_MAX}
		    __CRF_MAX=${__TMP_I}
		    #__CRF_MIN=`calc -d "${__CRF_MAX} - 1" | tr -d [:space:]`
		fi
		if [ ${__CRF_MIN} -lt 0 ] ; then
		    __CRF_MIN=0
		fi
	    fi
	fi
	if [ ${__CRF_MIN} -gt ${__CRF_LIMIT} ] ; then
	    __CRF_MIN=${__CRF_LIMIT}
	fi
	if [ ${__CRF_MAX} -gt ${__CRF_LIMIT} ] ; then
	    __CRF_MAX=${__CRF_LIMIT}
	fi
	if [ ${__IS_SET_CRF_MIN} -ne 0 ] ; then
	    __APPEND_ARGS_POST+=(-qmin)
	    __APPEND_ARGS_POST+=(${__CRF_MIN})
	    __VCODEC_DISP_PARAMS="${__VCODEC_DISP_PARAMS}:qmin=${__CRF_MIN}"
	fi

	if [ ${__IS_SET_CRF_MAX} -ne 0 ] ; then
	    __APPEND_ARGS_POST+=(-qmax)
	    __APPEND_ARGS_POST+=("${__CRF_MAX}")
	    __VCODEC_DISP_PARAMS="${__VCODEC_DISP_PARAMS}:qmax=${__CRF_MAX}"
	fi
	typeset -i PARALLEL_LEVEL
	if [ ${FRAME_THREADS} -le 0 ] ; then
	    PARALLEL_LEVEL=0
	else
	    PARALLEL_LEVEL=${FRAME_THREADS}
	    if [ ${PARALLEL_LEVEL} -gt 6 ]; then
		PARALLEL_LEVEL=6
	    fi
	fi
	__VCODEC_PARAMS="${__VCODEC_PARAMS}:lp=${PARALLEL_LEVEL}:enable-overlays=1"

	typeset -i __GRAIN_VALUE
	__GRAIN_VALUE=0
	_T_TUNE_VALUE="`echo ${SVTAV1_TUNE} | tr '[:lower:]' '[:upper:]'`" 
	case "${_T_TUNE_VALUE}" in
	    "GRAIN" )
		__GRAIN_VALUE=15
		__VCODEC_PARAMS="${__VCODEC_PARAMS}:tune=0:rc=${SVTAV1_RC_MODE}:scm=0:scd=0"
		;;
	    "ANIMATION" | "ANIME" )
		__VCODEC_PARAMS="${__VCODEC_PARAMS}:tune=2:scd=1:scm=3"
		;;
	    "ANIMATION_GRAIN" | "ANIME_GRAIN" )
		__GRAIN_VALUE=15
		__VCODEC_PARAMS="${__VCODEC_PARAMS}:tune=2:scd=1:scm=3"
		;;
	    "NOGRAIN" | "NO_GRAIN" )
		__VCODEC_PARAMS="${__VCODEC_PARAMS}:tune=0:rc=${SVTAV1_RC_MODE}:scd=1:scm=2"
		;;
	    "NOGRAIN-MS-SSIM" | "NO_GRAIN_MS_SSIM" )
		__VCODEC_PARAMS="${__VCODEC_PARAMS}:tune=4:rc=${SVTAV1_RC_MODE}:scd=1:scm=2"
		;;
	    "MIDGRAIN" | "MID_GRAIN" )
		__GRAIN_VALUE=6
		__VCODEC_PARAMS="${__VCODEC_PARAMS}:tune=0:rc=${SVTAV1_RC_MODE}:scd=1:scm=2"
		;;
	    * )
		__VCODEC_PARAMS="${__VCODEC_PARAMS}:tune=0:rc=${SVTAV1_RC_MODE}:scd=1:scm=0"
		;;
	esac
	__VCODEC_PARAMS="${__VCODEC_PARAMS}:film-grain=${__GRAIN_VALUE}"
	if [ ${SVTAV1_DETAIL_BOOST} -ne 0 ] ; then
		__VCODEC_PARAMS="${__VCODEC_PARAMS}:enable-variance-boost=1"
	fi
	if [ ${SVTAV1_DISABLE_TEMPORAL_FILTERING} -ne 0 ] ; then
	    __VCODEC_PARAMS="${__VCODEC_PARAMS}:enable-tf=0:enable-tf-kf=0"
	elif [ ${SVTAV1_TEMPORAL_FILTERING_STRENGTH} -ge 0 ] ; then
	    __VCODEC_PARAMS="${__VCODEC_PARAMS}:tf-strength=${SVTAV1_TEMPORAL_FILTERING_STRENGTH}"
	fi
	if [ ${SVTAV1_SHARPNESS} -ge -7 ] ; then
	    if [ ${SVTAV1_SHARPNESS} -le 7 ] ; then
	         __VCODEC_PARAMS="${__VCODEC_PARAMS}:sharpness=${SVTAV1_SHARPNESS}"
	    fi
	fi
	if [ "__n__${SVTAV1_AQ_STRENGTH}" != "__n__" ] ; then
	    __VCODEC_PARAMS="${__VCODEC_PARAMS}:ac-bias=${SVTAV1_AQ_STRENGTH}"
	fi
	if [ ${SVTAV1_ENABLE_QM} -ne 0 ] ; then
	    __VCODEC_PARAMS="${__VCODEC_PARAMS}:enable-qm=1"
	    if [ ${SVTAV1_QM_MIN} -ge 0 ] ; then
	        if [ ${SVTAV1_QM_MIN} -le 15 ] ; then
		    __VCODEC_PARAMS="${__VCODEC_PARAMS}:qm-min=${SVTAV1_QM_MIN}"
		fi
	    fi
	    if [ ${SVTAV1_QM_MAX} -ge 0 ] ; then
	        if [ ${SVTAV1_QM_MAX} -le 15 ] ; then
	            if [ ${SVTAV1_QM_MAX} -ge ${SVTAV1_QM_MIN} ] ; then
		        __VCODEC_PARAMS="${__VCODEC_PARAMS}:qm-max=${SVTAV1_QM_MAX}"
		    fi
		fi
	    fi
	fi
	if [ "__n__${_T_TUNE_VALUE}" != "__n__" ] ; then
	    __VCODEC_DISP_PARAMS="${__VCODEC_DISP_PARAMS}:tune_type=${_T_TUNE_VALUE}"
	fi    
	__VCODEC_DISP_PARAMS="${__VCODEC_DISP_PARAMS}:preset=${_N_PRESET_VALUE}(${SVTAV1_PRESET})"
	ARG_METADATA+=(-metadata:s:v:0)
	ARG_METADATA+=(real_encoder=libsvtav1)

	if [ "__xx__" != "__xx__${VIDEO_FILTERCHAIN_HWACCEL}" ] ; then
	    ARG_METADATA+=(-metadata:s:v:0)
	    ARG_METADATA+=(filterchains="${VIDEO_FILTERCHAIN_HWACCEL}")
	fi
	if [ "__xx__" != "__xx__${__VCODEC_PARAMS}" ] ; then
	    ARG_METADATA+=(-metadata:s:V:0)
	    ARG_METADATA+=(vcodec_params="${__VCODEC_PARAMS}")
	fi
	if [ "__xx__" != "__xx__${__VCODEC_DISP_PARAMS}" ] ; then
	    ARG_METADATA+=(-metadata:s:V:0)
	    ARG_METADATA+=(vcodec_params_any="${__VCODEC_DISP_PARAMS}")
	fi
	logging "${_AUDIO_ARGS[@]} ${ARG_METADATA[@]} -metadata:g decoder_opts=”`cat $TEMPDIR/general_decoder_opts.txt`” -metadata:s:v v_encoder_options=”`cat $TEMPDIR/v_encoder_options.txt`”"
	#echo \
	$EXECUTE_PREFIX_COMMANDS \
	    ${FFMPEG_CMD} -loglevel info ${ARG_DECODE_GENERAL_FLAGS[@]} \
	               $DECODE_APPEND \
		       ${ARG_DECODE_GENERAL_SKIP_FLAGS[@]} \
		       -i "$DIRNAME2/$SRC2" \
		       ${ARG_ENCODE_GENERAL_FLAGS[@]} \
		       ${ARG_ENCODE_STREAMS[@]} \
		       ${FRAMERATE} -aspect ${VIDEO_ASPECT} \
		       -vf ${VIDEO_FILTERCHAIN_HWACCEL} \
		       -c:v libsvtav1 \
		       -c:a aac \
		       -filter_complex_threads ${FILTER_COMPLEX_THREADS} -filter_threads ${FILTER_THREADS} \
		       ${SVTAV1_HEAD_VALUES[@]} \
		       ${__APPEND_ARGS_PRE[@]} \
		       -svtav1-params "${__VCODEC_PARAMS}" \
		       ${__APPEND_ARGS_POST[@]} \
		       -threads ${ENCTHREADS} \
		       ${_AUDIO_ARGS[@]} \
		       "${ARG_METADATA[@]}" \
		       -metadata:g decoder_opts="`cat $TEMPDIR/general_decoder_opts.txt`" \
		       -metadata:s:v v_encoder_options="`cat $TEMPDIR/v_encoder_options.txt`" \
		       -metadata:g enc_start="${__ENCODE_START_DATE}" \
		       -y $TEMPDIR/v1tmp.mkv
	#exit -1
    elif [ ${USE_X265} -ne 0 ]; then
    
	if [ ${IS_CRF} -ne 0 ] ; then
	   __QUANT_TYPE="crf"
	else
	   __QUANT_TYPE="qp"
	fi
	X265_THREAD_PARAMS="frame-threads=${FRAME_THREADS}:pools=${POOLTHREADS}"
	#X265_THREAD_PARAMS="${X265_THREAD_PARAMS}:pme=true:pmode=true"
	
	X265_AQ_PARAMS="hevc-aq=true:aq-mode=${X265_AQ_MODE}"
	X265_AQ_PARAMS="${X265_AQ_PARAMS}:aq-strength=${X265_AQ_STRENGTH}"
	X265_AQ_PARAMS="${X265_AQ_PARAMS}:qp-adaptation-range=${X265_QP_ADAPTATION_RANGE}"
	#X265_AQ_PARAMS="${X265_AQ_PARAMS}:aq-motion=true"
	
	if test "__n__${X265_PARAMS}" != "__n__"; then
		X265_PARAMS="${X265_PARAMS}:"
	fi
	if test "__n__${X265_AQ_PARAMS}" != "__n__"; then
		X265_PARAMS="${X265_PARAMS}${X265_AQ_PARAMS}"
	fi
		
	if test "__n__${X265_PARAMS}" != "__n__"; then
		X265_PARAMS="${X265_PARAMS}:${X265_THREAD_PARAMS}"
	else
		X265_PARAMS="${X265_THREAD_PARAMS}"
	fi 
	if test ${USE_HDR} -ne 0 ; then
	    case "${X265_PROFILE}" in
	        "main10" )
		if test "__n__${X265_PARAMS}" != "__n__"; then
			X265_PARAMS="${X265_PARAMS}:hdr10=true:hdr10-opt=true"
		else
			X265_PARAMS="hdr10=true:hdr10-opt=true"
		fi
		;;
		* )
		;;
	   esac
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

	ARG_METADATA+=(-metadata:s:v:0)
	ARG_METADATA+=(real_encoder=libx265)

	DISPLAY_ENCODER_PARAMS="${DISPLAY_ENCODER_PARAMS}:profile=${X265_PROFILE}"
	DISPLAY_ENCODER_PARAMS="${DISPLAY_ENCODER_PARAMS}:preset=${X265_PRESET}"
	DISPLAY_ENCODER_PARAMS="${DISPLAY_ENCODER_PARAMS}:${__QUANT_TYPE}=${VIDEO_QUANT}"
	DISPLAY_ENCODER_PARAMS="${DISPLAY_ENCODER_PARAMS}:${X265_PARAMS}"
	
	ARG_METADATA+=(-metadata:s:v:0)
	ARG_METADATA+=(encode_threads="${DISPLAY_SINK_PARAM}")
	
	ARG_METADATA+=(-metadata:s:v:0)
	ARG_METADATA+=(encode_params="${DISPLAY_ENCODER_PARAMS}")

	ARG_METADATA+=(-metadata:s:v:0)
	ARG_METADATA+=(filterchains="${DISPLAY_FILTERCHAIN}")
#		      -af aresample=async=1 \
#		      -af aresample=async=1:first_pts=0 \

	logging "${_AUDIO_ARGS[@]} ${ARG_METADATA[@]} -metadata:g decoder_opts=”`cat $TEMPDIR/general_decoder_opts.txt`” -metadata:s:v v_encoder_options=”`cat $TEMPDIR/v_encoder_options.txt`”"
	$EXECUTE_PREFIX_COMMANDS \
	    ${FFMPEG_CMD} -loglevel info ${ARG_DECODE_GENERAL_FLAGS[@]} \
	               $DECODE_APPEND \
		       ${ARG_DECODE_GENERAL_SKIP_FLAGS[@]} \
		       -i "$DIRNAME2/$SRC2" \
		       ${ARG_ENCODE_GENERAL_FLAGS[@]} \
		       ${ARG_ENCODE_STREAMS[@]} \
		       ${FRAMERATE} -aspect ${VIDEO_ASPECT} \
		       -vf ${VIDEO_FILTERCHAIN_HWACCEL} \
		       -c:v libx265 \
		       -c:a aac \
		       -filter_complex_threads ${FILTER_COMPLEX_THREADS} -filter_threads ${FILTER_THREADS} \
		      ${FFMPEG_X265_HEAD[@]} \
		      ${FFMPEG_X265_FRAMES1} \
		      ${FFMPEG_X265_AQ} \
		      ${FFMPEG_X265_PARAMS} \
		      -threads ${ENCTHREADS} \
		      ${_AUDIO_ARGS[@]} \
		      "${ARG_METADATA[@]}" \
		      -metadata:g decoder_opts="`cat $TEMPDIR/general_decoder_opts.txt`" \
		      -metadata:s:v v_encoder_options="`cat $TEMPDIR/v_encoder_options.txt`" \
		      -metadata:g enc_start="${__ENCODE_START_DATE}" \
		      -y $TEMPDIR/v1tmp.mkv
	
    else
	
	ARG_METADATA+=(-metadata:s:v:0)
	ARG_METADATA+=(real_encoder=libx264)
	ARG_METADATA+=(-metadata:s:v:0)
	ARG_METADATA+=(encode_threads="${DISPLAY_SINK_PARAM}")
	ARG_METADATA+=(-metadata:s:v:0)
	ARG_METADATA+=(encode_params="profile=${X264_PROFILE}:${FFMPEG_X264_PARAM}")

	ARG_METADATA+=(-metadata:s:v:0)
	ARG_METADATA+=(filterchains="${DISPLAY_FILTERCHAIN}")
	
	logging "${_AUDIO_ARGS[@]} ${ARG_METADATA[@]} -metadata:g decoder_opts=”`cat $TEMPDIR/general_decoder_opts.txt`” -metadata:s:v v_encoder_options=”`cat $TEMPDIR/v_encoder_options.txt`”"
	$EXECUTE_PREFIX_COMMANDS  \
	    ${FFMPEG_CMD} -loglevel info ${ARG_DECODE_GENERAL_FLAGS[@]} \
	          $DECODE_APPEND \
		  ${ARG_DECODE_GENERAL_SKIP_FLAGS[@]} \
		  -i "$DIRNAME2/$SRC2" \
		  ${ARG_ENCODE_GENERAL_FLAGS[@]} \
	          ${ARG_ENCODE_STREAMS[@]} \
	          ${FRAMERATE} -aspect ${VIDEO_ASPECT} \
		  -vf ${VIDEO_FILTERCHAIN_HWACCEL} \
		  -c:v libx264 \
		  -filter_complex_threads ${FILTER_COMPLEX_THREADS} -filter_threads ${FILTER_THREADS} \
		  ${FFMPEG_X264_HEAD[@]} \
		  ${FFMPEG_X264_FRAMES1} \
		  ${FFMPEG_X264_AQ[@]} \
		  -x264-params ${FFMPEG_X264_PARAM} \
		  -threads ${ENCTHREADS} \
		  ${_AUDIO_ARGS[@]} \
		  "${ARG_METADATA[@]}" \
		  -metadata:g decoder_opts="`cat $TEMPDIR/general_decoder_opts.txt`" \
		  -metadata:s:v v_encoder_options="`cat $TEMPDIR/v_encoder_options.txt`" \
      		  -metadata:g enc_start="${__ENCODE_START_DATE}" \
		  -y $TEMPDIR/v1tmp.mkv 
	fi
    
    #    -filter_complex_threads 4 -filter_threads 4 \
elif    test $HWENC -ne 0; then
	DISPLAY_FILTERCHAIN="filter_complex:${DISPLAY_FILTERCHAIN}"
	
    
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
	DISPLAY_ENCODER_PARAMS="profile=${X265_PROFILE}:${DISPLAY_HWENC_PARAM}"


	ARG_METADATA+=(-metadata:s:v:0)
	ARG_METADATA+=(real_encoder=h264_vaapi)
	ARG_METADATA+=(-metadata:s:v:0)
	ARG_METADATA+=(encode_params="${DISPLAY_ENCODER_PARAMS}")
	ARG_METADATA+=(-metadata:s:v:0)
	ARG_METADATA+=(encode_threads="${DISPLAY_SINK_PARAM}")
	ARG_METADATA+=(-metadata:s:v:0)
	ARG_METADATA+=(filterchains="${DISPLAY_FILTERCHAIN}")
	
	logging "${_AUDIO_ARGS[@]} ${ARG_METADATA[@]} -metadata:g decoder_opts=”`cat $TEMPDIR/general_decoder_opts.txt`” -metadata:s:v v_encoder_options=”`cat $TEMPDIR/v_encoder_options.txt`”"
	$EXECUTE_PREFIX_COMMANDS \
	    ${FFMPEG_CMD} ${ARG_DECODE_GENERAL_FLAGS[@]} \
	              $DECODE_APPEND \
		       ${ARG_DECODE_GENERAL_SKIP_FLAGS[@]} \
		      -i "$DIRNAME2/$SRC2" \
		      ${ARG_ENCODE_GENERAL_FLAGS[@]} \
		       ${ARG_ENCODE_STREAMS[@]} \
		       ${FRAMERATE} \
		       -filter_complex ${VIDEO_FILTERCHAIN_HWACCEL} \
		       -c:v h264_vaapi \
		       -filter_threads ${FILTER_THREADS} \
		       -filter_complex_threads ${FILTER_COMPLEX_THREADS} \
		       $HWENC_PARAM \
		       -aspect ${VIDEO_ASPECT} \
		       -threads:0 8 \
		       -threads:1 8 \
		       ${FRAMERATE} \
		       ${_AUDIO_ARGS[@]} \
		       "${ARG_METADATA[@]}" \
		       -metadata:g decoder_opts="`cat $TEMPDIR/general_decoder_opts.txt`" \
		       -metadata:s:v v_encoder_options="`cat $TEMPDIR/v_encoder_options.txt`" \
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
	DISPLAY_SINK_PARAM="${DISPLAY_SINK_PARAM}:threads(0)=4:threads(1)=4"
	
	ARG_METADATA+=(-metadata:s:v:0)
	ARG_METADATA+=(real_encoder=hevc_vaapi)
	ARG_METADATA+=(-metadata:s:v:0)
	ARG_METADATA+=(encode_params="profile=${X265_PROFILE}:${DISPLAY_HWENC_PARAM}")
	ARG_METADATA+=(-metadata:s:v:0)
	ARG_METADATA+=(encode_threads="${DISPLAY_SINK_PARAM}")
	ARG_METADATA+=(-metadata:s:v:0)
	ARG_METADATA+=(filterchains="${DISPLAY_FILTERCHAIN}")
	

	logging "${_AUDIO_ARGS[@]} ${ARG_METADATA[@]} -metadata:g decoder_opts=”`cat $TEMPDIR/general_decoder_opts.txt`” -metadata:s:v v_encoder_options=”`cat $TEMPDIR/v_encoder_options.txt`”"
	$EXECUTE_PREFIX_COMMANDS \
	    ${FFMPEG_CMD}  ${ARG_DECODE_GENERAL_FLAGS[@]} \
	               $DECODE_APPEND \
		       ${ARG_DECODE_GENERAL_SKIP_FLAGS[@]} \
		       -i "$DIRNAME2/$SRC2" \
		       ${ARG_ENCODE_GENERAL_FLAGS[@]} \
  		       ${ARG_ENCODE_STREAMS[@]} \
	               -profile:v ${X265_PROFILE} \
		       -aud 1 -level 51 \
		       ${FRAMERATE} \
		       -filter_complex $VIDEO_FILTERCHAIN_HWACCEL \
		       -c:v hevc_vaapi \
		       -filter_threads ${FILTER_THREADS} \
		       -filter_complex_threads ${FILTER_COMPLEX_THREADS} \
		       $HWENC_PARAM \
		       -aspect ${VIDEO_ASPECT} \
		       -threads:0 4 \
		       -threads:1 4 \
		       ${FRAMERATE} \
		       ${_AUDIO_ARGS[@]} \
		       "${ARG_METADATA[@]}" \
		       -metadata:g decoder_opts="`cat $TEMPDIR/general_decoder_opts.txt`" \
		       -metadata:s:v v_encoder_options="`cat $TEMPDIR/v_encoder_options.txt`" \
		      -metadata:g enc_start="${__ENCODE_START_DATE}" \
		       -y $TEMPDIR/v1tmp.mkv 

	
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
    if test $IGNORE_DECODE_ERRORS -ne 0; then
        logging "WARNING: ERROR on encoding, but try to make encoding; ERROR = ${ERRFLAGS}"
    else
        cd ../..
        rm -rf $TEMPDIR
        logging "ERROR ${ERRFLAGS}"
        exit 2
    fi
fi

if test -s "$TEMPDIR/${__SUB_FILE_NAME}" ; then
    ARG_MUX_SUB_STREAM+=(-map:s)
    ARG_MUX_SUB_STREAM+=(1:0)
    
    ARG_MUX_SUB_TXT2+=(-c:s)
    ARG_MUX_SUB_TXT2+=(copy)
    ARG_MUX_SUB_TXT2+=(-metadata:s:s:0)
    ARG_MUX_SUB_TXT2+=(language=jpn)
    
    #ARG_SUBTXT2=""
    echo "${__TMPS_DECODER_SUB}" > $TEMPDIR/decoder_sub_str.txt
    #if [ "___xxx___${__TMPS_DECODER_SUB}" != "___xxx___" ] ; then
    #    __TMPS_X=`echo ${__TMPS_DECODER_SUB} | sed -e s/[[:blank:]]/　/g`
    #    __TMPS_X=`echo ${__TMPS_X} | sed -e s/\;/；/g`
    #    ARG_SUBTXT2="${ARG_SUBTXT2} -metadata:s:s:0 decoder_options_for_subscripts=${__TMPS_X}" 
    #	#ARG_SUBTXT2="${ARG_SUBTXT2} -metadata:s:s:0 decoder_options_for_subscripts=\"${__TMPS_DECODER_SUB}\"" 
    #fi
    $EXECUTE_PREFIX_COMMANDS \
    ${FFMPEG_CMD} -i $TEMPDIR/v1tmp.mkv \
                  ${ARG_ENCODE_SUB_DELAY_FLAGS[@]} \
		  ${ARG_ENCODE_SUB_CODEC_FLAGS[@]}  \
                  -i $TEMPDIR/${__SUB_FILE_NAME} \
		  ${ARG_ENCODE_STREAMS[@]} \
		  ${ARG_MUX_SUB_STREAM[@]} \
		  ${ARG_ENCODE_SUB_TXT2[@]} \
		  ${ARG_MUX_SUB_TXT2[@]} \
		  -metadata:s:s:0 decoder_options_for_subscripts="`cat $TEMPDIR/decoder_sub_str.txt`" \
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
  ${EXECUTE_PREFIX_COMMANDS} cp "$TEMPDIR/v2tmp.mkv" "$DIRNAME/$BASENAME"
else
  ${EXECUTE_PREFIX_COMMANDS} cp "$TEMPDIR/v2tmp.mkv" "$DIRNAME/$BASENAME"
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
