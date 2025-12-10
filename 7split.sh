#!/bin/bash
set -euo pipefail

APPNAME=$(basename "$0" | sed "s/\.sh$//")

# realpath polyfill
if [[ 0 == $(which realpath >/dev/null 2>&1 && echo 1 || echo 0) ]]; then
	realpath() {
		OURPWD=$(pwd)
		cd "$(dirname "$1")"
		LINK=$(readlink "$(basename "$1")")
		while [ "$LINK" ]; do
			cd "$(dirname "$LINK")"
			LINK=$(readlink "$(basename "$1")")
		done
		REALPATH="$PWD/$(basename "$1")"
		cd "$OURPWD"
		echo "$REALPATH"
	}
fi

#
# Whatever we do, we do it in a self destructing temp directory
#
# fallback for undefined TMPDIR
START_DIR="$(pwd)"
TMPDIR=${TMPDIR:-"/tmp"}
if [[ -z "$TMPDIR" || ! -d "$TMPDIR" ]]; then
	TMPDIR="/tmp"
fi
_TMPDIR="$(mktemp -d)"
cleanup() {
	trap - EXIT
	if [[ -d "$START_DIR" ]]; then cd "$START_DIR" >/dev/null; fi
	if [[ -d "$_TMPDIR" && "$_TMPDIR" == "$TMPDIR/"* ]]; then rm -r "$_TMPDIR" >/dev/null; fi
}
trap cleanup EXIT
cd "$_TMPDIR"

fn_log_info()  { echo "$APPNAME: $1"; }

fn_log_warn()  { echo "$APPNAME: [WARNING] $1" 1>&2; }

fn_log_error() { echo "$APPNAME: [ERROR] $1" 1>&2; }

fn_display_usage() {
	echo "Usage: $(basename "$0") <input.mp4> <output.png> [OPTIONS]"
	echo ""
	echo "Options"
	echo "-h, --help                  Display this help message."
	echo "--fps, --sample-fps         Video sampling rate."
	echo "--msf, --sample-ms-from     Sample video from ms timestamp, defaults to 0."
	echo "--mst, --sample-ms-to       Sample video until ms timestamp, defaults to end of the video."
	echo "--gsh, --greenscreen-hex    Remove greenscreen. If unset, greenscreen removal is disabled."
	echo "--gsf, --greenscreen-fuzz   Greenscreen removal threshold. Defaults to \"20%\"."
	echo ""
	echo "For more detailed help, please see the README file:"
	echo ""
	echo "https://github.com/drez3000/7split/blob/master/README.md"
}

#
# Parameters
#

FFMPEG_SAMPLE_FPS=60
FFMPEG_SAMPLE_FROM_MS=0
FFMPEG_SAMPLE_TO_MS=
GREENSCREEN_HEX="#00FF00"
GREENSCREEN_FUZZ="20%"
INPUT_PATH=
OUTPUT_PATH=

while [[ $# -gt 0 ]]; do
	case "$1" in
		-h|-\?|--help)
			fn_display_usage
			exit 0
			;;
		--fps=*|--sample-fps=*)
			FFMPEG_SAMPLE_FPS="${1#*=}"
			shift
			;;
		--msf=*|--sample-ms-from=*)
			FFMPEG_SAMPLE_FROM_MS="${1#*=}"
			shift
			;;
		--mst=*|--sample-ms-to=*)
			FFMPEG_SAMPLE_TO_MS="${1#*=}"
			shift
			;;
		--gsh=*|--greenscreen-hex=*)
			GREENSCREEN_HEX="${1#*=}"
			shift
			;;
		--gsf=*|--greenscreen-fuzz=*)
			GREENSCREEN_FUZZ="${1#*=}"
			shift
			;;
		--)
			shift
			INPUT_PATH="$(realpath "$1")"
			OUTPUT_PATH="$(realpath "$2")"
			break
			;;
		-*)
			fn_log_error "Unknown option: \"$1\""
			fn_log_info ""
			fn_display_usage
			exit 1
			;;
		*)
			if [[ -z "$INPUT_PATH" ]]; then
				INPUT_PATH="$(realpath "$1")"
			elif [[ -z "$OUTPUT_PATH" ]]; then
				OUTPUT_PATH="$(realpath "$1")"
			else
				fn_log_error "Too many positional arguments."
				fn_log_info ""
				fn_display_usage
				exit 1
			fi
			shift
			;;
	esac
done

#
# Fail on missing input
#

if [[ -z "$INPUT_PATH" || -z "$OUTPUT_PATH" ]]; then
	fn_log_error "Missing required arguments."
	fn_log_info ""
	fn_display_usage
	exit 1
fi

