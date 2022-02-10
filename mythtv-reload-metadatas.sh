#!/bin/bash

BASEFILE=$1;

#!/bin/bash
POOL_THREADS=5
FRAME_THREADS=5
PRESET_VALUE="faster"
CRF_VALUE=22.5
CRF_MIN=""
CRF_MAX=""
typeset -i AQ_MODE
AQ_MODE=3
APPEND_X265_MODE=""

#TUNE_VALUE=grain
AQ_VALUE=0.95
QP_ADAPTATIVE_VALUE=1.20
USE_DATABASE=1
BASE_FPS="30000/1001"
FORCE_FPS=0
VIDEO_STREAM="0:0"
#VBV_VALUE=3000

typeset -i COPY_AUDIOS
COPY_AUDIOS=1
AUDIO_CODEC="aac"
AUDIO_ARGS="-ar 48000 -ab 224k"

HEAD_TITLE=""

typeset -i REPLACE_HEADER
typeset -i EPISODE_NUM
APPEND_HEADER="NONE"
REPLACE_HEADER=0
EPISODE_NUM=1

typeset -i USE_10BIT 
USE_10BIT=1
FILTER_STRING=""

FFMPEG_CMD="/usr/bin/ffmpeg"
FFMPEG_SUBTXT_CMD="${FFMPEG_CMD}"

if [ -e /etc/mythtv/mythtv-transcode-x264 ]; then
   . /etc/mythtv/mythtv-transcode-x264
fi
if [ -e $HOME/.mythtv-transcode-x264 ]; then
   . $HOME/.mythtv-transcode-x264
fi

if [ -e "$PWD/mythtv-reload-metadatas.txt" ]; then
   . "$PWD/mythtv-reload-metadatas.txt"
elif [ -e $HOME/.mythtv-reload-metadatas ]; then
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

    case "$1" in
        --num | -n )
	  shift
	  EPNUM=$1
	  HAS_EPNUM=1
	  shift
	  continue
        ;;
        --database | -d )
	  shift
	  USE_DATABASE=$1
	  shift
	  continue
        ;;
        --episode-num )
	  shift
	  EPISODE_NUM=$1
	  shift
	  continue
        ;;
        --replace-header )
	  shift
	  REPLACE_HEADER=1
	  continue
        ;;
        --no-replace-header | --fixed-header )
	  shift
	  REPLACE_HEADER=0
	  continue
        ;;
        --head-title )
	  shift
	  HEAD_TITLE="$1"
	  shift
	  continue
        ;;
        --no-head-title | --reset-head-title )
	  shift
	  HEAD_TITLE=""
	  REPLACE_HEADER=0
	  continue
        ;;
	--append-head-only )
	  shift
	  APPEND_HEADER="HEAD_ONLY"
	  continue
	;;
	--append-head-with-number )
	  shift
	  APPEND_HEADER="NUMERIC"
	  continue
	;;
	--without-head | --no-append-head )
	  shift
	  APPEND_HEADER="NONE"
	  continue
	;;
        --with-database | -d1 )
	  USE_DATABASE=1
	  shift
	  continue
        ;;
        --without-database |--no-database | -d0 )
	  USE_DATABASE=0
	  shift
	  continue
        ;;
        --frame-threads )
	  shift
	  FRAME_THREADS=$1
	  shift
	  continue
        ;;
        --pool-threads )
	  shift
	  POOL_THREADS=$1
	  shift
	  continue
        ;;
        --encode-audio )
	  COPY_AUDIOS=0
	  shift
	  continue
	;;
        --copy-audio )
	  COPY_AUDIOS=1
	  shift
	  continue
	;;
        --threads | -j )
	  shift
	  POOL_THREADS=$1
	  FRAME_THREADS=$1
	  shift
	  continue
        ;;
        --crf )
	  shift
	  CRF_VALUE=$1
	  shift
	  continue
        ;;
        --crf-max )
	  shift
	  CRF_MAX=$1
	  shift
	  continue
        ;;
        --crf-min )
	  shift
	  CRF_MIN=$1
	  shift
	  continue
        ;;
        --reset-crf-max )
	  shift
	  CRF_MAX=""
	  continue
        ;;
        --reset-crf-min )
	  shift
	  CRF_MIN=""
	  continue
        ;;
        --vbv-maxrate | --vbv-max )
	  shift
	  VBV_VALUE=$1
	  shift
	  continue
        ;;
        --reset-vbv-maxrate | --reset-vbv-max )
	  VBV_VALUE=""
	  shift
	  continue
        ;;
        --aq-value )
	  shift
	  AQ_VALUE=$1
	  shift
	  continue
        ;;
        --aq-mode )
	  shift
	  AQ_MODE=$1
	  shift
	  continue
        ;;
        --reset-aq-value )
	  AQ_VALUE=""
	  shift
	  continue
        ;;
        --qp-adaptive )
	  shift
	  QP_ADAPTATIVE_VALUE=$1
	  shift
	  continue
        ;;
        --reset-qp-adaptive )
	  QP_ADAPTATIVE_VALUE=""
	  shift
	  continue
        ;;
        --preset )
	  shift
	  PRESET_VALUE=$1
	  shift
	  continue
        ;;
        --tune )
	  shift
	  TUNE_VALUE=$1
	  shift
	  continue
        ;;
        --reset-tune )
	  TUNE_VALUE=""
	  shift
	  continue
        ;;
        --db-user )
	  shift
	  DATABASEUSER="$1"
	  shift
	  continue
        ;;
        --db-passwd )
	  shift
	  DATABASEPASSWORD="$1"
	  shift
	  continue
        ;;

    --fps )
	  shift
	  BASE_FPS=$1
	  shift
	  continue
        ;;
    --force-fps | --no-auto-fps )
		shift
		FORCE_FPS=1
		continue
        ;;
    --no-force-fps | --auto-fps )
		shift
		FORCE_FPS=0
		continue
        ;;
	* )
        BASEFILE="$1"
	;;
    esac

