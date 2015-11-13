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
X264_ENCPRESET="--preset slower --8x8dct --partitions all"

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
USE_DATABASE=1
ENCMODE="DEFAULT"
NOENCODE=0

echo "$@" | logger -i -t "MYTHTV.TRANSCODE" 
# Parse ARGS
for x in "$@" ; do
    SS="$1"
    case "$1" in
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
    --threads )
    shift
    ENCTHREADS="$1"
    shift
    ;;
    --db | --use-db | --with-db )
    shift
    USE_DATABASE=1
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
    --live_low | --live-low)
    # for Live, middle quality.
    shift
    ENCMODE="LIVE_LOW"
    ;;
    --live_mid | --live-mid)
    # for Live, middle quality.
    shift
    ENCMODE="LIVE_MID"
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
    --norm | --no-remove | --no-remove-source | --NO-REMOVE-SOURCE )
    shift
    REMOVE_SOURCE=0
    ;;
    -h | --help )
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
    echo " -i | --src | --i Input-File (Full path)  : Set input file."
    echo " -o | --dst | --o Output-File (Full path) : Set output file. You must set to MP4 File."
    echo " -c | --chanid chanid                     : Set channel-id written in database."
    echo " -t | --starttime starttime               : Set start time written in database."
    echo " --cmcut : Perform CM CUT.(DANGER!) Seems to be imcomplete audio(s) at ISDB/Japan"
    echo " --no-cmcut : DO NOT Perform CM CUT.(Default)"
    echo " --db    : Use MythTV's database to manage trancoded video.(Default)"
    echo " --nodb  : Don't use MythTV's database and not manage trancoded video.(not default, useful for manual transcoding)"
    echo " --threads threads : Set threads for x264 video encoder. (Default = 4)"
    echo " --opencl    : Use OpenCL on video encoding."
    echo " --no-opencl : DO NOT Use OpenCL on video encoding.(Default)"
    echo " "
    echo " --anime          : Set encode parameters for Anime (standard)."
    echo " --anime_high     : Set encode parameters for Anime (high quality a little)."
    echo " --live1 | --live : Set encode parameters for Live movies (standard)."
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
    exit 1
    ;;
    esac
done
# don't change these
MYPID=$$

# a temporary working directory (must be writable by mythtv user)
TEMPDIR=`mktemp -d`

DIRNAME=`dirname "$DST"`
DIRNAME2=`dirname "$SRC"`

BASENAME=`echo "$DST" | awk -F/ '{print $NF}' | sed 's/!/！/g' | sed 's/ /_/g' | sed 's/://g' | sed 's/?//g' | sed s/"'"/’/g`
#BASENAME=`echo "$DST" | awk -F/ '{print $NF}' | sed 's/ /_/g' | sed 's/:/：/g' | sed 's/?/？/g' | sed s/"'"/"’"/g`
BASENAME2=`echo "$SRC" | awk -F/ '{print $NF}'`
printf "BASENAME=%s STARTTIME=%s" $BASENAME $I_STARTTIME | logger -i -t "MYTHTV.TRANSCODE" 

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
   "ANIME_HIGH" | "LIVE_HIGH" )
   AUDIOBITRATE=224
   AUDIOCUTOFF=22050
   ;;
esac

# convert audio track to aac
AUDIOTMP="$TEMPDIR/a1tmp.raw"
mkfifo $AUDIOTMP

ffmpeg -i "$DIRNAME2/$SRC2"  -acodec pcm_s16be -f s16be -ar 48000 -ac 2 -y $AUDIOTMP  >/dev/null &
DEC_AUDIO_PID=$!

faac -w -b $AUDIOBITRATE -c $AUDIOCUTOFF -P -R 48000 -C 2 $AUDIOTMP -o $TEMPDIR/a1.m4a >/dev/null &
ENC_AUDIO_PID=$!

# first video pass
VIDEOTMP="$TEMPDIR/v1tmp.y4m"
mkfifo $VIDEOTMP

# if set encode mode ($ENCMODE), override defaults.
VIDEO_FILTERCHAIN0="crop=out_w=1440:out_h=1080:y=1080:keep_aspect=1"
VIDEO_FILTERCHAINX="kerndeint,hqdn3d=luma_spatial=4.5:chroma_spatial=3.4:luma_tmp=4.4:chroma_tmp=4.0"

