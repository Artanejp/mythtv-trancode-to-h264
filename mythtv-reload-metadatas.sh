#!/bin/bash

BASEFILE="$1"

declare -a ARG_METADATA

NUMA_NODES=""
POOL_THREADS=5
FRAME_THREADS=5
PRESET_VALUE="faster"
CRF_VALUE=22.5
CRF_MIN=""
CRF_MAX=""

# HEVC or HAVC or AV1 ?
VCODEC_TYPE="HEVC"
BASE_AV1_ENCODER="SVTAV1"
typeset -i AQ_MODE
AQ_MODE=3

declare -a APPEND_VCODEC_PARAMETERS_PRE
unset APPEND_VCODEC_PARAMETERS_PRE[@]

declare -a APPEND_VCODEC_PARAMETERS_POST
unset APPEND_VCODEC_PARAMETERS_POST[@]

FILTER_THREADS=12
FILTER_COMPLEX_THREADS=12
FFMPEG_THREADS=18

TUNE_VALUE=""

AQ_VALUE=0.95
QP_ADAPTATIVE_VALUE=1.20
USE_DATABASE=1
BASE_FPS="30000/1001"

typeset -i FORCE_FPS
typeset -i DETECT_VFR
typeset -i PASSTHROUGH_FPS

PASSTHROUGH_FPS=0
FORCE_FPS=0
DETECT_VFR=1
MAXIMUM_FPS="60000/1001"

typeset -i SVTAV1_DISABLE_TEMPORAL_FILTERING
SVTAV1_DISABLE_TEMPORAL_FILTERING=0

VIDEO_STREAM="0:0"
#VBV_VALUE=3000

typeset -i COPY_AUDIOS
COPY_AUDIOS=1
AUDIO_CODEC="aac"
AUDIO_ARGS="-ar 48000 -ab 224k"

HEAD_TITLE=""
META_TITLE=""
COMMENTS=""

typeset -i REPLACE_TITLE
typeset -i REPLACE_HEADER
typeset -i EPISODE_NUM

APPEND_HEADER="NONE"
REPLACE_HEADER=0
REPLACE_TITLE=0
EPISODE_NUM=1

EPISODES_LIST_FILE=""

typeset -i USE_10BIT 
typeset -i USE_HDR10
USE_10BIT=1
USE_HDR10=0
FILTER_STRING=""
typeset -i PREFETCH_FILE
PREFETCH_FILE=0

typeset -i DUMP_SUB_FROM_SOURCE
DUMP_SUB_FROM_SOURCE=0

typeset -i ADD_SUB_IF_EXISTS
ADD_SUB_IF_EXISTS=1

declare -a MUXER_OPTIONS
unset MUXER_OPTIONS[@]

FFMPEG_CMD="/usr/bin/ffmpeg"
FFMPEG_SUBTXT_CMD="${FFMPEG_CMD}"

NICE_CMD="/bin/nice"
RENICE_CMD="/bin/renice"
IONICE_CMD=/bin/ionice

typeset -i NICE_VALUE
typeset -i IONICE_VALUE


NICE_VALUE=13
IONICE_CLASS=""
IONICE_VALUE=-1

# Example:
# FFMPEG_APPEND_ARGS_PRE+=(__EPISODE_001) # Episode Number, this set __EPISODE_ALL to all episode(default)
# FFMPEG_APPEND_ARGS_PRE+=(-metadata:s:a:1) # Arg1
# FFMPEG_APPEND_ARGS_PRE+=(language=jpn) # Arg2

declare -a FFMPEG_APPEND_ARGS_PRE
unset FFMPEG_APPEND_ARGS_PRE[@]

declare -a FFMPEG_APPEND_ARGS_POST
unset FFMPEG_APPEND_ARGS_POST[@]

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

if [ "__x__${EPISODES_LIST_FILE}" = "__x__" ] ; then
    if [ -e "$PWD/episodes_list.txt" ]; then
       EPISODES_LIST_FILE="$PWD/episodes_list.txt"
    fi
fi


