#!/bin/bash
SRC="$1"
DST="$2"

if [ -e mythtv-reload-metadatas.txt ]; then
   . $PWD/mythtv-reload-metadatas.txt
else
    exit 0
fi

if [ "___xxx___${DST}" = "___xxx___" ] ; then
    DST="$PWD/out.mkv"
fi

if [ "___xxx___${COMMENTS}" != "___xxx___" ] ; then
    ffmpeg -i "${SRC}" \
            -c:a copy -c:v copy -c:s copy \
            -map_metadata:g 0 -map_chapters:g 0 \
	    -metadata:g DESCRIPTION="${COMMENTS}" \
	    -y "${DST}"
fi