# ToDo

FILTER_STRING_1="${FILTER_STRING_1}"

if [ "___x___${BASEFILE}" = "___x___" ] ; then
   exit 0
fi
    ARG_METADATA=""
    ARG_DESC=""
    ARG_SUBTITLE=""
    ARG_EPISODE=""
    ARG_ONAIR=""
    __N_TITLE=""

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
s/\.wmv//g
s/\.mkv//g
s/\.mp4//g
s/\.ts//g
s/\.m2ts//g
s/\.mpg//g
s/\.avi//g
s/\.WMV//g
s/\.MKV//g
s/\.MP4//g
s/\.TS//g
s/\.M2TS//g
s/\.MPG//g
s/\.AVI//g
EOF

ARG_TITLE=""
ARG_SUBTITLE=""
ARG_DESC=""
ARG_STARTTIME=""
ARG_ENDTIME=""
ARG_GENRE=""
ARG_EPISODE=""
ARG_SEASON=""
ARG_CHANID=""

ARG_KEY=`echo "${BASEFILE}" | gawk "${AWK_EXTRACT1}" | sed -f "${TEMPDIR}/__tmpscript13" `

if [ ${USE_DATABASE} -ne 0 ] ; then
     
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
else
	# WITHOUT DATABASE
	ARG_METADATA="-map_metadata:g 0 "
	
	#ARG_TITLE="${ARG_KEY}"
	if [ "__x__${ARG_TITLE}" != "__x__" ] ; then
		ARG_METADATA="${ARG_METADATA} -metadata:g title=${ARG_TITLE} "
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