declare -a COLORSPACE_ARGS
unset COLORSPACE_ARGS[@]

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
__AWK_EPLIST_GETDEFINES="
	function check_define(type, defstr, defnum, src, ans) {
		ans=\"\";
		if(isarray(src)) {
			ii=1;
			for(ss in defstr) {
				#printf(\"%s %s\\n\\r\", type, defstr[ss]);
				if(match(defstr[ss], type)) {
					#if(src[defnum[ii]] != \"\") { 
						ans=src[defnum[ii]];	  
						return ans;
					#}	
				}
				ii++;				
			}
		}
		return ans;
	}
    BEGIN {
		GET_BEGIN=0;
		__DEFINES=1;
		__EP_FIELDS=0;
		__TITLE_FIELDS=0;
		FS=\"[\t ]+\";
	}
	/@DEFINE.*\$/ {
		if(GET_BEGIN == 0) {
			if(NF >= 3) {
				__DEFNUM[__DEFINES] = \$2;
				__DEFSTR[__DEFINES] = \$3;
				__DEFINES++;
				#printf(\"@DEFINE %s=%s\\n\\r\", __DEFNUM[__DEFINES-1], __DEFSTR[__DEFINES-1]); 
			}
		}
		next;
	}
	/@BEGIN.*\$/ {
		if(GET_BEGIN == 0) {
			if(match(\$2, \"EPISODES\")) {
				delete __EPISODES_ARRAY;
				FS=\"[\\t ]+\";
				GET_BEGIN=1;
				GET_TITLE=0;
			} else if(match(\$2, \"DEFINE\")) {
				# GET TITLE
				delete __TITLE_ARRAY;
				FS=\"[\\t ]+\";
				GET_BEGIN=1;
				GET_TITLE=1;		
			} 
		}
		next;
	}	
	/^@END/ {
		if(GET_BEGIN != 0) {
			FS=\" \";
			GET_BEGIN=0;
			GET_TITLE=0;
		}
		#print \"end\\n\";
		next;
	}
	/^#.*$/ {
		#print \"comment x\\n\";
	}  
	/^#$/ {
		#print \"comment 0\\n\";
	}  
	{
		if(GET_BEGIN != 0) {
			if(GET_TITLE != 0) {
				for(xx = 1; xx <= NF; xx++) {
					__TITLE_ARRAY[xx]=\$xx;
					#printf(\"%s\\n\\r\", \$xx);
				}
				if(NF >= 1) {
					__TITLE_FIELDS=NF;
				}
			} else {
				NUM=\$1;
				if(NUM==__EPNUM) {
					for(xx = 1; xx <= NF; xx++) {
						__EPISODES_ARRAY[xx]=\$xx;
						#printf(\"%s\\n\\r\", \$xx);
					}
					if(NF > 1) {
						__EP_FIELDS=NF;
					}
				}
			}  
		}
		next;		
	}
	END {
		#if(!isarray(__EPISODES_ARRAY)) {
		#	exit 1;
		#}
		#if(!isarray(__TITLE_ARRAY)) {
		#	exit 1;
		#}
		#for(xx in __TITLE_ARRAY) {
		#	printf(\"%s\\n\\r\", __EPISODES_ARRAY[xx]);
		#}
		#exit 0;
		ans=\"\";
		if(match(_TYPE, \"description\")) {
			ii=1;
			for(xx in __TITLE_ARRAY) {
				ans = ans  __TITLE_ARRAY[xx]  \":\\t\" __EPISODES_ARRAY[xx]  \"\\n\\r\";
				ii++;
			}
			for(ij = ii ; ij <= __EPISODE_FIELDS; ij++) {
				ans = ans  \"\\t\" __EPISODES_ARRAY[ij]  \"\\n\\r\";
			}
			printf(\"%s\", ans);
		} else if(match(_TYPE, \"title\")) {
			ans=check_define(\"SUBTITLE\", __DEFSTR, __DEFNUM, __EPISODES_ARRAY, ans);
			printf(\"%s\", ans);
		} else if(match(_TYPE, \"date\")) {
			ans=check_define(\"BROADCAST_DATE\", __DEFSTR, __DEFNUM, __EPISODES_ARRAY, ans);
			printf(\"%s\", ans);
		} else if(match(_TYPE, \"episode_num\")) {
			ans=check_define(\"EPNUM\", __DEFSTR, __DEFNUM, __EPISODES_ARRAY, ans);
			printf(\"%s\", ans);
		}
	}
	"
# TEST

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

function change_arg_comment() {
# $1 = str
__SRCFILE="$1"

__tmpv03=`cat ${__SRCFILE}`
echo "${__tmpv03}"
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


function print_help() {

echo "mythtv-reload-metadatas.sh [ARGUMENTS | FILES]"
echo "Reload metadata / Re-Transcode MOVIES."
echo
echo "ARGUMENTS:"
echo "--help                       : This help."
echo
echo "Around episode and metadata:"
echo "--num EPISODE_NUMBER         : Start from episode EPISODE_NUMBER (numeric)"
echo "-n EPISODE_NUMBER            : Alias of --num."
echo "--episode-num EPISODE_NUMBER : Change EPISODE_NUMBER at next."
echo "--replace-header             : Replace File name.Not keep original file name."
echo "--no-replace-header          : Not replace Filename.Adding to original filename."
echo "--replace-title              : Replace title (only metadata).Maybe not keep original title."
echo "--no-replace-title           : Not replace title (only metadata).Adding title to original title."
echo "--head-title TITLE           : Set file name to FILENAME."
echo "--reset-head-title           : Reset FILENAME before setting."
echo "--meta-title TITLE           : Set title to TITLE."
echo "--reset-meta-title           : Reset TITLE before setting."
echo "--append-head-only           : Append set FILENAME to original filename.Not counting numeric (caution!)."
echo "--append-head-with-number    : Append set FILENAME and numeric number to original filename."
echo
echo "Database:"
echo "--database [0|1]       : Use database of Mythtv for metadata."
echo "-d [0|1]               : Alias of --database."
echo "--with-database        : Use databese from next."
echo "-d1                    : alias of --with-database ."
echo "  --without-database   : Not use databese from next."
echo "  --db-user  USER      : Login database as USER."
echo "  --db-passwd PASSWORD : Login database with PASSWORD."
echo
echo "Job controlling:"
echo "  --prefetch-mb  MB    : Allow prefetch source file up to MB Megabytes.Useful for fast transcoding."
echo "  --pool-threads   THREADS : Set thread pool to THREADS. See manual of x265."
echo "  --frame-threads  THREADS : Set frame threads to THREADS. See manual of x265."
echo "  --threads        THREADS : Set both thread pool and frame thread to THREADS. See manual of x265."
echo "  --ffmpeg-threads THREADS : Set ffmpeg threads to THREADS. Equivalent to ffmpeg -threads THREADS ."
echo "  --filter-threads THREADS : Set ffmpeg filter threads to THREADS. Equivalent to ffmpeg -filter_threads THREADS ."
echo "  --filter-complex-threads THREADS : Set ffmpeg filter complex threads to THREADS. Equivalent to ffmpeg -filter_complex_threads THREADS ."
echo "  --ionice-value INTEGER   : Set ionice value. (0 to 7). See man ionice (1)."
echo "  --ionice-class TYPE      : Set ionice class. See man ionice (1)."
echo "  --nice-value   INTEGER   : Set nice value. (-20 to 20). See man nice (1)."
echo 
echo "Important around transcoding:"
echo "  --encode-audio          : Encode audio to another codec, bitrate."
echo "  --copy-audio            : Not encode (=COPY) audio to another codec, bitrate.Keep original."
echo "  --preset   TYPE         : Set preset type (i.e. veryfast, faster, fast, slower...) to TYPE. See manual of x265."
echo "  --tune     TYPE         : Set tune type (i.e. grain, animation...) to TYPE. See manual of x265."
echo "  --crf VALUE             : Set CRF quant value to VALUE. See manual of x265."
echo "  --aq-value VALUE        : Set adaptive quant value to VALUE. See manual of x265."
echo "  --aq-mode MODE          : Set adaptive quant mode to MODE. See manual of x265."
echo "  --qp-adaptive VALUE     : Set QP adaptive value to VALUE. See manual of x265."
echo "  --reset-aq-value        : Reset adaptive quant value to default (normally 1.0)."
echo "  --reset-qp-adaptive     : Reet QP adaptive value to default (normally 1.0). See manual of x265."
echo "  --fps FPS               : Set base framerate to FPS."
echo "  --force-fps             : Force to set framerate before setting."
echo "  --no-force-fps          : Not force to set framerate before setting."
echo "  --detect-vfr            : Detect variable framerate of source with 'vfrdet' filter. See ffmpeg's manual and -help filter=vfrdet."
echo "  --no-detect-vfr         : Not detect variable framerate of source."
echo "  --same-frame-rate       : Encode framerate as same as source (even source has variable framerate)." 
echo "  --auto-frame-rate       : Encode framerate as setting (even source has variable framerate)." 
echo
echo "Around Subtitle:"
echo "  --dump-sub-from-source     : Add subtitle(s) (teletexts) from source movie file."
echo "  --no-dump-sub-from-source  : DON't add subtitle(s) (teletexts) from source movie file."
echo "  --add-subs-if-exists       : Add subtitle(s) (teletexts) from external files."
echo "  --no-add-subs-if-exists    : DON't add subtitle(s) (teletexts) from external files."
echo
echo "Rate controlling:"
echo "  --crf-max VALUE         : Set maximum CRF quant value to VALUE. See manual of x265."
echo "  --crf-min VALUE         : Set minimum CRF quant value to VALUE. See manual of x265."
echo "  --reset-crf-max         : Reset maximum CRF quant value to default."
echo "  --reset-crf-min         : Reset minimum CRF quant value to default."
echo "  --vbv-maxrate VALUE     : Set VBV MAX RATE value to VALUE. See manual of x265."
echo "  --reset-vbv-maxrate     : Reset VBV MAX RATE value to default."
echo ""

}

for x in $@ ; do \

    case "$1" in
        --help | -h )
	  print_help
	  shift
	  exit 0
	  ;;
        --num | -n )
	  shift
	  EPISODE_NUM=$1
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
        --replace-title )
	  shift
	  REPLACE_TITLE=1
	  continue
        ;;
        --no-replace-header | --fixed-header )
	  shift
	  REPLACE_HEADER=0
	  continue
        ;;
        --no-replace-title )
	  shift
	  REPLACE_TITLE=0
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
        --meta-title )
	  shift
	  META_TITLE="$1"
	  shift
	  continue
        ;;
        --no-meta-title | --reset-meta-title )
	  shift
	  META_TITLE=""
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
	--prefetch | --prefetch-bytes | --prefetch-mb )
	  shift
	  PREFETCH_FILE=$1
	  shift
	  continue
	;;
        --frame-threads | --frame_threads )
	  shift
	  FRAME_THREADS=$1
	  shift
	  continue
        ;;
        --pool-threads | --pool_threads )
	  shift
	  POOL_THREADS=$1
	  shift
	  continue
        ;;
        --ffmpeg-threads | --ffmpeg_threads )
	  shift
	  FFMPEG_THREADS=$1
	  shift
	  continue
        ;;
        --filter-threads | --filter_threads | --ffmpeg-filter-threads | --ffmpeg_filter_threads )
	  shift
	  FILTER_THREADS=$1
	  shift
	  continue
        ;;
        --filter-complex-threads | --filter_complex_threads | --complex-threads | --complex_threads | --ffmpeg-filter-complex-threads | --ffmpeg_filter_complex_threads )
	  shift
	  FILTER_COMPLEX_THREADS=$1
	  shift
	  continue
        ;;
	--nice_value | --nice-value )
	  shift
	  NICE_VALUE=$1
	  shift
	  continue
	;;
	--ionice_value | --ionice-value )
	  shift
	  IONICE_VALUE=$1
	  shift
	  continue
	;;
	--nice_class | --nice-class )
	  shift
	  IONICE_CLASS=$1
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
	  FFMPEG_THREADS=$1
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
	--dump-sub-from-source )
	  shift
	  DUMP_SUB_FROM_SOURCE=1
	  continue
	;;
	--add-subs-if-exists )
	  shift
	  ADD_SUB_IF_EXISTS=1
	  continue
	;;
	--no-dump-sub-from-source )
	  shift
	  DUMP_SUB_FROM_SOURCE=0
	  continue
	;;
	--no-add-subs-if-exists )
	  shift
	  ADD_SUB_IF_EXISTS=0
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
    --detect-vfr | --detect-variable-frame-rate )
		shift
		DETECT_VFR=1
		continue
        ;;
    --no-detect-vfr | --no-detect-variable-frame-rate )
		shift
		DETECT_VFR=0
		continue
        ;;
    --same-fps-as-source | --same-frame-rate )
		shift
		PASSTHROUGH_FPS=1
		continue
        ;;
    --auto-fps | --auto-frame-rate )
		shift
		PASSTHROUGH_FPS=0
		continue
        ;;
	* )
        BASEFILE="$1"
	;;
    esac

