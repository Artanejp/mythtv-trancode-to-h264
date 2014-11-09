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

# a temporary working directory (must be writable by mythtv user)
TEMPDIR="~/mythtv-tmp"

# MySQL database login information (for mythconverg database)
DATABASEUSER="mythtv"
DATABASEPASSWORD="yourpasswordhere"

# MythTV Install Prefix (make sure this matches with the directory where MythTV is installed)
INSTALLPREFIX="/usr/bin"

# Number of threads to use (default uses all threads)
NUMTHREADS="auto"

# don't change these
MYPID=$$
AUDIOTMP="audiotmp"
AUDIOFILE="audio.ogg"
AVIFILE="video.avi"
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
$INSTALLPREFIX/mythcommflag -c "$3" -s "$4" --gencutlist
$INSTALLPREFIX/mythtranscode --chanid "$3" --starttime "$4" --mpeg2 --honorcutlist
echo "UPDATE recorded SET basename='$BASENAME2.tmp' WHERE chanid='$3' AND starttime='$4';" > update-database_$MYPID.sql
mysql --user=$DATABASEUSER --password=$DATABASEPASSWORD mythconverg < update-database_$MYPID.sql

# fix seeking and bookmarking by removing stale db info
echo "DELETE FROM recordedseek WHERE chanid='$3' AND starttime='$4';" > update-database_$MYPID.sql
mysql --user=$DATABASEUSER --password=$DATABASEPASSWORD mythconverg < update-database_$MYPID.sql
echo "DELETE FROM recordedmarkup WHERE chanid='$3' AND starttime='$4';" > update-database_$MYPID.sql
mysql --user=$DATABASEUSER --password=$DATABASEPASSWORD mythconverg < update-database_$MYPID.sql

# convert audio track to ogg vorbis
mkdir $AUDIOTMP
mkfifo $AUDIOTMP/fifo
oggenc -b 64 -o "$AUDIOFILE" $AUDIOTMP/fifo &
mplayer -ao pcm:file=$AUDIOTMP/fifo -vo null -vc dummy -benchmark "$1.tmp" >/dev/null 2>&1

# first video pass
mencoder -nosound -vf crop=704:528:12:0,yadif,scale=512:384,harddup "$1.tmp" -o /dev/null -ovc x264 -x264encopts pass=1:bitrate=1000:threads=$NUMTHREADS

# second video pass
mencoder -nosound -vf crop=704:528:12:0,yadif,scale=512:384,harddup "$1.tmp" -o $AVIFILE -ovc x264 -x264encopts pass=2:bitrate=1000:threads=$NUMTHREADS

# multiplex audio and video together (audio delay set to 200ms. change the 200 to whatever you require if your output file happens to be out of sync, but try this value first)
mkvmerge -o "$DIRNAME/$BASENAME" -A "$AVIFILE" -y 0:200 "$AUDIOFILE"

# update the database to point to the transcoded file and delete the original recorded show.
NEWFILESIZE=`du -b "$DIRNAME/$BASENAME" | cut -f1`
echo "UPDATE recorded SET basename='$BASENAME',filesize='$NEWFILESIZE',transcoded='1' WHERE chanid='$3' AND starttime='$4';" > update-database_$MYPID.sql
mysql --user=$DATABASEUSER --password=$DATABASEPASSWORD mythconverg < update-database_$MYPID.sql
rm $1
rm $1.-1.160x120.png
rm $1.-1.100x75.png
rm $1.png
rm $1.tmp

# cleanup temp files
cd ..
rm -rf mythtmp-$MYPID

