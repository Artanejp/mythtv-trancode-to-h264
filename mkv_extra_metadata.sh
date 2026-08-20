#!/bin/bash


FFMPEG=ffmpeg
GAWK=gawk

CLTIME=150

TEMP_DIR=`mktemp -d`

IN_VIDEO="$1"
IN_METALIST="$2"
shift
shift

declare -a ARG_INPUT_PP
unset ARG_INPUT_PP[@]

# Queue size to 10MPackets.
ARG_INPUT_PP+=(-thread_queue_size)
ARG_INPUT_PP+=(10485760)

declare -a MUXER_OPTIONS
unset MUXER_OPTIONS[@]
## Around Muxing queue
# Max packets queue is 256k packets. 
MUXER_OPTIONS+=(-max_muxing_queue_size)
MUXER_OPTIONS+=(262144)
# 100bytes
MUXER_OPTIONS+=(-muxing_queue_data_threshold:t)
MUXER_OPTIONS+=(100)

# Audio data muxing threshold to 64kbytes 
MUXER_OPTIONS+=(-muxing_queue_data_threshold:a)
MUXER_OPTIONS+=(65536)
# Video data muxing threshold to 10Mbytes
MUXER_OPTIONS+=(-muxing_queue_data_threshold:v)
MUXER_OPTIONS+=(10485760)


## for MKV
# Reserve index space to 1MB.
MUXER_OPTIONS+=(-reserve_index_space)
MUXER_OPTIONS+=(1048576)

MUXER_OPTIONS+=(-cues_to_front)
MUXER_OPTIONS+=(true)
MUXER_OPTIONS+=(-allow_raw_vfw)
MUXER_OPTIONS+=(true)


declare -a ARG_METADATA
unset ARG_METADATA[@]

declare -a ARG_JSON
unset ARG_JSON[@]

declare -a ARG_JSON_POST
unset ARG_JSON_POST[@]

#if [ -e "$1" ] ; then
#   ARG_JSON+=(-attach)
#   ARG_JSON+=("$1")
#   shift
#fi


cat <<EOF > ${TEMP_DIR}/__tmpscript.awk
#!/bin/gawk

BEGIN {
    indexs[0] = "";
    values[0] = "";
    index_count = 0;
    _is_index = 0;
    descs = "";
    first_title = 0;
}

/^[A-Za-z0-9]+:\$/ {
    _tstr = \$0;
    sub(":", "", _tstr);
    #print _tstr;
    if(_is_index == 0) {
	/* INDEX */
	index_count++;
	_is_index = 1;
	indexs[index_count] = _tstr;
	if(first_title == 0) {
	    if(match("TITLE", _tstr)) {
	        next;
	    }
	}
        descs = descs \$0 "\\n";
	next;
    }
}

{
    _tstr = \$0;
    /*print _tstr; */
    if(_is_index != 0) {
        /* VALUE */
	values[index_count] = _tstr;
	_is_index = 0;
	if(first_title == 0) {
	    if(match("TITLE", indexs[index_count])) {
	        first_title = 1;
		next;
	    }
	}
    }
    descs = descs _tstr "\n";
}
END {
   # print "INDEXES:"; 
   
   #_icount = 0;
   # for(x in indexs) {
   #     printf "-metadata:g %s=\"%s\" ", indexs[x], values[x];
   # }
   # printf " -metadata:g DESCRIPTION=\"%s\"" , descs;
  if(match(PINDEX, "DESCRIPTION")) {
      printf "%s" , descs;
  } else {
      for(x in indexs) {
          if(indexs[x] != "") {
              if(match(PINDEX, indexs[x])) {
	          _tstr = values[x];
	          sub(/^[[:space:]]+/, "", _tstr);
                  printf "%s", _tstr;
              }
	  }
      }
  }
}

EOF


declare -a ARG_METADATA
unset ARG_METADATA[@]

function check_and_add_metadata() {
   if [ __xx__"$1" != __xx__ ] ; then
       if [ __xx__"$2" != __xx__ ] ; then
           _tstr=`cat "$1" | ${GAWK} -v PINDEX="$2" -f ${TEMP_DIR}/__tmpscript.awk`
	   if [ __xx__"${_tstr}" != __xx__ ] ; then
	       ARG_METADATA+=(-metadata:g)
	       ARG_METADATA+=("$2=${_tstr}")
	       #echo "${_tstr}"
	   fi
       fi
   fi
}

check_and_add_metadata "${IN_METALIST}" TITLE
check_and_add_metadata "${IN_METALIST}" URL
check_and_add_metadata "${IN_METALIST}" TAGS
check_and_add_metadata "${IN_METALIST}" NOTE

check_and_add_metadata "${IN_METALIST}" AUTHOR
check_and_add_metadata "${IN_METALIST}" PUBLISHER
check_and_add_metadata "${IN_METALIST}" PERFORMER
check_and_add_metadata "${IN_METALIST}" BRAND

check_and_add_metadata "${IN_METALIST}" ACTOR
check_and_add_metadata "${IN_METALIST}" ACTRESS
check_and_add_metadata "${IN_METALIST}" AGE
check_and_add_metadata "${IN_METALIST}" SERIES

check_and_add_metadata "${IN_METALIST}" DATE
check_and_add_metadata "${IN_METALIST}" YEAR

check_and_add_metadata "${IN_METALIST}" DESCRIPTION

#echo ${ARG_METADATA[@]}

#exit



${FFMPEG} \
          ${ARG_INPUT_PP[@]} \
          -i "${IN_VIDEO}" \
          "${ARG_JSON[@]}" \
          -c copy  \
	  -map_metadata:g 0 \
	  -map_chapters 0 \
	  "${ARG_METADATA[@]}" \
	  -cluster_time_limit ${CLTIME} \
	  ${MUXER_OPTIONS[@]} \
	  $@ \
	  -y tmp.mkv
