#!/bin/bash

declare -a MOVIE_EXTS
unset MOVIE_EXTS[@]

MOVIE_EXTS+=("mp4")
MOVIE_EXTS+=("avi")
MOVIE_EXTS+=("mkv")
MOVIE_EXTS+=("wmv")
MOVIE_EXTS+=("flv")

SCRIPT=/usr/local/bin/mythtv-reload-metadatas.sh
NICE_PROG="/bin/nice"
TARGET_DIR=""
if [ -e $HOME/.config/reenc-staging-prefixs ]; then
    . $HOME/.config/reenc-staging-prefixs
fi

if [ -e $PWD/reenc-staging-prefixs ]; then
    . $PWD/reenc-staging-prefixs
fi

declare -a SCRIPT_ARGS
unset SCRIPT_ARGS[@]

declare -a MOVIE_DIRS
unset MOVIE_DIRS[@]

NICE_VAL=""
PHASE="MOVIES"

for x in "$@"; do
   case "$1" in 
       --arg | --ARG | --args | --ARGS )
         PHASE="ARGS"
	 ;;
       --movie | --MOVIE | --movies | --MOVIES | -- )
         PHASE="MOVIES"
	 ;;
       -j | --threads | --thread )
         shift
	 SCRIPT_ARGS+=("--threads")
	 SCRIPT_ARGS+=("$1")
	 ;;
       -f | --frame-threads | --frame-thread )
         shift
	 SCRIPT_ARGS+=("--frame-threads")
	 SCRIPT_ARGS+=("$1")
	 ;;
       -p | --pool-threads | --pool-thread )
         shift
	 SCRIPT_ARGS+=("--pool-threads")
	 SCRIPT_ARGS+=("$1")
	 ;;
       --prefetch | --prefetch-bytes )
         shift
	 SCRIPT_ARGS+=("--prefetch-bytes")
	 SCRIPT_ARGS+=("$1")
	 ;;
       -n | --nice | --nice-val )
         shift
	 NICE_VAL="$1"
	 ;;

       * )
         if [ "__x__"${PHASE} = "__x__MOVIES" ] ; then
	      MOVIE_DIRS+=("$1")
	 else
	      SCRIPT_ARGS+=("$1")
	 fi
	 ;;
    esac
    shift
done

if [ -x "${NICE_PROG}" ] ; then
   if [ "__xx__"${NICE_VAL} != "__xx__" ] ; then
       EXEC_PROG="${NICE_PROG} -n ${NICE_VAL} ${SCRIPT}"
   else
       EXEC_PROG="${SCRIPT}"
   fi
fi

declare -a XLIST
X_PWD="${PWD}"
for xx in ${MOVIE_DIRS[@]} ; do 
   if [ "__xx__"${TARGET_DIR} != "__xx__" ] ; then
      cd "${X_PWD}/${TARGET_DIR}/${xx}"
   else
      cd "${X_PWD}/${xx}"
   fi
   #echo "${xx}"  "${SCRIPT_ARGS[@]}"
   unset XLIST[@]
   for yy in ${MOVIE_EXTS[@]} ; do
       __TMPS=""
       __TMPS=`find . -maxdepth 1 -iname \*.${yy} -print`
       if [ __xxx__"${__TMPS}" != ___xxx___ ] ; then
          XLIST+=("${__TMPS}")
       fi
   done
   #echo ${XLIST[@]}
   ${EXEC_PROG} ${SCRIPT_ARGS[@]} ${XLIST[@]}
   cd "${X_PWD}"
done