X264_FILTPARAM="--vf resize:width=1280,height=720,method=lanczos"
# Live video (low motion)

#Determine override presets when set to mode
x=$ENCMODE
case "$x" in
   "ANIME" )
   VIDEO_QUANT=21
   VIDEO_MINQ=14
   VIDEO_MAXQ=24
   VIDEO_AQSTRENGTH="0.75"
   VIDEO_QCOMP="0.88"
   VIDEO_FILTERCHAINX="yadif,hqdn3d=luma_spatial=2.7:chroma_spatial=2.2:luma_tmp=2.5:chroma_tmp=2.5"
   X264_FILTPARAM="--vf resize:width=1280,height=720,method=bicubic"
   ;;
   "ANIME_HIGH" )
   VIDEO_QUANT=21
   VIDEO_MINQ=14
   VIDEO_MAXQ=24
   VIDEO_AQSTRENGTH="0.88"
   VIDEO_QCOMP="0.92"
   VIDEO_FILTERCHAINX="yadif,hqdn3d=luma_spatial=2.5:chroma_spatial=2.2:luma_tmp=2.2:chroma_tmp=2.2"
   X264_FILTPARAM="--vf resize:width=1280,height=720,method=bicubic"
   ;;
   "LIVE1" )
   VIDEO_QUANT=22
   VIDEO_MINQ=14
   VIDEO_MAXQ=32
   VIDEO_AQSTRENGTH="1.1"
   VIDEO_QCOMP="0.67"
   VIDEO_FILTERCHAINX="yadif,hqdn3d=luma_spatial=4.2:chroma_spatial=3.2:luma_tmp=3.8:chroma_tmp=3.8"
   ;;
   "LIVE_HIGH" )
   VIDEO_QUANT=22
   VIDEO_MINQ=14
   VIDEO_MAXQ=28
   VIDEO_AQSTRENGTH="1.1"
   VIDEO_QCOMP="0.75"
   VIDEO_FILTERCHAINX="yadif,hqdn3d=luma_spatial=4.2:chroma_spatial=3.2:luma_tmp=3.8:chroma_tmp=3.8"
   ;;
   "LIVE_MID" )
   VIDEO_QUANT=23
   VIDEO_MINQ=15
   VIDEO_MAXQ=35
   VIDEO_AQSTRENGTH="1.3"
   VIDEO_QCOMP="0.55"
   VIDEO_FILTERCHAINX="yadif,hqdn3d=luma_spatial=4.7:chroma_spatial=3.5:luma_tmp=4.2:chroma_tmp=4.2"
   ;;
   "LIVE_LOW" )
   VIDEO_QUANT=25
   VIDEO_MINQ=14
   VIDEO_MAXQ=40
   VIDEO_AQSTRENGTH="1.5"
   VIDEO_QCOMP="0.50"
   VIDEO_FILTERCHAINX="yadif,hqdn3d=luma_spatial=5.0:chroma_spatial=3.9:luma_tmp=4.7:chroma_tmp=4.7"
   ;;
esac

X264_PRESETS="--profile high --keyint 300 --min-keyint 24 --scenecut 30"
X264_QUANT="-q $VIDEO_QUANT"
X264_AQPARAM="--aq-mode 3 --qpmin $VIDEO_MINQ --qpmax $VIDEO_MAXQ --qpstep 8 --aq-strength $VIDEO_AQSTRENGTH --qcomp $VIDEO_QCOMP"