# ToDo

FILTER_STRING_1="${FILTER_STRING}"

if [ "___x___${BASEFILE}" = "___x___" ] ; then
   exit 0
fi
unset ARG_METADATA[@]
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


ARG_REALTITLE="${ARG_TITLE}"
if [ "__xxx__${ARG_TITLE}" != "__xxx__" ] ; then
   if [ "__xx__${ARG_SUBTITLE}" != "__xx__" ] ; then
       ARG_TITLE="${ARG_TITLE}:${ARG_SUBTITLE}"
   fi
else
   if [ "__xx__${ARG_SUBTITLE}" != "__xx__" ] ; then
       ARG_TITLE="${ARG_SUBTITLE}"
   fi
fi

if [ "__x__${ARG_SUBTITLE}" != "__x__" ] ; then
    ARG_METADATA+=(-metadata:g)
    ARG_METADATA+=(subtitle="${ARG_SUBTITLE}")
fi
if [ "__x__${ARG_REALTITLE}" != "__x__" ] ; then
    ARG_METADATA+=(-metadata:g)
    ARG_METADATA+=(realtitle="${ARG_REALTITLE}")
fi
if [ "__x__${ARG_EPISODE}" != "__x__" ] ; then
    ARG_METADATA+=(-metadata:g)
    ARG_METADATA+=(episode="${ARG_EPISODE}")
fi
if [ "__x__${ARG_SEASON}" != "__x__" ] ; then
    ARG_METADATA+=(-metadata:g)
    ARG_METADATA+=(season="${ARG_SEASON}")
fi
if [ "__x__${ARG_GENRE}" != "__x__" ] ; then
    ARG_METADATA+=(-metadata:g)
    ARG_METADATA+=(genre="${ARG_GENRE}")
fi
if [ "__x__${RECID}" != "__x__" ] ; then
    ARG_METADATA+=(-metadata:g)
    ARG_METADATA+=(recordedid="${RECID}")
fi
if [ "__x__${ARG_CHANID}" != "__x__" ] ; then
    ARG_METADATA+=(-metadata:g)
    ARG_METADATA+=(channel_id="${ARG_CHANID}")
fi
if [ "__x__${ARG_STARTTIME}" != "__x__" ] ; then
    ARG_METADATA+=(-metadata:g)
    ARG_METADATA+=(starttime_utc="${ARG_STARTTIME}")
fi
if [ "__x__${ARG_ENDTIME}" != "__x__" ] ; then
    ARG_METADATA+=(-metadata:g)
    ARG_METADATA+=(endtime_utc="${ARG_ENDTIME}")
fi
fi
else
    # WITHOUT DATABASE
    if [ "___x___${COMMENTS}" != "___x___" ] ; then
        echo "${COMMENTS}" >> $TEMPDIR/desc.txt
        ARG_DESC=$(change_arg_comment "$TEMPDIR/desc.txt")
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
	  if(match(\$0, /^.*Video:.*\\(attached.*\\)\$/) == 0) {
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
    }
