#!/bin/bash

BASEFILE=$1;

#!/bin/bash
POOL_THREADS=8
FRAME_THREADS=8
PRESET_VALUE="faster"
CRF_VALUE=22.5
#TUNE_VALUE=grain
AQ_VALUE=0.90
QP_ADAPTATIVE_VALUE=1.20
#VBV_VALUE=3000

FFMPEG_CMD="/usr/bin/ffmpeg"
FFMPEG_SUBTXT_CMD="${FFMPEG_CMD}"

if [ -e /etc/mythtv/mythtv-transcode-x264 ]; then
   . /etc/mythtv/mythtv-transcode-x264
fi
if [ -e $HOME/.mythtv-transcode-x264 ]; then
   . $HOME/.mythtv-transcode-x264
fi

if [ -e $HOME/.mythtv-reload-metadatas ]; then
   . $HOME/.mythtv-reload-metadatas
fi


function logging() {
   __str="$@"
   echo ${__str} | logger -t "MYTHTV.RENAME[${BASHPID}]"
   echo ${__str}
}

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
s/"\n"/"\\\n"/g
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
s/"\n"/"\\\n"/g
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
s/"\n"/"\\\n"/g
EOF
__tmpv1=`cat ${__SRCFILE} | sed -f "${TEMPDIR}/__tmpscript12"`
#rm ${TEMPDIR}/__tmpscript12
echo "${__tmpv1}"
}


for x in "$@"; do \

    ARG_METADATA=""
    ARG_DESC=""
    ARG_SUBTITLE=""
    ARG_EPISODE=""
    ARG_ONAIR=""
    __N_TITLE=""
    BASEFILE="$1"
    TEMPDIR=`mktemp -d`
    
