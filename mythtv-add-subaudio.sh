#!/bin/bash

BASEFILE=$1
TARGETFILE=$2

FFMPEG_CMD="/usr/bin/ffmpeg"
FAAC_CMD="/usr/bin/faac"
SOX_CMD="/usr/bin/sox"
#TSSPLITTER_EXE="$HOME/bin/TsSplitter.exe"
TSSPLITTER_EXE="$HOME/bin/TsSplitter.exe"

if [ -e /etc/mythtv/mythtv-add-subaudio ]; then
   . /etc/mythtv/mythtv-add-subaudio
fi
if [ -e $HOME/.mythtv-add-subaudio ]; then
   . $HOME/.mythtv-add-subaudio
fi
if [ -e "$PWD/mythtv-add-subaudio.txt" ]; then
   . "$PWD/mythtv-add-subaudio.txt"
fi

if [ "___x___${BASEFILE}" = "___x___" ] ; then
   exit 0
fi

TEMPDIR=`mktemp -d`

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

BASE_BASE=`echo "${BASEFILE}" | sed -f "${TEMPDIR}/__tmpscript13" `
#echo ${BASE_BASE}

wine "${TSSPLITTER_EXE}" -SEP3 "${BASEFILE}"

find -name ${BASE_BASE}_HD.\* -print > "${TEMPDIR}/__tslist"
find -name ${BASE_BASE}_HD-[0-9].\* -print | sort -n >> "${TEMPDIR}/__tslist"
find -name ${BASE_BASE}_HD-[1-9][0-9].\* -print | sort -n >> "${TEMPDIR}/__tslist"

__TSLIST=`cat "${TEMPDIR}/__tslist"`
__BASELIST=`cat "${TEMPDIR}/__tslist" | sed -f "${TEMPDIR}/__tmpscript13" `

__WAVLIST=""

__AWK_AUDIODESC="
	BEGIN {
	   inum=1;
	}
	{
	   ST_NUM=\$2;
	   ST_TYPE=\$3;
	   
	   _ARG_TYPE[inum] = ST_TYPE;
	   N_NUM = split(ST_NUM, __ST_NUM, \":\");
	   STREAM_NUM=\"\";
	   __ST_ID=__ST_NUM[2];
	   
	   gsub(/#/, \"\", __ST_NUM[1]);
	   gsub(/\\(.*\\)/, \"\", __ST_NUM[2]);
	   gsub(/\\[.*\\]/, \"\", __ST_NUM[2]); #Todo

	   gsub(/\\[.*/, \"\", __ST_ID); #Todo
	   //gsub(/\\].*/, \"\", __ST_ID); #Todo

	   STREAM_NUM=__ST_NUM[1] \":\" __ST_NUM[2];
	   
	   _ARG_STREAM[inum] = STREAM_NUM;
	   _ARG_AID[inum] = __ST_ID;
	   inum++;
	   next;
	}
	END {
	   for(i = 1; i <= inum; i++) {
	      
	      if(match(_ARG_TYPE[i], \"Audio\") != 0) {
	         if(_ARG_AID[i] >= 2) {
	                printf(\"-map:a %s  \", _ARG_STREAM[i]);
	         }
	       }
	   }
	}
	"

typeset -i __xnum
typeset -i __slcount

__xnum=1;
__slcount=0;

for i in ${__TSLIST} ; do
   if [ -e "${i}" ] ; then
      FFPROBE_RESULT=`ffprobe -i "${i}" 2>&1`
      ARG_STREAM=`echo "${FFPROBE_RESULT}" | grep "Stream"`
      ARG_MAP="-map:a 0:1" 
      ARG_MAP2=`echo "${ARG_STREAM}" | gawk "${__AWK_AUDIODESC}"`
      if [ "___x___${ARG_MAP2}" != "___x___" ] ; then
         ARG_MAP="${ARG_MAP2}"
      fi
      WAVNAME=`echo "${i}" | sed -f "${TEMPDIR}/__tmpscript13" `
      WAVNAME="${TEMPDIR}/${WAVNAME}.wav"
      
      if [ $__xnum -eq 1 ] ; then
         ARG_MAP="-ss 00:00:15 ${ARG_MAP}"
      fi
      ${FFMPEG_CMD} -i "${i}" ${ARG_MAP} -ac 2 -ar 48000 -af aresample=async=1:min_hard_comp=0.100000:first_pts=0 -y "${WAVNAME}"
      if [ -e "${WAVNAME}" ] ; then
         __WAVLIST="${__WAVLIST} ${WAVNAME}"
	 __slcount=1
      fi
  fi
  __xnum=__xnum+1
done

if [ $__slcount -eq 0 ] ; then
   echo "No sub audios"
   exit 1
fi

${SOX_CMD} ${__WAVLIST} "${TEMPDIR}/tmp.wav"

if [ -e "${TEMPDIR}/tmp.wav" ] ; then
   ${FAAC_CMD} -w -b 192 --overwrite "${TEMPDIR}/tmp.wav"
   if [ -e "${TEMPDIR}/tmp.m4a" ] ; then
      ${FFMPEG_CMD} -i "${TARGETFILE}" \
                    -i "${TEMPDIR}/tmp.m4a" \
                    -map:v 0:0 \
                    -map:a 0:1 \
                    -map:a 1:0 \
                    -map:s 0:2 \
		    -map_metadata:g 0 \
		    -map_chapters 0 \
		    -c:v copy \
		    -c:a copy \
		    -c:s copy \
		    -disposition:a:0 default \
		    -y "${BASE_BASE}_TMP.mkv"
		   
	__RESULT=$?
	if [ $__RESULT -ne 0 ] ; then
	   echo "Error on muxing video and audios"
	   exit 4
	fi
   else
     echo "Error on encoding sub-audio to AAC"
     exit 2
   fi
else
   echo "Error on merging sub-audio"
   exit 3
fi

echo "${BASE_BASE}_TMP.mkv"

exit 0
		    