"
__AWK_STREAMDESC="
	BEGIN {
	   inum=1;
	   video_count=0;
	   audio_count=0;
	   sub_count=0;
	}
	{
	   ST_NUM=\$2;
	   ST_TYPE=\$3;
	   _ARG_EXTRA[inum]=\$0;
	   if(match(\$0, /^.*Video:.*\\(attached.*\\)\$/) != 0) {
	       _ARG_TYPE[inum] = \"Attachment_PIC\";
	   } else {
	       _ARG_TYPE[inum] = ST_TYPE;
           }
	   N_NUM = split(ST_NUM, __ST_NUM, \":\");
	   STREAM_NUM=\"\";
	   gsub(/#/, \"\", __ST_NUM[1]);
	   gsub(/\\(.*\\)/, \"\", __ST_NUM[2]);
	   gsub(/\\[.*\\]/, \"\", __ST_NUM[2]); #Todo
	   
	   STREAM_NUM=__ST_NUM[1] \":\" __ST_NUM[2];
	   
	   _ARG_STREAM[inum] = STREAM_NUM;
	   inum++;
	   next;
	}
	END {
	   for(i = 1; i <= inum; i++) {
	      if(match(_ARG_TYPE[i], \"Video\") != 0) {
	           printf(\"-map:v %s -c:V:%d %s \", _ARG_STREAM[i], video_count, VENCODER_TYPE);
		   video_count++;
	      } else if(match(_ARG_TYPE[i], \"Audio\") != 0) {
	           if(AUDIO_COPY != 0) {
	                printf(\"-map:a %s -c:a:%d copy \", _ARG_STREAM[i], audio_count);
		   } else {
		        printf(\"-map:a %s -c:a:%d %s %s \", _ARG_STREAM[i],  audio_count, AUDIO_CODEC, AUDIO_ARGS);
		   }
		   audio_count++;
              } else if(match(_ARG_TYPE[i], \"Subtitle\") != 0) {
	           if(match(_ARG_EXTRA[i], \"hdmv_pgs_subtitle\") != 0) {
	               printf(\"-map:s %s -c:s:%d copy \", _ARG_STREAM[i], sub_count);
	           } else if(match(_ARG_EXTRA[i], \"dvd_subtitle\") != 0) {
	               printf(\"-map:s %s -c:s:%d copy \", _ARG_STREAM[i], sub_count);
		   } else if(match(_ARG_EXTRA[i], \"dvb_subtitle\") != 0) {
	               printf(\"-map:s %s -c:s:%d copy \", _ARG_STREAM[i], sub_count);
		   } else {
	               printf(\"-map:s %s -c:s:%d webvtt \", _ARG_STREAM[i], sub_count);
		   }
		   sub_count++;
              } else if(match(_ARG_TYPE[i], \"Attachment_PIC\") != 0) {
	           printf(\"-map:v %s -c:%d copy  \", _ARG_STREAM[i], i - 1);
              } else if(match(_ARG_TYPE[i], \"Attachment\") != 0) {
	           printf(\"-map:t %s -c:t copy  \", _ARG_STREAM[i]);
              }
	   }
	}
	"
declare -a __APPEND_ARGS_SUBTITLES
unset __APPEND_ARGS_SUBTITLES[@]
__APPEND_FILES_SUBTITLES=""

declare -a ARG_SUBTITLES
declare -a ARG_MAPCOPY_SUBS
typeset -i __sb_num
__sb_num=1;

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
BASEFILE3=`echo "${BASEFILE}" | sed -f "${TEMPDIR}/__tmpscript13" `
if [ ${DUMP_SUB_FROM_SOURCE} -ne 0 ] ; then
   $EXECUTE_PREFIX_COMMANDS ${FFMPEG_SUBTXT_CMD} -loglevel info  -aribb24-skip-ruby-text false \
						-fix_sub_duration -i "${BASEFILE}"  \
       -c:s ass -f ass \
       -y "${TEMPDIR}/v1tmp.ass"
   
    if [ -s "${TEMPDIR}/v1tmp.ass" ] ; then
		__tmp_sb="${TEMPDIR}/v1tmp.ass"
		__APPEND_FILES_SUBTITLES="${__APPEND_FILES_SUBTITLES} -i \"${__tmp_sb}\""
		__APPEND_ARGS_SUBTITLES+=(-map:s)
		__APPEND_ARGS_SUBTITLES+=(${__sb_num}:0)
		__APPEND_ARGS_SUBTITLES+=(-c:s)
		__APPEND_ARGS_SUBTITLES+=(subrip)
		__sb_num=__sb_num+1
	fi
fi

for __sb in "ass" "ASS" "smi" "SMI" "srt" "SRT" "ttml" "TTML" "vtt" "VTT" ; do 
    __tmp_sb=""
    ARG_SUBTITLES[$__sb_num]=""
    ARG_MAPCOPY_SUBS[$__sb_num]=""
    if [ -s "${BASEFILE3}.${__sb}" ] ; then
		__tmp_sb="${BASEFILE3}.${__sb}"
		ARG_SUBTITLES[$__sb_num]="${__tmp_sb}"
		ARG_MAPCOPY_SUBS[$__sb_num]="-map:s ${__sb_num}:0 -c:s subrip"
		__APPEND_FILES_SUBTITLES="${__APPEND_FILES_SUBTITLES} -i ${BASEFILE3}.${__sb}"
		__APPEND_ARGS_SUBTITLES+=(-map:s)
		__APPEND_ARGS_SUBTITLES+=(${__sb_num}:0)
		__APPEND_ARGS_SUBTITLES+=(-c:s)
		__APPEND_ARGS_SUBTITLES+=(subrip)
		__sb_num=__sb_num+1
    fi
done
#echo ${ARG_SUBTITLES}
#exit 1

ARG_FPS=""
ARG_STREAM=`echo "${FFPROBE_RESULT}" | grep "Stream"`

__VCODEC_ENCODER=""
VCODEC_TYPE=`echo ${VCODEC_TYPE} | tr "[:lower:]" "[:upper:]"`
__BASE_AV1_ENCODER=`echo ${BASE_AV1_ENCODER} | tr "[:lower:]" "[:upper:]"`

## TRIM BASE AV1 ENCODER -> DEFAULT IS SVT-AV1
case ${__BASE_AV1_ENCODER} in
    "SVTAV1" | "SVT-AV-1" | "SVT-AV1" )
	__BASE_AV1_ENCODER="SVTAV1"
	;;
    "RAV1E" | "R-AV1E" | "R-AV1-E" | "RAV1-E" )
	__BASE_AV1_ENCODER="RAV1E"
	;;
    * )
	__BASE_AV1_ENCODER="SVTAV1"
	;;
esac    
## Convert VCODEC
case ${VCODEC_TYPE} in 
    "HEVC" | "X265" | "H.265" | "H265" )
	VCODEC_TYPE="HEVC"
	;;
    "AV1" | "AV-1" )
	VCODEC_TYPE="${__BASE_AV1_ENCODER}"
	;;
    "SVTAV1" | "SVT-AV-1" | "SVT-AV1" )
	VCODEC_TYPE="SVTAV1"
	;;
    "RAV1E" | "R-AV1E" | "R-AV1-E" | "RAV1-E" )
	VCODEC_TYPE="RAV1E"
	;;
    "HAVC" | "X264" | "H.264" | "H264" )
	VCODEC_TYPE="HAVC"
	;;
    * )
	;;
esac
case "${VCODEC_TYPE}" in
    "HEVC" )
	__VCODEC_ENCODER="libx265"
	;;
    "SVTAV1" )
	__VCODEC_ENCODER="libsvtav1"
	;;
    "RAV1E" )
	__VCODEC_ENCODER="librav1e"
	;;
    "HAVC" )
	__VCODEC_ENCODER="libx264"
	;;
    * )
	__VCODEC_ENCODER="libx265"
	;;
esac	
    
if [ ${COPY_AUDIOS} -ne 0 ] ; then
    ARG_COPYMAP=`echo "${ARG_STREAM}" | gawk -v AUDIO_COPY=1 -v VENCODER_TYPE="${__VCODEC_ENCODER}" "${__AWK_STREAMDESC}"`
else
    ARG_COPYMAP=`echo "${ARG_STREAM}" | gawk -v AUDIO_COPY=0 -v AUDIO_CODEC="${AUDIO_CODEC}" -v AUDIO_ARGS="${AUDIO_ARGS}" -v VENCODER_TYPE="${__VCODEC_ENCODER}"  "${__AWK_STREAMDESC}"`
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
PRESET_ARG=""
AQ_ARG=""
QP_ADAPTATIVE_ARG=""
__VCODEC_PARAMS=""


# To integer value for SVT-AV1 or X264
case "${VCODEC_TYPE}" in
    "HAVC" )
	AQ_VALUE=`numfmt --to=iec ${AQ_VALUE}`
	;;
    * )
	;;
esac

__VCODEC_DISP_PARAMS=""
__CRF_ARGS=""
__CODEC_PARAM_NAME="-x265-params"

__EXECUTE_COMMANDS="${EXECUTE_PREFIX_COMMANDS} ${FFMPEG_CMD}"
case "${__VCODEC_ENCODER}" in
    "libx265" )
	__CODEC_PARAM_NAME="-x265-params"
	__CRF_ARGS="-crf ${CRF_VALUE}"
	if test "__n__${TUNE_VALUE}" != "__n__" ; then
	    TUNE_ARG="-tune ${TUNE_VALUE}"
	fi
	if test "__n__${PRESET_VALUE}" != "__n__" ; then
	    PRESET_ARG="-preset ${PRESET_VALUE}"
	fi
	if test "__n__${AQ_VALUE}" != "__n__" ; then
	    AQ_ARG="aq-strength=${AQ_VALUE}"
	else
	    AQ_ARG="aq-strength=1.0"
	fi
	
	__VCODEC_PARAMS="pools=${POOL_THREADS}:frame_threads=${FRAME_THREADS}"
	__VCODEC_PARAMS="${__VCODEC_PARAMS}:hevc-aq=true"

	case "${AQ_MODE}" in
	    "4" )
		__VCODEC_PARAMS="${__VCODEC_PARAMS}:aq-mode=4:aq-motion=true:${AQ_ARG}"       
		;;
	    "1" | "2" | "3" | "0" )
		__VCODEC_PARAMS="${__VCODEC_PARAMS}:aq-mode=${AQ_MODE}:${AQ_ARG}"
		;;
	    * )
		__VCODEC_PARAMS="${__VCODEC_PARAMS}:aq-mode=3:${AQ_ARG}"
		;;
	esac

	if test "__n__${QP_ADAPTATIVE_VALUE}" != "__n__" ; then
	    __VCODEC_PARAMS="${__VCODEC_PARAMS}:qp-adaptation-range=${QP_ADAPTATIVE_VALUE}"
	fi
	if test "__n__${VBV_VALUE}" != "__n__" ; then
	    __VCODEC_PARAMS="${__VCODEC_PARAMS}:vbv-maxrate=${VBV_VALUE}"
	fi
	#    __VCODEC_PARAMS="${__VCODEC_PARAMS}:pme=true:pmode=true"
	
	if [ "__n__${CRF_MIN}" != "__n__" ] ; then
	    __VCODEC_PARAMS="${__VCODEC_PARAMS}:crf-min=${CRF_MIN}"
	fi
	if [ "__n__${CRF_MAX}" != "__n__" ] ; then
	    __VCODEC_PARAMS="${__VCODEC_PARAMS}:crf-max=${CRF_MAX}"
	fi
	if [ ${USE_HDR10} -ne 0 ] ; then
	    if [ ${USE_10BIT} -ne 0 ] ; then
		__VCODEC_PARAMS="${__VCODEC_PARAMS}:repeat-headers=1"
		__VCODEC_PARAMS="${__VCODEC_PARAMS}:hdr10=true"
		__VCODEC_PARAMS="${__VCODEC_PARAMS}:hdr10-opt=true"
		__VCODEC_PARAMS="${__VCODEC_PARAMS}:level-idc=5.1"
		__VCODEC_PARAMS="${__VCODEC_PARAMS}:colorprim=bt2020"
		__VCODEC_PARAMS="${__VCODEC_PARAMS}:range=limited"
		__VCODEC_PARAMS="${__VCODEC_PARAMS}:transfer=smpte2084"
		__VCODEC_PARAMS="${__VCODEC_PARAMS}:colormatrix=bt2020nc"
		__VCODEC_PARAMS="${__VCODEC_PARAMS}:master-display='G(13250,34500)B(7500,3000)R(34000,16000)WP(15635,16450)L(10000000,1)'"
		__VCODEC_PARAMS="${__VCODEC_PARAMS}:max-cll=1000,293"
		#__VCODEC_PARAMS="${__VCODEC_PARAMS}:max-cll=0,0"
		#COLORSPACE_ARGS+=("-pix_fmt")
		#COLORSPACE_ARGS+=("yuv420p10le")
	    fi
	fi
	__VCODEC_DISP_PARAMS="crf=${CRF_VALUE}"
	if test "__n__${TUNE_VALUE}" != "__n__" ; then
	    __VCODEC_DISP_PARAMS="${__VCODEC_DISP_PARAMS}:tune=${TUNE_VALUE}"
	fi    
	if test "__n__${PRESET_VALUE}" != "__n__" ; then
	    __VCODEC_DISP_PARAMS="${__VCODEC_DISP_PARAMS}:preset=${PRESET_VALUE}"
	fi    
	;;
    "libsvtav1" )
	__CRF_ARGS="-crf ${CRF_VALUE}"
	__CODEC_PARAM_NAME="-svtav1-params"
	if [ ${POOL_THREADS} -gt 0 ] ; then
	    __APPEND_ARGS_PRE+=(-threads:v)
	    __APPEND_ARGS_PRE+=(${POOL_THREADS})
	fi
	if [ "${AQ_MODE}" -lt 0 ] ; then
	    AQ_MODE=0
	elif [ "${AQ_MODE}" -gt 2 ]; then
	    AQ_MODE=2
	fi
	__VCODEC_PARAMS="aq-mode=${AQ_MODE}"
	typeset -i PARALLEL_LEVEL
	if [ ${FRAME_THREADS} -le 0 ] ; then
	    PARALLEL_LEVEL=0
	else
	    PARALLEL_LEVEL=${FRAME_THREADS}
	    if [ ${PARALLEL_LEVEL} -gt 6 ]; then
		PARALLEL_LEVEL=6
	    fi
	fi
	__VCODEC_PARAMS="${__VCODEC_PARAMS}:nb=120:lp=${PARALLEL_LEVEL}:enable-overlays=1"
	if [ "__xxx__${NUMA_NODES}" != "__xxx__" ] ; then
	    if [ -x /bin/taskset ] ; then
		__EXECUTE_COMMANDS="${EXECUTE_PREFIX_COMMANDS} /bin/taskset -c ${NUMA_NODES} ${FFMPEG_CMD} "
	    fi
	#else    
	#    if [ ${POOL_THREADS} -ne 0 ] ; then
	#	if [ -x /bin/cpulimit ] ; then
	#	    __EXECUTE_COMMANDS="${EXECUTE_PREFIX_COMMANDS} /bin/cpulimit -c ${POOL_THREADS} -l `calc -d 'int( (${FRAME_THREADS} / ${POOL_THREADS} ) * 100) + 10'` -f ${FFMPEG_CMD} "
	#	fi
	#    fi
	fi
	# Convert tune value from x265 to svt-av1
	__T_PRESET_VALUE="`echo ${PRESET_VALUE} | tr '[:upper:]' '[:lower:]'`"
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
		_N_PRESET_VALUE=${PRESET_VALUE}
		#_N_PRESET_VALUE=7
		;;
	esac
	PRESET_ARG="-preset ${_N_PRESET_VALUE}"
	
	__GRAIN_VALUE=0
	_T_TUNE_VALUE="`echo ${TUNE_VALUE} | tr '[:lower:]' '[:upper:]'`" 
	case "${_T_TUNE_VALUE}" in
	    "GRAIN" )
		__GRAIN_VALUE=15
		__VCODEC_PARAMS="${__VCODEC_PARAMS}:tune=0:scm=0:scd=0"
		;;
	    "ANIMATION" | "ANIME" )
		__VCODEC_PARAMS="${__VCODEC_PARAMS}:tune=2:scd=1:scm=3"
		;;
	    "ANIMATION_GRAIN" | "ANIME_GRAIN" )
		__GRAIN_VALUE=7
		__VCODEC_PARAMS="${__VCODEC_PARAMS}:tune=2:scd=1:scm=3"
		;;
	    "NOGRAIN" | NO_GRAIN )
		__VCODEC_PARAMS="${__VCODEC_PARAMS}:tune=0:scd=1:scm=2"
		;;
	    "MIDGRAIN" | MID_GRAIN )
		__GRAIN_VALUE=6
		__VCODEC_PARAMS="${__VCODEC_PARAMS}:tune=0:scd=1:scm=2"
		;;
	    * )
		__VCODEC_PARAMS="${__VCODEC_PARAMS}:tune=0:scd=1:scm=0"
		;;
	esac
	__VCODEC_PARAMS="${__VCODEC_PARAMS}:film-grain=${__GRAIN_VALUE}"
	    
	if [ "__n__${CRF_MIN}" != "__n__" ] ; then
	    __VCODEC_PARAMS="${__VCODEC_PARAMS}:crf-min=${CRF_MIN}"
	fi
	if [ "__n__${CRF_MAX}" != "__n__" ] ; then
	    __VCODEC_PARAMS="${__VCODEC_PARAMS}:crf-max=${CRF_MAX}"
	fi
	if [ ${SVTAV1_DISABLE_TEMPORAL_FILTERING} -ne 0 ] ; then
	    __VCODEC_PARAMS="${__VCODEC_PARAMS}:enable-tf=0"
	fi
	if [ "__n__${QP_ADAPTATIVE_VALUE}" != "__n__" ] ; then
	    __VCODEC_PARAMS="${__VCODEC_PARAMS}:ac-bias=${QP_ADAPTATIVE_VALUE}"
	fi
	    
	__VCODEC_DISP_PARAMS="crf=${CRF_VALUE}"
	if test "__n__${_T_TUNE_VALUE}" != "__n__" ; then
	    __VCODEC_DISP_PARAMS="${__VCODEC_DISP_PARAMS}:tune=${_T_TUNE_VALUE}"
	fi    
	__VCODEC_DISP_PARAMS="${__VCODEC_DISP_PARAMS}:preset=${_N_PRESET_VALUE}"
	;;
    "librav1e" )
	## See https://www.free-codecs.com/guides/how_do_i_use_rav1e_and_ffmpeg_to_create_high_quality_videos.htm .
	_I_CRF_VALUE=`calc -d "int( ${CRF_VALUE} * 4)"`
	if [ ${_I_CRF_VALUE} -lt 0 ] ; then
	    _I_CRF_VALUE=0;
	elif [ ${_I_CRF_VALUE} -gt 255 ] ; then
	    _I_CRF_VALUE=255
	fi
	__CRF_ARGS="-qp ${_I_CRF_VALUE}"
	
	__T_PRESET_VALUE="`echo ${PRESET_VALUE} | tr '[:upper:]' '[:lower:]'`"
	_N_PRESET_VALUE=0
	case "${__T_PRESET_VALUE}" in
	    "ultrafast" )
		_N_PRESET_VALUE=10
		;;
	    "superfast" )
		_N_PRESET_VALUE=9
		;;
	    "veryfast" )
		_N_PRESET_VALUE=8
		;;
	    "faster" )
		_N_PRESET_VALUE=7
		;;
	    "fast" )
		_N_PRESET_VALUE=6
		;;
	    "medium" )
		_N_PRESET_VALUE=5
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
		_N_PRESET_VALUE=${PRESET_VALUE}
		#_N_PRESET_VALUE=7
		;;
	esac
	PRESET_ARG="-speed ${_N_PRESET_VALUE}"
	
	__CODEC_PARAM_NAME="-rav1e-params"
	#if [ ${FRAME_THREADS} -gt 0 ] ; then
	#    __APPEND_ARGS_PRE+=(-threads:v)
	#    __APPEND_ARGS_PRE+=(${FRAME_THREADS})
	#fi
	__VCODEC_PARAMS="threads=${FRAME_THREADS}"
	__GRAIN_VALUE=0
	_T_TUNE_VALUE="`echo ${TUNE_VALUE} | tr '[:lower:]' '[:upper:]'`" 
	case "${_T_TUNE_VALUE}" in
	    "GRAIN" )
		__GRAIN_VALUE=20
		__VCODEC_PARAMS="${__VCODEC_PARAMS}:psnr=Psychovisual"
		;;
	    "ANIMATION" | "ANIME" )
		__VCODEC_PARAMS="${__VCODEC_PARAMS}:tune=Psnr"
		;;
	    "ANIMATION_GRAIN" | "ANIME_GRAIN" )
		__GRAIN_VALUE=10
		__VCODEC_PARAMS="${__VCODEC_PARAMS}:tune=Psnr"
		;;
	    "NOGRAIN" | NO_GRAIN )
		__VCODEC_PARAMS="${__VCODEC_PARAMS}:psnr=Psychovisual"
		;;
	    "MIDGRAIN" | MID_GRAIN )
		__GRAIN_VALUE=10
		__VCODEC_PARAMS="${__VCODEC_PARAMS}:psnr=Psychovisual"
		;;
	    * )
		__VCODEC_PARAMS="${__VCODEC_PARAMS}:tune=Psychovisual"
		;;
	esac
	TUNE_ARG="-tile-rows 64 -tile-columns 64"
	if [ ${__GRAIN_VALUE} -gt 0 ] ; then
	    __VCODEC_PARAMS="${__VCODEC_PARAMS}:photon_noise=${__GRAIN_VALUE}"
	fi
	if [ "__n__${CRF_MIN}" != "__n__" ] ; then
	    _N_MIN_QUANT=`calc -d "int( ${CRF_MIN} * 4 )"`
	    if [ ${_N_MIN_QUANT} -ge ${_I_CRF_VALUE} ] ; then
		_N_MIN_QUANT=`calc -d "${_I_CRF_VALUE} - 1"`
	    fi
	    if [ ${_N_MIN_QUANT} -ge 0 ] ; then 
		__VCODEC_PARAMS="${__VCODEC_PARAMS}:min-quantizer=${_I_CRF_VALUE}"
	    fi
	fi
	## CRF_MAX has not implemented.
	;;
    * )
	;;
