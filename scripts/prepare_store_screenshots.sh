#!/bin/zsh

set -euo pipefail

if [[ $# -ne 2 ]]; then
  print -u2 "Usage: prepare_store_screenshots.sh INPUT_DIR OUTPUT_DIR"
  exit 64
fi

input_dir=$1
output_dir=$2
mkdir -p "$output_dir"

setopt null_glob
screenshots=("$input_dir"/*.png)
if (( ${#screenshots} == 0 )); then
  print -u2 "No PNG screenshots found in $input_dir"
  exit 66
fi

work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT

for source in "${screenshots[@]}"; do
  filename=${source:t}
  flattened_jpeg="$work_dir/${filename:r}.jpg"
  output="$output_dir/$filename"

  # Simulator PNGs retain an alpha channel. JPEG conversion composites that channel against
  # white; converting back to PNG gives App Store Connect a standard opaque RGB screenshot.
  sips -s format jpeg -s formatOptions best "$source" --out "$flattened_jpeg" >/dev/null
  sips -s format png "$flattened_jpeg" --out "$output" >/dev/null
  print "Prepared $filename"
done
