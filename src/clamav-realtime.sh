#!/bin/bash
# Real-Time Monitoring Script
WATCH_DIR="/home"
LOGFILE="/var/log/clamav/realtime.log"
QUARANTINE="/var/quarantine"

mkdir -p "$QUARANTINE"

inotifywait -mr \
  -e create \
  -e modify \
  -e moved_to \
  --format '%w%f' \
  "$WATCH_DIR" |
while read FILE
do
  # Skip if it's not a regular file
  [ -f "$FILE" ] || continue
  echo "Scanning: $FILE"
  
  RESULT=$(clamdscan \
    --fdpass \
    --move="$QUARANTINE" \
    --log="$LOGFILE" \
    "$FILE")
  echo "$RESULT"
  
  if echo "$RESULT" | grep -q "FOUND"
  then
    notify-send "⚠ Malware Detected" "Infected file quarantined"
    logger "ClamAV: Malware detected in $FILE"
  fi
done
