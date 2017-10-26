#!/bin/bash
# A simple script to convert all files in a given folder from EAC3 to AC3

####################################################
# Basic Command Syntax
####################################################
#
#   FFMPEG Convert EAC3 to AC3 as seperate file
#   ffmpeg -drc_scale 0 -i "INPUT MKV" -vn -acodec ac3 -center_mixlev 0.707 -ab 640k "OUTPUT.AC3"
#
#   MKVMERRGE Remove EAC3 track and merge in new AC3 file
#   
#
####################################################
# Edit these variables as required (do not work yet)
####################################################

# Default values
PRIORITY=0
COMP="none"
NOEAC3=1
NOCOLOR=0

container="mkv"         # Choose output container (mkv; mp4 only)
aoutputcodec="ac3"      # Choose audio output type (ac3 only for now)
asamplerate="640k"      # Choose audio sample rate (default 640k)
cmixlev="0.707"         # Center channel mix level

####################################################
# You can set filetypes to parse here (remember to not use the same types as your container above)
####################################################

filetypes=("*.mkv")

####################################################
# Don't change anything beyond this point!
####################################################

# Disable case sensativity
shopt -s nocaseglob

# Set variables to ""
  vcodec=""
  acodec=""
  vconvert=""
  aconvert=""
  i=""

# Make some adjustments based on the version of mkvtoolnix
MKVTOOLNIXVERSION=$(mkvmerge -V | cut -d " " -f 2 | sed s/\[\^0-9\]//g)
if [ ${MKVTOOLNIXVERSION} -lt 670 ]; then
  AUDIOTRACKPREFIX="audio (A_"
  VIDEOTRACKPREFIX="video (V_"
else
  AUDIOTRACKPREFIX="audio ("
  VIDEOTRACKPREFIX="video ("
fi

# Search file type
#for INFILE in ${filetypes[*]}; do
INFILE=$1

  echo $INFILE

  #Root path
  DIR=$(dirname "$INFILE")
  echo $DIR

  # File name without the extension
  NAME=$(basename "$INFILE" .mkv)
  echo $NAME

  # Setup temporary files
  AC3FILE="/config/$NAME.ac3"
  NEWFILE="/config/${NAME}_AC3.mkv"

  RAW_INFO=$(mkvmerge -i "${INFILE}")

  # Figure out what we have...
  # Use mkvmerge -i to get track id of first AC-3/E-AC-3 audio track
  TRACK=$(mkvmerge -i "${INFILE}" | grep -m 1 "${AUDIOTRACKPREFIX}AC3/EAC3)" | cut -d ":" -f 1 | cut -d " " -f 3)

  echo "AUDIOTRACK_ID=${TRACK}"

  TOTALTRACKS=$(($(mkvmerge -i "${INFILE}" | wc -l)-1))

  # Check to make sure we have a possible track
  if [ -z $TRACK ]; then
      echo "There are no AC3/EAC3 tracks in '${INFILE}'."
      #exit 1
  fi

  # Get track information from mkvinfo and make sure it's EAC3
  INFO=$(mkvinfo "${INFILE}")
  FIRSTLINE=$(echo "$INFO" | grep -n -m 1 "mkvextract: $TRACK" | cut -d ":" -f 1)
  INFO=$(echo "$INFO" | tail -n +$FIRSTLINE)
  LASTLINE=$(echo "$INFO" | grep -n -m 1 "mkvextract: $(($TRACK+1))" | cut -d ":" -f 1)
  if [ -z "$LASTLINE" ]; then
    LASTLINE=$(echo "$INFO" | grep -m 1 -n "|+" | cut -d ":" -f 1)
  fi
  if [ -z "$LASTLINE" ]; then
    LASTLINE=$(echo "$INFO" | wc -l)
  fi
  INFO=$(echo "$INFO" | head -n $(($LASTLINE-1)))

  # echo "INFO=${INFO}"

  # Get codec type
  CODEC=$(echo "$INFO" | grep -m 1 "Codec ID" | cut -d " " -f 6)

  echo "CODEC=${CODEC}"

  # if codec is "A_EAC3" continue, otherwise we are done...
  if [ $CODEC = "A_EAC3" ]; then
    # work it
    echo "Generating AC3 audio file...."
    nice -n $PRIORITY ffmpeg -drc_scale 0 -i "${INFILE}" -vn -acodec $aoutputcodec -center_mixlev $cmixlev -ab $asamplerate "$AC3FILE" &> /dev/null

    # Get language so we can name it correctly during merge
    LANG=$(echo "$INFO" | grep -m 1 "Language" | cut -d " " -f 5)
    if [ -z "$LANG" ]; then
      LANG=$"eng"
    fi

    echo "LANG=${LANG}"

    # Setup to do the merge

    # Start to "build" command
    CMD="nice -n $PRIORITY mkvmerge -o \"$NEWFILE\" -A"

    # Get track ID of video track
    #VIDEOTRACK=$(mkvmerge -i "${INFILE}" | grep -m 1 "$VIDEOTRACKPREFIX" | cut -d ":" -f 1 | cut -d " " -f 3)
    VIDEOTRACK=$(echo "$RAW_INFO" | grep -m 1 "${VIDEOTRACKPREFIX}" | cut -d ":" -f 1 | cut -d " " -f 3)
    # Add original MKV file, set header compression scheme
    CMD_VID="--compression $VIDEOTRACK:$COMP \"$INFILE\""

    # If the language was set for the original EAC3 track set it for the AC3
    if [ $LANG ]; then
      CMD_LANG="--language 0:$LANG"
    fi

    # Set track compression scheme and append new AC3
    CMD_AUDIO="--compression 0:$COMP \"$AC3FILE\""

    echo "Muxing files back together...."
    #echo "CMD=${CMD}"
    #eval $CMD &> /dev/null
    nice -n $PRIORITY mkvmerge -o "${NEWFILE}" -A "${CMD_VID}" "${CMD_LANG}" "${CMD_AUDIO}" &> /dev/null

    echo "Removing temporary AC3 file...."
    rm -f "$AC3FILE"

    # Fix permissions for unraid
    chown nobody:users "$NEWFILE"

    echo "Replacing Original file..."
    mv "$NEWFILE" "${INFILE}"

  else
    echo "Codec is already AC3, nothing to do..."
  fi

#done
echo "Conversion of ${NAME} complete."

shopt -u nocaseglob