esac


__START_DATE=`date -Iseconds`

BASEFILE3=`echo "${BASEFILE}" | sed -f "${TEMPDIR}/__tmpscript13" `
EPSTR=""
TMP_BASE1=""
TMP_BASE2=""

EP_DESC=""
EP_SUBTTL=""
EP_DATE=""
EP_EPNUM=""
if [ -e "$EPISODES_LIST_FILE" ] ; then
	EP_DESC=`cat "$EPISODES_LIST_FILE" | gawk -v _TYPE=description -v __EPNUM=${EPISODE_NUM} "${__AWK_EPLIST_GETDEFINES}"`
	EP_SUBTTL=`cat "$EPISODES_LIST_FILE" | gawk -v _TYPE=title -v __EPNUM=${EPISODE_NUM} "${__AWK_EPLIST_GETDEFINES}"`
	EP_DATE=`cat "$EPISODES_LIST_FILE" | gawk -v _TYPE=date -v __EPNUM=${EPISODE_NUM} "${__AWK_EPLIST_GETDEFINES}"`
	EP_EPNUM=`cat "$EPISODES_LIST_FILE" | gawk -v _TYPE=episode_num -v __EPNUM=${EPISODE_NUM} "${__AWK_EPLIST_GETDEFINES}"`
#	EP_DATA=`cat "$EPISODES_LIST_FILE"`
#	echo "${EP_DATA}"
#	echo "${EP_EPNUM}"
	echo "${EP_SUBTTL}"