AWK_EXTRACT1="
      BEGIN {
         FS=\"_\";
	 IS_START=0;
       }
      NR==1 {
         for(x = 1; x <= NF; x++) {
	     if(IS_START == 0) { 
	         if(match(\$x, /^[0-9]+/)) {
		     __TOKEN1=\$x;
	            __TOKEN2=\$(x+1);
		    IS_START=1;
		 }
	      } else {
	         if(match(\$x, /[0-9]+/)) {

		 }
	      }
	 }
	 printf(\"%s_%s\", __TOKEN1, __TOKEN2);

      }
      "
cat <<EOF >${TEMPDIR}/__tmpscript13
s/\.mkv//g
s/\.mp4//g
s/\.ts//g
s/\.m2ts//g
s/\.mpg//g
EOF
      
  ARG_KEY=`echo "${BASEFILE}" | gawk "${AWK_EXTRACT1}" | sed -f "${TEMPDIR}/__tmpscript13" `
  
      
#  echo "SELECT recordedid from recorded where basename=\"${BASEFILE}\" ;" > "$TEMPDIR/getrecid.query.sql"
  echo "SELECT recordedid from recorded where basename like \"%${ARG_KEY}%\" ;" > "$TEMPDIR/getrecid.query.sql"
  RECID=`mysql -B -N  --user=$DATABASEUSER --password=$DATABASEPASSWORD mythconverg < "$TEMPDIR/getrecid.query.sql"`

if [ -z "${RECID}" ] ; then 
     logging "ERROR: Recording not found."
else
echo "SELECT chanid from recorded where recordedid=\"${RECID}\" ;" > "$TEMPDIR/getchanid.query.sql"
  mysql -B -N  --user=$DATABASEUSER --password=$DATABASEPASSWORD mythconverg < "$TEMPDIR/getchanid.query.sql" > "$TEMPDIR/chanid.txt"

echo "SELECT title from recorded where recordedid=\"${RECID}\" ;" > "$TEMPDIR/gettitle.query.sql"
#  logging `cat "$TEMPDIR/gettitle.query.sql"`
  mysql -B -N  --user=$DATABASEUSER --password=$DATABASEPASSWORD mythconverg < "$TEMPDIR/gettitle.query.sql" > "$TEMPDIR/title.txt" 

#  logging `cat "$TEMPDIR/title.txt"`
__N_TITLE=`cat "$TEMPDIR/title.txt"`


echo "SELECT subtitle from recorded where recordedid=\"${RECID}\" ;" > "$TEMPDIR/getsubtitle.query.sql"
#  logging `cat "$TEMPDIR/getsubtitle.query.sql"`
  mysql -B -N  --user=$DATABASEUSER --password=$DATABASEPASSWORD mythconverg < "$TEMPDIR/getsubtitle.query.sql" > "$TEMPDIR/subtitle.txt" 
#  logging `cat "$TEMPDIR/subtitle.txt"`

echo "SELECT description from recorded where recordedid=\"${RECID}\" ;" > "$TEMPDIR/getdesc.query.sql"
#  logging `cat "$TEMPDIR/getdesc.query.sql"`
  mysql -B -N  --user=$DATABASEUSER --password=$DATABASEPASSWORD mythconverg < "$TEMPDIR/getdesc.query.sql" > "$TEMPDIR/desc.txt" 
#  logging `cat "$TEMPDIR/desc.txt"`

echo "SELECT starttime from recorded where recordedid=\"${RECID}\" ;" > "$TEMPDIR/getstarttime.query.sql"
  mysql -B -N  --user=$DATABASEUSER --password=$DATABASEPASSWORD mythconverg < "$TEMPDIR/getstarttime.query.sql" > "$TEMPDIR/starttime.txt" 
echo "SELECT endtime from recorded where recordedid=\"${RECID}\" ;" > "$TEMPDIR/getendtime.query.sql"
  mysql -B -N  --user=$DATABASEUSER --password=$DATABASEPASSWORD mythconverg < "$TEMPDIR/getendtime.query.sql" > "$TEMPDIR/endtime.txt" 
echo "SELECT category from recorded where recordedid=\"${RECID}\" ;" > "$TEMPDIR/getgenre.query.sql"
  mysql -B -N  --user=$DATABASEUSER --password=$DATABASEPASSWORD mythconverg < "$TEMPDIR/getgenre.query.sql" > "$TEMPDIR/genre.txt" 
echo "SELECT season from recorded where recordedid=\"${RECID}\" ;" > "$TEMPDIR/getseason.query.sql"
  mysql -B -N  --user=$DATABASEUSER --password=$DATABASEPASSWORD mythconverg < "$TEMPDIR/getseason.query.sql" > "$TEMPDIR/season.txt" 
echo "SELECT episode from recorded where recordedid=\"${RECID}\" ;" > "$TEMPDIR/getepisode.query.sql"
  mysql -B -N  --user=$DATABASEUSER --password=$DATABASEPASSWORD mythconverg < "$TEMPDIR/getepisode.query.sql" > "$TEMPDIR/episode.txt" 


ARG_TITLE=$(change_arg_file "$TEMPDIR/title.txt")
ARG_SUBTITLE=$(change_arg_file "$TEMPDIR/subtitle.txt")
ARG_DESC=$(change_arg_file "$TEMPDIR/desc.txt")
ARG_STARTTIME=`cat "$TEMPDIR/starttime.txt" | sed 's/ /T/g'`
ARG_ENDTIME=`cat "$TEMPDIR/endtime.txt" | sed 's/ /T/g'`
ARG_GENRE=$(change_arg_file "$TEMPDIR/genre.txt")
ARG_EPISODE=$(change_arg_file "$TEMPDIR/episode.txt")
ARG_SEASON=$(change_arg_file "$TEMPDIR/season.txt")
ARG_CHANID=$(change_arg_file "$TEMPDIR/chanid.txt")


ARG_REALTITLE=${ARG_TITLE}
ARG_TITLE="${ARG_TITLE}:${ARG_SUBTITLE}"

ARG_METADATA="-map_metadata:g 0 "

if [ "__x__${ARG_TITLE}" != "__x__" ] ; then
   ARG_METADATA="${ARG_METADATA} -metadata:g title=${ARG_TITLE} "
fi
if [ "__x__${ARG_SUBTITLE}" != "__x__" ] ; then
   ARG_METADATA="${ARG_METADATA} -metadata:g subtitle=${ARG_SUBTITLE} "
fi
if [ "__x__${ARG_DESC}" != "__x__" ] ; then
   ARG_METADATA="${ARG_METADATA} -metadata:g description=${ARG_DESC} "
fi
if [ "__x__${ARG_REALTITLE}" != "__x__" ] ; then
   ARG_METADATA="${ARG_METADATA} -metadata:g realtitle=${ARG_REALTITLE} "
fi
if [ "__x__${ARG_EPISODE}" != "__x__" ] ; then
   ARG_METADATA="${ARG_METADATA} -metadata:g episode=${ARG_EPISODE} "
fi
if [ "__x__${ARG_SEASON}" != "__x__" ] ; then
   ARG_METADATA="${ARG_METADATA} -metadata:g season=${ARG_SEASON} "
fi
if [ "__x__${ARG_GENRE}" != "__x__" ] ; then
   ARG_METADATA="${ARG_METADATA} -metadata:g genre=${ARG_GENRE} "
fi
if [ "__x__${RECID}" != "__x__" ] ; then
   ARG_METADATA="${ARG_METADATA} -metadata:g recordedid=${RECID} "
fi
if [ "__x__${ARG_CHANID}" != "__x__" ] ; then
   ARG_METADATA="${ARG_METADATA} -metadata:g channel_id=${ARG_CHANID} "
fi
if [ "__x__${ARG_STARTTIME}" != "__x__" ] ; then
   ARG_METADATA="${ARG_METADATA} -metadata:g starttime_utc=${ARG_STARTTIME} "
fi
if [ "__x__${ARG_ENDTIME}" != "__x__" ] ; then
   ARG_METADATA="${ARG_METADATA} -metadata:g endtime_utc=${ARG_ENDTIME} "
fi
fi

cat <<EOF >${TEMPDIR}/__tmpscript14
s/\ /　/g
EOF

if [ "__x__${BASEFILE}" != "__x__" ] ; then
   BASEFILE2=`echo "${BASEFILE}" | sed -f "${TEMPDIR}/__tmpscript14"`
#   ARG_METADATA="${ARG_METADATA} -metadata:g source=\"${BASEFILE2}\" "
fi

#echo "${ARG_METADATA}"
#exit 1

FFPROBE_RESULT=`ffprobe "${BASEFILE}" 2>&1`
echo
#echo "${FFPROBE_RESULT}"

__AWK_STREAMDESC="
	BEGIN {
	   inum=1;
	}
	{
	   ST_NUM=\$2;
	   ST_TYPE=\$3;
	   
	   N_NUM = split(ST_NUM, __ST_NUM, \":\");
	   STREAM_NUM=\"\";
	   gsub(/#/, \"\", __ST_NUM[1]);
	   gsub(/\\(.*\\)/, \"\", __ST_NUM[2]);
	   
	   STREAM_NUM=__ST_NUM[1] \":\" __ST_NUM[2];
	   _ARG_STREAM[inum] = STREAM_NUM;
	   _ARG_TYPE[inum] = ST_TYPE;
	   inum++;
	   next;
	}
	END {
	   for(i = 1; i <= inum; i++) {
	      
	      if(match(_ARG_TYPE[i], \"Video\") != 0) {
	           #printf(\"-map:v %s -c:v copy \", _ARG_STREAM[i]);
	      } else if(match(_ARG_TYPE[i], \"Audio\") != 0) {
	           printf(\"-map:a %s -c:a copy \", _ARG_STREAM[i]);
              } else if(match(_ARG_TYPE[i], \"Subtitle\") != 0) {
	           printf(\"-map:s %s -c:s copy \", _ARG_STREAM[i]);
              }
	   }
	}
	"
ARG_STREAM=`echo "${FFPROBE_RESULT}" | grep "Stream"`
ARG_COPYMAP=`echo "${ARG_STREAM}" | gawk "${__AWK_STREAMDESC}"`

#echo "${ARG_COPYMAP}"
#echo
#exit 1

TUNE_ARG=""
if test "__n__${TUNE_VALUE}" != "__n__" ; then
    TUNE_ARG="-tune ${TUNE_VALUE}"
fi
PRESET_ARG=""
if test "__n__${PRESET_VALUE}" != "__n__" ; then
    PRESET_ARG="-preset ${PRESET_VALUE}"
fi

AQ_ARG=""
if test "__n__${AQ_VALUE}" != "__n__" ; then
    AQ_ARG="aq-strength=${AQ_VALUE}"
else
    AQ_ARG="aq-strength=1.0"
fi
QP_ADAPTATIVE_ARG=""    
__X265_PARAMS="pools=${POOL_THREADS}:frame_threads=${FRAME_THREADS}"
__X265_PARAMS="${__X265_PARAMS}:hevc-aq=true"
#__X265_PARAMS="${__X265_PARAMS}:${AQ_ARG}:aq-mode=4:aq-motion=true"
__X265_PARAMS="${__X265_PARAMS}:${AQ_ARG}:aq-mode=3"
if test "__n__${QP_ADAPTATIVE_VALUE}" != "__n__" ; then
    __X265_PARAMS="${__X265_PARAMS}:qp-adaptation-range=${QP_ADAPTATIVE_VALUE}"
fi
if test "__n__${VBV_VALUE}" != "__n__" ; then
    __X265_PARAMS="${__X265_PARAMS}:vbv-maxrate=${VBV_VALUE}"
fi
#    __X265_PARAMS="${__X265_PARAMS}:pme=true:pmode=true"

__X265_DISP_PARAMS=""
if test "__n__${PRESET_VALUE}" != "__n__" ; then
    __X265_DISP_PARAMS=":preset=${PRESET_VALUE}"
fi    
if test "__n__${TUNE_VALUE}" != "__n__" ; then
    __X265_DISP_PARAMS=":tune=${TUNE_VALUE}${__X265_DISP_PARAMS}"
fi    
__X265_DISP_PARAMS="crf=${CRF_VALUE}${__X265_DISP_PARAMS}:${__X265_PARAMS}"


__START_DATE=`date -Iseconds`

BASEFILE3=`echo "${BASEFILE}" | sed -f "${TEMPDIR}/__tmpscript13" `

${FFMPEG_CMD} -i "${BASEFILE}" \
			  -map:v 0:0 \
			  ${ARG_COPYMAP} \
			  -vf "format=yuv420p10le" \
			  -threads 4 -filter_complex_threads 4 -filter_threads 4 \
			  -map_chapters 0 \
			  -c:v libx265 \
			  -profile:v main10 \
			  -r:v 30000/1001 \
			  -crf ${CRF_VALUE}  \
			  ${PRESET_ARG}  \
			  ${TUNE_ARG} \
			  -x265-params "${__X265_PARAMS}" \
			  -map_metadata:g 0 \
			  -map_chapters 0 \
			  ${ARG_METADATA} \
			  -metadata:g source="${BASEFILE}" \
			  -metadata:s:v source="${BASEFILE}" \
			  -metadata:s:a source="${BASEFILE}" \
			  -metadata:s:v x265_params="${__X265_DISP_PARAMS}" \
			  -y "re-enc/${BASEFILE3}(Re-Enc HEVC CRF=${CRF_VALUE}).mkv"


shift
done

