#!/bin/bash
# https://github.com/jirutka/luasrcdiet

set -e

for source_file in src/*.lua; do
  output_file="dist/GrimGuesser/${source_file##*/}"
  luasrcdiet "$source_file" -o "$output_file" --none --opt-comments --opt-emptylines --opt-srcequiv --opt-binequiv
done