#	echo "${EP_DATE}"
fi


if [ "__x__${HEAD_TITLE}" = "__x__" ] ; then
    EPSTR=""
    if [ "__x__${APPEND_HEADER}" = "__x__NUMERIC" ] ; then
        EPSTR=`printf "%02d" ${EPISODE_NUM}`
	TMP_BASE1="${HEAD_TITLE} #${EPSTR} " 
    else
	TMP_BASE1="${HEAD_TITLE}"
    fi
else
   EPSTR=`printf "%02d" ${EPISODE_NUM}`
   TMP_BASE1="${HEAD_TITLE} #${EPSTR} "   
   TMP_BASE2="${HEAD_TITLE}"   
fi

if [ "__x__${META_TITLE}" != "__x__" ] ; then
    EPSTR=""
	if [ "__x__${APPEND_HEADER}" = "__x__NUMERIC" ] ; then
		EPSTR=`printf "%02d" ${EPISODE_NUM}`
		ARG_TITLE="${META_TITLE} #${EPSTR}"
	else
		ARG_TITLE="${META_TITLE}"
	fi
fi    
if [ "__x__${ARG_TITLE}" = "__x__" ] ; then
    if [ "__x__${TMP_BASE2}" != "__x__" ] ; then
         ARG_TITLE='`echo -e "${TMP_BASE2}"`'
    fi	
fi


if [ "__x__${EP_SUBTTL}" != "__x__" ] ; then
	ARG_TITLE="${ARG_TITLE} 「${EP_SUBTTL}」"
fi

if [ ${REPLACE_TITLE} -ne 0 ] ; then
    typeset -i ARG_META_TITLE_LINES
    ARG_META_TITLE=`echo "${FFPROBE_RESULT}" | grep -e "title[[:space:]]\+:[[:space:]]"`
    ARG_META_TITLE_LINES=`echo "${ARG_META_TITLE}" | wc -l`
    #echo "${ARG_META_TITLE_LINES}"
    #exit 1

    if [ ${ARG_META_TITLE_LINES} -gt 0 ] ; then 
        __TMPS=`echo "${ARG_META_TITLE}" | sed -E "s/[[:space:]]+title.*:[[:space:]]+//g"`
	if [ "__xx__${ARG_TITLE}" != "__xx__" ] ; then
	    ARG_TITLE="${__TMPS} (${ARG_TITLE})"
	else
	    ARG_TITLE="${__TMPS}"
	fi
    fi
    if [ "__x__${ARG_TITLE}" = "__x__" ] ; then
    ARG_TITLE=" "
    fi
fi