__AWK_GETFPS=" 
    BEGIN {
	   FS=\",\";
   }
   \$1~/^.*Video:/ {
   	  for(i = 1; i < NF; i++ ) {
	      if(match(\$i, /^.*fps/)) {
		  	 gsub(/ /, \"\", \$i);
		  	 gsub(/fps/, \"\", \$i);
		     printf(\"%s\\n\", \$i);
		     break;
	       }
	      if(match(\$i, /^.*tbr/)) {
		  	 gsub(/ /, \"\", \$i);
		  	 gsub(/tbr/, \"\", \$i);
		     printf(\"%s\\n\", \$i);
		     break;
	       }
	  }
    }
"
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
	   gsub(/\\[.*\\]/, \"\", __ST_NUM[2]); #Todo
	   
	   STREAM_NUM=__ST_NUM[1] \":\" __ST_NUM[2];
	   _ARG_STREAM[inum] = STREAM_NUM;
	   _ARG_TYPE[inum] = ST_TYPE;
	   inum++;
	   next;
	}
	END {
	   for(i = 1; i <= inum; i++) {
	      
	      if(match(_ARG_TYPE[i], \"Video\") != 0) {
	           printf(\"-map:v %s \", _ARG_STREAM[i]);
	      } else if(match(_ARG_TYPE[i], \"Audio\") != 0) {
	           if(AUDIO_COPY != 0) {
	                printf(\"-map:a %s -c:a copy \", _ARG_STREAM[i]);
		   } else {
		        printf(\"-map:a %s -c:a %s %s \", _ARG_STREAM[i], AUDIO_CODEC, AUDIO_ARGS);
		   }
              } else if(match(_ARG_TYPE[i], \"Subtitle\") != 0) {
	           printf(\"-map:s %s -c:s subrip \", _ARG_STREAM[i]);
              } else if(match(_ARG_TYPE[i], \"Attachment\") != 0) {
	           printf(\"-map:t %s -c:t copy  \", _ARG_STREAM[i]);
              }
	   }
	}
	"

declare -a ARG_SUBTITLES
declare -a ARG_MAPCOPY_SUBS
typeset -i __sb_num
__sb_num=1;
BASEFILE3=`echo "${BASEFILE}" | sed -f "${TEMPDIR}/__tmpscript13" `
for __sb in "ass" "ASS" "srt" "SRT" "ttml" "TTML" "vtt" "VTT" ; do 
    __tmp_sb=""
    ARG_SUBTITLES[$__sb_num]=""
    ARG_MAPCOPY_SUBS[$__sb_num]=""
    if [ -e "${BASEFILE3}.${__sb}" ] ; then
       __tmp_sb="${BASEFILE3}.${__sb}"
       ARG_SUBTITLES[$__sb_num]="${__tmp_sb}"
       ARG_MAPCOPY_SUBS[$__sb_num]="-map:s ${__sb_num}:0 -c:s subrip"
      __sb_num=__sb_num+1
    fi
done
#echo ${ARG_SUBTITLES}
#exit 1

ARG_FPS=""
ARG_STREAM=`echo "${FFPROBE_RESULT}" | grep "Stream"`
if [ ${COPY_AUDIOS} -ne 0 ] ; then
    ARG_COPYMAP=`echo "${ARG_STREAM}" | gawk -v AUDIO_COPY=1 "${__AWK_STREAMDESC}"`
else
    ARG_COPYMAP=`echo "${ARG_STREAM}" | gawk -v AUDIO_COPY=0 -v AUDIO_CODEC="${AUDIO_CODEC}" -v AUDIO_ARGS="${AUDIO_ARGS}" "${__AWK_STREAMDESC}"`
fi


ARG_FPS=`echo "${ARG_STREAM}" | gawk "${__AWK_GETFPS}"`

case "${ARG_FPS}" in
     "23.98" )
       ARG_FPS="24000/1001"
       ;;
     "29.97" )
       ARG_FPS="30000/1001"
       ;;
     "59.94" )
       ARG_FPS="60000/1001"
       ;;
esac

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

case "${AQ_MODE}" in
   "4" )
      __X265_PARAMS="${__X265_PARAMS}:aq-mode=4:aq-motion=true:${AQ_ARG}"       
      ;;
   "1" | "2" | "3" | "0" )
      __X265_PARAMS="${__X265_PARAMS}:aq-mode=${AQ_MODE}:${AQ_ARG}"
      ;;
   * )
      __X265_PARAMS="${__X265_PARAMS}:aq-mode=3:${AQ_ARG}"
      ;;
esac

if test "__n__${QP_ADAPTATIVE_VALUE}" != "__n__" ; then
    __X265_PARAMS="${__X265_PARAMS}:qp-adaptation-range=${QP_ADAPTATIVE_VALUE}"
fi
if test "__n__${VBV_VALUE}" != "__n__" ; then
    __X265_PARAMS="${__X265_PARAMS}:vbv-maxrate=${VBV_VALUE}"
fi
#    __X265_PARAMS="${__X265_PARAMS}:pme=true:pmode=true"

if [ "__n__${CRF_MIN}" != "__n__" ] ; then
    __X265_PARAMS="${__X265_PARAMS}:crf-min=${CRF_MIN}"
fi
if [ "__n__${CRF_MAX}" != "__n__" ] ; then
    __X265_PARAMS="${__X265_PARAMS}:crf-max=${CRF_MAX}"
fi

__X265_DISP_PARAMS=""
if test "__n__${PRESET_VALUE}" != "__n__" ; then
    __X265_DISP_PARAMS=":preset=${PRESET_VALUE}"
fi    
if test "__n__${TUNE_VALUE}" != "__n__" ; then
    __X265_DISP_PARAMS=":tune=${TUNE_VALUE}${__X265_DISP_PARAMS}"
fi    
__X265_DISP_PARAMS="crf=${CRF_VALUE}:${__X265_PARAMS}${__X265_DISP_PARAMS}"


__START_DATE=`date -Iseconds`

BASEFILE3=`echo "${BASEFILE}" | sed -f "${TEMPDIR}/__tmpscript13" `
EPSTR=""
TMP_BASE1=""
TMP_BASE2=""

if [ "__x__${HEAD_TITLE}" != "__x__" ] ; then
   EPSTR=`printf "%03d" ${EPISODE_NUM}`
   TMP_BASE1="${HEAD_TITLE}_#${EPSTR} "   
   TMP_BASE2="${HEAD_TITLE} "   
fi
if [ ${REPLACE_HEADER} -ne 0 ] ; then
   BASEFILE3="${TMP_BASE1}"
else 
   case "${APPEND_HEADER}" in
       NUMERIC )
         BASEFILE3="${TMP_BASE1}${BASEFILE3}"
	 ;;
       HEAD_ONLY )
         BASEFILE3="${TMP_BASE2}${BASEFILE3}"
	 ;;
       * )
         ;;
    esac
fi

if [ "__x__${ARG_FPS}" != "__n__" ] ; then
	if [ ${FORCE_FPS} -ne 0 ] ; then
		FPS_VAL=${BASE_FPS}
	else
		FPS_VAL=${ARG_FPS}
	fi
else
	FPS_VAL=${BASE_FPS}
fi

APPEND_ARGS_INPUT=""
APPEND_ARGS_MAPS=""
#APPEND_ARGS_INPUT=$( for __xx in "${ARG_SUBTITLES[@]}" ; do if [ "__xx__${__xx}" != "__xx__" ] ; then echo "-i \"${__xx}\"" ; fi ; done )
#echo ${APPEND_ARGS_INPUT}
#exit 1
if [ ${USE_10BIT} -ne 0 ] ; then
   FILTER_FORMAT="format=yuv420p10le"
   PROFILE_ARG="main10"
else
   FILTER_FORMAT="format=yuv420p"
   PROFILE_ARG="main"
fi
if [ "__xx__" != "__xx__${FILTER_STRING_1}" ] ; then
   FILTER_ARG="${FILTER_STRING_1}:${FILTER_FORMAT}"
else
   FILTER_ARG="${FILTER_FORMAT}"
fi

${FFMPEG_CMD} -i "${BASEFILE}" \
			  ${ARG_COPYMAP} \
			  -vf "${FILTER_ARG}" \
			  -threads 4 -filter_complex_threads 4 -filter_threads 4 \
			  -map_chapters 0 \
			  -c:v libx265 \
			  -profile:v ${PROFILE_ARG} \
			  -r:v ${FPS_VAL} \
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
			  -y "re-enc/${BASEFILE3}(Re-Enc HEVC CRF=${CRF_VALUE}).mkv"\


EPISODE_NUM=EPISODE_NUM+1

shift
done