if [[ ! -f "$INPUT_PATH" ]]; then
	fn_log_error "Input path doesn't exist, or it's not a file."
	fn_log_info ""
	fn_display_usage
	exit 1
fi

#
# Functions
#

_fn_norm_abs_path () {
	echo "$1/" | sed -E 's/(\/)+/\//g'
}

_fn_a_contains_b() {
	local a="$1"
	local b="$2"
	a="$(_fn_norm_abs_path "$(realpath "$a")")"
	b="$(_fn_norm_abs_path "$(realpath "$b")")"
	if [[ "$b" = "$a"* && "$a" != "$b" ]]; then
		return 0
	else
		return 1
	fi
}

_fn_process_mp4() {

	local filename
	local name
	local outdir
	local outdir_green
	local outdir_alpha

	filename="$(basename "$INPUT_PATH")"
	name="${filename%.*}"
	outdir="$(printf '%s/%s' "$_TMPDIR" "$filename")"
	outdir_green="$(printf '%s/green' "$outdir")"
	outdir_alpha="$(printf '%s/alpha' "$outdir")"

	mkdir -p "$outdir_green"
	mkdir -p "$outdir_alpha"

	# split the input $filepath in .png frames (saves to $outdir_green)
	if [[ -n "$FFMPEG_SAMPLE_TO_MS" ]]; then
		ffmpeg -hide_banner -loglevel error \
			-ss "$FFMPEG_SAMPLE_FROM_MS" -to "$FFMPEG_SAMPLE_TO_MS" \
			-i "$INPUT_PATH" \
			-vf "fps=$FFMPEG_SAMPLE_FPS" \
			"$outdir_green/%08d.png"
	else
		ffmpeg -hide_banner -loglevel error \
			-ss "$FFMPEG_SAMPLE_FROM_MS" \
			-i "$INPUT_PATH" \
			-vf "fps=$FFMPEG_SAMPLE_FPS" \
			"$outdir_green/%08d.png"
	fi
	
	# remove the greenscreen (from $outdir_green to $outdir_alpha)
	for f in "$outdir_green"/*.png; do
		if [[ -n "$GREENSCREEN_HEX" ]]; then
			convert "$f" -fuzz "$GREENSCREEN_FUZZ" -transparent "$GREENSCREEN_HEX" \
				"$outdir_alpha/$(basename "$f")"
		else
			mv "$f" "$outdir_alpha/$(basename "$f")"
		fi
	done

	# assemble all frames into a single sprite sheet
	local rows
	local cols
	local count
	local w
	local h
	count=$(find "$outdir_alpha" -type f -name '*.png' | wc -l)
	set -- "$outdir_alpha"/*.png
	w=$(identify -format "%w" "$1")
	h=$(identify -format "%h" "$1")
	cols=$(printf "%.0f" "$(awk -v c="$count" 'BEGIN{print sqrt(c)}')")
	if (( cols < 1 )); then cols=1; fi
	rows=$(( (count + cols - 1) / cols ))
	# montage expects a writable XDG_CACHE_HOME
	# containers may not have one
	if [[ -z "${XDG_CACHE_HOME:-}" ]]; then
		export XDG_CACHE_HOME="$_TMPDIR/cache"
		mkdir -p "$XDG_CACHE_HOME/fontconfig"
	fi
	# `montage` fails on startup if no fonts are found, even if we don't actually use any.
	# For this reason 7split container installs "liberation sans" to let montage startup.
	# If the font exists, the if block below tells montage to use it wether we're in a container or not.
	if [[ -e /usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf ]]; then
		FC_NO_CACHE=1 montage "$outdir_alpha"/*.png \
			-label "" \
			-font /usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf \
			-tile "${cols}x${rows}" \
			-geometry "${w}x${h}+0+0" \
			-define annotate:font=none \
			-background none \
			-alpha on \
			"$outdir/$name.png"
	else
		FC_NO_CACHE=1 montage "$outdir_alpha"/*.png \
			-label "" \
			-tile "${cols}x${rows}" \
			-geometry "${w}x${h}+0+0" \
			-define annotate:font=none \
			-background none \
			-alpha on \
			"$outdir/$name.png"
	fi

	# annotate output png metadata
	mogrify \
		-set sprite:cell_width  "$w" \
		-set sprite:cell_height "$h" \
		-set sprite:rows        "$rows" \
		-set sprite:cols        "$cols" \
		"$outdir/$name.png"
	
	# move output to the output path
	mv "$outdir/$name.png" "$OUTPUT_PATH"
}

#
# Main
#

main() {
	case "$INPUT_PATH" in
		*.mp4) _fn_process_mp4 ;;
		*) _fn_log_error "Invalid input format. Expected .mp4"; exit 1 ;;
	esac
}
main
