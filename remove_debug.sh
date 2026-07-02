#!/bin/bash

read -p "Enter lowest visible log level (trace, debug, info, warn, error): " log_level

if [ -z "$log_level" ]; then
  echo "No log level entered. Exiting."
  exit 1
fi

case "$log_level" in
  error)
    echo "Removing logs error level and below..."
    sed -i '' '/printh("error: /d' spoopy_golf.p8 > golf.p8
    ;&
  warn)
    echo "Removing logs warn level and below..."
    sed -i '' '/printh("warn: /d' spoopy_golf.p8 > golf.p8
    ;&
  info)
    echo "Removing logs info level and below..."
    sed -i '' '/printh("info: /d' spoopy_golf.p8 > golf.p8
    ;&
  debug)
    echo "Removing logs debug level and below..."
    sed -i '' '/printh("debug: /d' spoopy_golf.p8 > golf.p8
    ;&
  trace)
    echo "Removing logs trace level and below..."
    sed -i '' '/printh("trace: /d' spoopy_golf.p8 > golf.p8
    ;;
  *)
    echo "Invalid log level entered. Exiting."
    exit 1
    ;;
esac

echo "Log cleanup complete. Output written to golf.p8"