typeset -i ARG_META_TITLE_COMMENTS
ARG_META_COMMENT=`echo "${FFPROBE_RESULT}" | grep -e "comment[[:space:]]\+:[[:space:]]"`
ARG_META_COMMENT_LINES=`echo "${ARG_META_COMMENT}" | wc -l`


if [ ${ARG_META_COMMENT_LINES} -gt 0 ] ; then 
   __TMPS=`echo "${ARG_META_COMMENT}" | sed -E "s/[[:space:]]+comment.*:[[:space:]]+//g"`
   # Workaround for comment contains white space. 20241211 K.O
   if [ "__xxx__${__TMPS}" != "__xxx__" ] ; then
       __TMPS2=`echo "${__TMPS}" | sed -e "s/[[:space:]]/　/g"`
       ARG_METADATA+=(-metadata:g)
       ARG_METADATA+=(source-comment="${__TMPS2}")
   fi
fi
   


if [ "__x__${ARG_DESC}" = "__x__" ] ; then
   ARG_DESC=" "
fi

if [ "__x__${ARG_DESC}" != "__x__" ] ; then
	ARG_DESC=`echo -e "${ARG_DESC}"`
fi

declare -a ARGS_COMMENT_FINAL
unset ARGS_COMMENT_FINAL[@]

#echo "${ARG_DESC}"
#exit 1

if [ "__x__${ARG_DESC}" != "__x__ " ] ; then
    echo "${ARG_DESC}" > "$TEMPDIR/desc3.txt"
fi
if [ "__x__${EP_DESC}" != "__x__" ] ; then
    
    echo " ${EP_DESC}" >> "$TEMPDIR/episodes.txt"
    EP_DESC_2=`cat $TEMPDIR/episodes.txt`
    EP_DESC_2=$(change_arg_comment "$TEMPDIR/episodes.txt")
    echo "${EP_DESC_2}" >> "$TEMPDIR/desc3.txt"
fi

#if [ -s "$TEMPDIR/desc3.txt" ] ; then
#   ARGS_COMMENT_FINAL+=(-metadata:g)
#   #__TMPS2=`cat "$TEMPDIR/desc3.txt" | sed -e "s/[[:space:]]/　/g"`
#   __TMPS2=$(change_arg_comment "$TEMPDIR/desc3.txt")
#   ARGS_COMMENT_FINAL+=(description="${__TMPS2}")
#fi
#if [ "__x__${ARG_DESC}" != "__x__ " ] ; then
#    echo "${ARG_DESC}" > $TEMPDIR/desc2.txt
#    ARG_DESC="-metadata:g DESCRIPTION=\"`cat $TEMPDIR/desc2.txt`\""
#fi
#if [ "__x__${ARG_DESC}" != "__x__ " ] ; then
#    ARG_DESC="-metadata:g DESCRIPTION=\"${ARG_DESC}\""
#fi

if [ ${REPLACE_HEADER} -ne 0 ] ; then
	if [ "__x__${EP_SUBTTL}" != "__x__" ] ; then
		BASEFILE3="${TMP_BASE1}「${EP_SUBTTL}」"
	else
		BASEFILE3="${TMP_BASE1}"
	fi
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
	 if [ "__x__${EP_SUBTTL}" != "__x__" ] ; then
		 BASEFILE3="${BASEFILE3}「${EP_SUBTTL}」"
	 fi
fi

if [ ${PASSTHROUGH_FPS} -ne 0 ] ; then
    FORCE_FPS=0
    DETECT_VFR=0
fi

if [ ${FORCE_FPS} -eq 0 ] ; then
    if [ ${DETECT_VFR} -eq 0 ] ; then 
	FPS_VAL="-fps_mode:V:0 passthrough -copyts"
	MUXER_OPTIONS+=(-enc_time_base:V:0)
	MUXER_OPTIONS+=(demux)
        ARG_METADATA+=(-metadata:s:V:0) 
        ARG_METADATA+=(framerate_type=passthrough)
        ARG_METADATA+=(-metadata:s:V:0) 
        ARG_METADATA+=(enc_time_base=demux)
    else 
        if [ "__x__" != "__x__${FILTER_STRING_1}" ] ; then
	    FILTER_STRING_1="${FILTER_STRING_1},vfrdet"
        else
	    FILTER_STRING_1="vfrdet"
        fi
        FPS_VAL="-fps_mode vfr"
	ARG_METADATA+=(-metadata:s:V:0) 
	ARG_METADATA+=(framerate_type=vfr)
	#MUXER_OPTIONS+=(-enc_time_base:V:0)
	#MUXER_OPTIONS+=(filter)
    fi
else
    if [ "__x__${ARG_FPS}" != "__n__" ] ; then
	FPS_VAL="-r ${ARG_FPS}"
	ARG_METADATA+=(-metadata:s:V:0) 
	ARG_METADATA+=(framerate_type=fixed,"${ARG_FPS}") 
    else
	FPS_VAL="-r ${BASE_FPS}"
	ARG_METADATA+=(-metadata:s:V:0)
	ARG_METADATA+=(framerate_type=fixed,"${BASE_FPS}")
    fi
fi


APPEND_ARGS_INPUT=""
APPEND_ARGS_MAPS=""
#APPEND_ARGS_INPUT=$( for __xx in "${ARG_SUBTITLES[@]}" ; do if [ "__xx__${__xx}" != "__xx__" ] ; then echo "-i \"${__xx}\"" ; fi ; done )
#echo ${BASEFILE3}
#exit 1

case "${__VCODEC_ENCODER}" in
    "libsvtav1" | "librav1e" )
	if [ ${USE_10BIT} -ne 0 ] ; then
	    if [ ${USE_HDR10} -ne 0 ] ; then
		FILTER_FORMAT="colorspace=all=bt2020:range=pc:trc=bt2020-10:format=yuv420p10le"
	    else
		FILTER_FORMAT="format=yuv420p10le"
	    fi
	else
	    FILTER_FORMAT="format=yuv420ple"
	fi
	PROFILE_ARG=""
	;;
    * )
	if [ ${USE_10BIT} -ne 0 ] ; then
	    if [ ${USE_HDR10} -ne 0 ] ; then
		FILTER_FORMAT="colorspace=all=bt2020:range=pc:trc=bt2020-10:format=yuv420p10"
	    else
		FILTER_FORMAT="format=yuv420p10le"
	    fi
	    PROFILE_ARG="-profile:V:0 main10"
	else
	    FILTER_FORMAT="format=yuv420p"
	    PROFILE_ARG="-profile:V:0 main"
	fi
	;;
esac

if [ "__xx__" != "__xx__${FILTER_STRING_1}" ] ; then
   FILTER_ARG="${FILTER_STRING_1},${FILTER_FORMAT}"
else
   FILTER_ARG="${FILTER_FORMAT}"
fi

BASEFILE4=`echo "${BASEFILE}" | sed 's/\ /　/g'`
#echo ${BASEFILE}
echo ${BASEFILE4}
#exit 1
ARG_METADATA+=(-metadata:g)
ARG_METADATA+=(source="${BASEFILE4}")
ARG_METADATA+=(-metadata:s:V:0)
ARG_METADATA+=(source="${BASEFILE4}")
ARG_METADATA+=(-metadata:s:a)
ARG_METADATA+=(source="${BASEFILE4}")

#echo ${ARG_METADATA[@]}
#exit 0

__VCODEC_PARAMS_PRE=""
__VCODEC_PARAMS_POST=""
for xx in "${APPEND_VCODEC_PARAMETERS_PRE[@]}" ; do
    if [ "__xx__${xx}" != "__xx__" ] ; then
         if [ "__xx__${__VCODEC_PARAMS_PRE}" != "__xx__" ] ; then
	     __VCODEC_PARAMS_PRE="${__VCODEC_PARAMS_PRE}:"
	 fi
	 __VCODEC_PARAMS_PRE="${__VCODEC_PARAMS_PRE}${xx}"
    fi
