#!/bin/sh

# MythTV multi-pass auto-transcode to H.264, remove commercials, delete original recording, and
# make database entry point to transcoded file. 
# This is a Bourne shell script optimized for Hauppauge PVR-150 captures.
#
# Written by Defcronyke Webmaster, copyright 2012.
# Version 0.8

# Arguments
# $1 must be the directory/file to be transcoded.
# $2 must be the output directory / file name. The directory must be writeable by the mythtv user
# $3 must be chanid
# $4 must be starttime
# the full userjob command in mythtv-setup should look like this: /path/to/this-script/mythtv-transcode-h264.sh "%DIR%/%FILE%" "%DIR%/%TITLE% - %PROGSTART%.mkv" "%CHANID%" "%STARTTIME%"


# MySQL database login information (for mythconverg database)
DATABASEUSER="mythtv"
DATABASEPASSWORD="yourpasswordhere"


# MythTV Install Prefix (make sure this matches with the directory where MythTV is installed)
INSTALLPREFIX="/usr/bin"

# Number of threads to use (default uses all threads)
USEOPENCL=0
AUDIOBITRATE=192
AUDIOCUTOFF=20000
ENCTHREADS=4

if [ -e ~/.mythtv-transcode-x264 ]; then
   . ~/.mythtv-transcode-x264
fi



# don't change these
MYPID=$$

# a temporary working directory (must be writable by mythtv user)
TEMPDIR=`mktemp -d`

AUDIOTMP="audiotmp.raw"
VIDEOOTMP="videotmp.y4m"

AUDIOFILE="audio.aac"
VIDEOTMPFILE="video.264"
DIRNAME=`dirname "$2"`



BASENAME=`echo "$2" | awk -F/ '{print $NF}' | sed 's/ /_/g' | sed 's/://g' | sed 's/?//g' | sed s/"'"/""/g`
BASENAME2=`echo "$1" | awk -F/ '{print $NF}'`



# play nice with other processes
renice 19 $MYPID
ionice -c 3 -p $MYPID

# make working dir, go inside
mkdir $TEMPDIR/mythtmp-$MYPID
cd $TEMPDIR/mythtmp-$MYPID

# remove commercials
#$INSTALLPREFIX/mythcommflag -c "$3" -s "$4" --gencutlist
#$INSTALLPREFIX/mythtranscode --chanid "$3" --starttime "$4" --mpeg2 --honorcutlist
#echo "UPDATE recorded SET basename='$BASENAME2.tmp' WHERE chanid='$3' AND starttime='$4';" > update-database_$MYPID.sql
#mysql --user=$DATABASEUSER --password=$DATABASEPASSWORD mythconverg < update-database_$MYPID.sql

# fix seeking and bookmarking by removing stale db info
echo "DELETE FROM recordedseek WHERE chanid='$3' AND starttime='$4';" > update-database_$MYPID.sql
mysql --user=$DATABASEUSER --password=$DATABASEPASSWORD mythconverg < update-database_$MYPID.sql
echo "DELETE FROM recordedmarkup WHERE chanid='$3' AND starttime='$4';" > update-database_$MYPID.sql
mysql --user=$DATABASEUSER --password=$DATABASEPASSWORD mythconverg < update-database_$MYPID.sql


SRC="$1"

# convert audio track to aac
AUDIOTMP="$TEMPDIR/a1tmp.raw"
mkfifo $AUDIOTMP
ffmpeg -i $SRC  -acodec pcm_s16be -f s16be -ar 48000 -ac 2 -y $AUDIOTMP  >/dev/null &
DEC_AUDIO_PID=$!
faac -w -b $AUDIOBITRATE -c $AUDIOCUTOFF -P -R 48000 -C 2 $AUDIOTMP -o $TEMPDIR/a1.m4a >/dev/null &
ENC_AUDIO_PID=$!

#mplayer -ao pcm:file=$AUDIOTMP/fifo -vo null -vc dummy -benchmark "$1.tmp" >/dev/null 2>&1

# first video pass
VIDEOTMP="$TEMPDIR/v1tmp.y4m"
mkfifo $VIDEOTMP

X264_ENCPARAM="--profile high422 --preset slower --aq-mode 2 --8x8dct --qpmin 14 --qpmax 33 --aq-strength 1.1 --qcomp 0.55 --vf resize:width=1280,height=720,method=lanczos"
x264 --sar 4:3 --opencl $X264_ENCPARAM --threads $ENCTHREADS -o $TEMPDIR/v1tmp.mp4 $VIDEOTMP  &
ENC_VIDEO_PID=$!


# Live video (low motion)
VIDEO_FILTERCHAIN1="crop=out_w=1440:out_h=1080:y=1080:keep_aspect=1,yadif,hqdn3d=luma_spatial=4.5:chroma_spatial=3.4:luma_tmp=4.4:chroma_tmp=4.4"
#ANIME
VIDEO_FILTERCHAIN2="crop=out_w=1440:out_h=1080:y=1080:keep_aspect=1,yadif,hqdn3d=luma_spatial=2.7:chroma_spatial=2.2:luma_tmp=2.5:chroma_tmp=2.5"

VIDEO_FILTERCHAIN="$VIDEO_FILTERCHAIN1"

ffmpeg -i $SRC -r 30000/1001 -aspect 16:9 -acodec null -vcodec rawvideo -f yuv4mpegpipe -vf $VIDEO_FILTERCHAIN -y $VIDEOTMP &
DEC_VIDEO_PID=$!


wait $DEC_AUDIO_PID $ENC_AUDIO_PID $DEC_VIDEO_PID $DEC_AUDIO_PID


# Demux files to one video
MP4Box -add $TEMPDIR/v1tmp.mp4 -add $TEMPDIR/a1.m4a -new "$DIRNAME/$BASENAME"


# update the database to point to the transcoded file and delete the original recorded show.
NEWFILESIZE=`du -b "$DIRNAME/$BASENAME" | cut -f1`
#echo "UPDATE recorded SET basename='$BASENAME',filesize='$NEWFILESIZE',transcoded='1' WHERE chanid='$3' AND starttime='$4';" > update-database_$MYPID.sql
#mysql --user=$DATABASEUSER --password=$DATABASEPASSWORD mythconverg < update-database_$MYPID.sql
#rm $1
#rm $1.-1.160x120.png
#rm $1.-1.100x75.png
#rm $1.png
#rm $1.tmp

# cleanup temp files
#cd ..
#rm -rf $TEMPDIR