# Modify encoding parameter(s) on ANIME/ANIME_HIGH
X264_DIRECT="--direct auto "
X264_BFRAMES="--bframes 5 --b-bias -2 --b-adapt 2"
x=$ENCMODE
case "$x" in
   ANIME )
     X264_DIRECT="--direct temporal"
     X264_BFRAMES="--bframes 4 --b-bias -2 --b-adapt 2"
     X264_PRESETS="--profile high --keyint 300 --min-keyint 24 --scenecut 30"
   ;;
   ANIME_HIGH )
     X264_DIRECT="--direct temporal"
     X264_BFRAMES="--bframes 3 --b-bias -2 --b-adapt 2"
     X264_PRESETS="--profile high --keyint 300 --min-keyint 24 --scenecut 26"
   ;;
   LIVE_HIGH )
     X264_DIRECT="--direct temporal"
     X264_BFRAMES="--bframes 4 --b-bias -2 --b-adapt 2"
     X264_PRESETS="--profile high --keyint 300 --min-keyint 24 --scenecut 32"
   ;;
   LIVE1 )
     X264_DIRECT="--direct temporal"
     X264_BFRAMES="--bframes 5 --b-bias -2 --b-adapt 2"
   ;;
   LIVE_MID )
     X264_DIRECT="--direct temporal"
     X264_BFRAMES="--bframes 6 --b-bias -2 --b-adapt 2"
     X264_PRESETS="--profile high --keyint 300 --min-keyint 24 --scenecut 37"
     X264_ENCPRESET="--preset slow ---subme 8 -8x8dct --partitions p8x8,b8x8,i8x8"
   ;;
   LIVE_LOW )
     X264_DIRECT="--direct auto"
     X264_BFRAMES="--bframes 6 --b-bias -2 --b-adapt 2"
     X264_PRESETS="--profile high --keyint 300 --min-keyint 24 --scenecut 43"
     X264_ENCPRESET="--preset medium --8x8dct --partitions p8x8,b8x8,i8x8"
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

x264 --sar 4:3 $X264_QUANT  $X264_PRESETS $X264_ENCPRESET $X264_FASTENC \
    $X264_AQPARAM $X264_ENCPARAM $X264_DIRECT $X264_BFRAMES $X264_FILTPARAM \
   --threads $ENCTHREADS $USECL -o $TEMPDIR/v1tmp.mp4 $VIDEOTMP  &
ENC_VIDEO_PID=$!


VIDEO_FILTERCHAIN="$VIDEO_FILTERCHAIN0","$VIDEO_FILTERCHAINX"
echo "Filter chain = $VIDEO_FILTERCHAIN" 
ffmpeg -i "$DIRNAME2/$SRC2" -r 30000/1001 -aspect 16:9 -acodec null -vcodec rawvideo -f yuv4mpegpipe -vf $VIDEO_FILTERCHAIN -y $VIDEOTMP &
DEC_VIDEO_PID=$!

wait $DEC_AUDIO_PID
RESULT_DEC_AUDIO=$?

wait $ENC_AUDIO_PID
RESULT_ENC_AUDIO=$?

wait $DEC_VIDEO_PID
RESULT_DEC_VIDEO=$?

wait $ENC_VIDEO_PID
RESULT_ENC_VIDEO=$?

# Demux files to one video
ERRFLAGS=0
if test $RESULT_DEC_AUDIO -ne 0 ; then
  echo "Error: Error on decoding AUDIO."
  ERRFLAGS=1
fi
if test $RESULT_ENC_AUDIO -ne 0 ; then
  echo "Error: Error on encoding AUDIO."
  ERRFLAGS=1
fi
if test $RESULT_DEC_VIDEO -ne 0 ; then
  echo "Error: Error on decoding AUDIO."
  ERRFLAGS=1
fi
if test $RESULT_ENC_VIDEO -ne 0 ; then
  echo "Error: Error on encoding AUDIO."
  ERRFLAGS=1
fi
if test $ERRFLAGS -ne 0; then
  cd ../..
  rm -rf $TEMPDIR
  exit 2
fi


MP4Box -add $TEMPDIR/v1tmp.mp4 -add $TEMPDIR/a1.m4a -new "$DIRNAME/$BASENAME"
RESULT_DEMUX=$?
#/if test $RESULT_DEMUX -ne 0; then
#  echo "Errror on DEMUXing."
#  cd ../..
#  rm -rf $TEMPDIR
#  exit 3
#fi
fi


# update the database to point to the transcoded file and delete the original recorded show.
NEWFILESIZE=`du -b "$DIRNAME/$BASENAME" | cut -f1`
if test $NEWFILESIZE -le 0 ; then
  echo "Unknown Error"
  exit 4
fi

if test $USE_DATABASE -ne 0 ; then
  echo "UPDATE recorded SET basename='$BASENAME',filesize='$NEWFILESIZE',transcoded='1' WHERE chanid='$I_CHANID' AND starttime='$I_STARTTIME';" > update-database_$MYPID.sql
  cat update-database_$MYPID.sql | logger -i -t "MYTHTV.TRANSCODE" 
  mysql -v -v -v --user=$DATABASEUSER --password=$DATABASEPASSWORD mythconverg < update-database_$MYPID.sql | logger -i -t "MYTHTV.TRANSCODE" 
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
exit 0