done
for xx in "${APPEND_VCODEC_PARAMETERS_POST[@]}" ; do
    if [ "__xx__${xx}" != "__xx__" ] ; then
         if [ "__xx__${__VCODEC_PARAMS_POST}" != "__xx__" ] ; then
	     __VCODEC_PARAMS_POST="${__VCODEC_PARAMS_POST}:"
	 fi
	 __VCODEC_PARAMS_POST="${__VCODEC_PARAMS_POST}${xx}"
    fi
done

if [ "__xx__${__VCODEC_PARAMS_PRE}" != "__xx__" ] ; then
    __VCODEC_PARAMS="${__VCODEC_PARAMS_PRE}:${__VCODEC_PARAMS}"
fi
if [ "__xx__${__VCODEC_PARAMS_POST}" != "__xx__" ] ; then
    __VCODEC_PARAMS="${__VCODEC_PARAMS}:${__VCODEC_PARAMS_POST}"
fi


if [ "__xx__" != "__xx__${FILTER_ARG}" ] ; then
    ARG_METADATA+=(-metadata:s:V:0)
    ARG_METADATA+=(filter_params="${FILTER_ARG}")
fi
if [ "__xx__" != "__xx__${__VCODEC_PARAMS}" ] ; then
    ARG_METADATA+=(-metadata:s:V:0)
    ARG_METADATA+=(vcodec_params="${__VCODEC_PARAMS}")
fi
if [ "__xx__" != "__xx__${__VCODEC_DISP_PARAMS}" ] ; then
    ARG_METADATA+=(-metadata:s:V:0)
    ARG_METADATA+=(vcodec_params_any="${__VCODEC_DISP_PARAMS}")
fi
#echo "${BASEFILE}" \


declare -a PREFETCH_ARGS
unset PREFETCH_ARGS[@]

__PREFETCH_TMPS=""
if [ ${PREFETCH_FILE} -gt 0 ] ; then
    __PREFETCH_TMPS=`calc -d "${PREFETCH_FILE} * 1024 * 1024"`
elif [ ${PREFETCH_FILE} -lt 0 ] ; then 
    __PREFETCH_TMPS="-1"
fi
if [ "__xxx__${__PREFETCH_TMPS}" != "__xxx__" ] ; then
    PREFETCH_ARGS+=(-read_ahead_limit)
    PREFETCH_ARGS+=("${__PREFETCH_TMPS}")
fi

declare -a __APPEND_ARGS_PRE
unset __APPEND_ARGS_PRE[@]
__EPISODE_NUM_FOR_APPENDED_ARGS=__EPISODE_ALL

for _xx in "${FFMPEG_APPEND_ARGS_PRE[@]}" ; do
   case "${_xx}" in
     __EPISODE_ALL | __EPISODE_[0-9]+ )
        __EPISODE_NUM_FOR_APPENDED_ARGS=${_xx}
	continue
	;;
     * )
        ;;
   esac
   __TMP_NUM=`printf "%03d" ${EPISODE_NUM}`
   case "${__EPISODE_NUM_FOR_APPENDED_ARGS}" in
       __EPISODE_ALL )
          __APPEND_ARGS_PRE+=(${_xx})
	  ;;
       __EPISODE_[0-9]+ )
         if [ __x__"${__EPISODE_NUM_FOR_APPENDED_ARGS}" = __x__"__EPISODE_"${__TMP_NUM} ] ; then
          __APPEND_ARGS_PRE+=(${_xx})
         fi
	 ;;
       * )
         ;;
   esac
#    fi
done


declare -a __APPEND_ARGS_POST
unset __APPEND_ARGS_POST[@]
__EPISODE_NUM_FOR_APPENDED_ARGS="__EPISODE_ALL"

for _xx in "${FFMPEG_APPEND_ARGS_POST[@]}" ; do
   case "${_xx}" in
     __EPISODE_ALL | __EPISODE_[0-9]+ )
        __EPISODE_NUM_FOR_APPENDED_ARGS=${_xx}
	continue
	;;
     * )
        ;;
   esac
   __TMP_NUM=`printf "%03d" ${EPISODE_NUM}`
   case "${__EPISODE_NUM_FOR_APPENDED_ARGS}" in
       __EPISODE_ALL )
          __APPEND_ARGS_POST+=(${_xx})
	  ;;
       __EPISODE_[0-9]+ )
         if [ __x__"${__EPISODE_NUM_FOR_APPENDED_ARGS}" = __x__"__EPISODE_"${__TMP_NUM} ] ; then
          __APPEND_ARGS_POST+=(${_xx})
         fi
	 ;;
       * )
         ;;
   esac
#    fi
done

#echo \
#echo ${ARG_METADATA[@]}
#echo
#echo ${ARG_COPYMAP}
#echo
#echo 		 ${__APPEND_ARGS_POST[@]}
#echo		 -map_metadata:g 0
#echo		 -map_chapters 0
#echo		 -metadata:g title=${ARG_TITLE}
#cat $TEMPDIR/desc3.txt
#echo		 ${MUXER_OPTIONS[@]}


#exit 1
#echo "${BASEFILE}"
#echo ${__APPEND_FILES_SUBTITLES}
#shift
#continue

declare -a __ARGS_TMP_TITLE
unset __ARGS_TMP_TITLE[@]

if [ "__xxx__${ARG_TITLE}" != "__xxx__" ] ; then 
    __ARGS_TMP_TITLE+=(-metadata:g)
    echo -e "${ARG_TITLE}" > ${TEMPDIR}/title2.txt
    __TMPS=$(change_arg_file "${TEMPDIR}/title2.txt")
    __ARGS_TMP_TITLE+=(title="${__TMPS}")
fi

declare -a __ARGS_TMP_DESC
unset __ARGS_TMP_DESC[@]

#if [ -e $TEMPDIR/desc3.txt ] ; then
#    __ARGS_TMP_DESC+=(-metadata:g)
#    __ARGS_TMP_DESC+=(description="`cat $TEMPDIR/desc3.txt`")
#fi

#echo ${__ARGS_TMP_TITLE[@]}
#exit 1

#echo \
${__EXECUTE_COMMANDS}  -fix_sub_duration -i "${BASEFILE}" \
		 ${__APPEND_FILES_SUBTITLES} \
		 ${__APPEND_ARGS_PRE[@]} \
		 ${ARG_COPYMAP} \
		 ${__APPEND_ARGS_SUBTITLES[@]} \
		 ${PREFETCH_ARGS[@]} \
		 -threads ${FFMPEG_THREADS} \
		 -filter_complex_threads ${FILTER_COMPLEX_THREADS} \
		 -filter_threads ${FILTER_THREADS} \
		 -map_chapters 0 \
		 ${COLORSPACE_ARGS[@]} \
		 ${PROFILE_ARG} \
		 ${FPS_VAL} \
		 -filter:V:0 "${FILTER_ARG}" \
		 ${__CRF_ARGS}  \
		 ${PRESET_ARG}  \
		 ${TUNE_ARG} \
		 ${__CODEC_PARAM_NAME} "${__VCODEC_PARAMS}" \
		 ${__APPEND_ARGS_POST[@]} \
		 -map_metadata:g 0 \
		 -map_chapters 0 \
		 ${__ARGS_TMP_TITLE[@]} \
		 ${__ARGS_TMP_DESC[@]} \
		 ${ARG_METADATA[@]} \
		 ${MUXER_OPTIONS[@]} \
		 -metadata:g DESCRIPTION="`cat $TEMPDIR/desc3.txt`" \
		 -y "re-enc/${BASEFILE3}(Re-Enc ${VCODEC_TYPE} CRF=${CRF_VALUE}).mkv" 
#
#echo "${ARG_DESC_FINAL}"
#
#exit 1
EPISODE_NUM=EPISODE_NUM+1

shift
done
