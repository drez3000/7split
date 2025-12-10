# 7split

![Run Shellcheck](https://github.com/drez3000/7split/actions/workflows/shellcheck.yml/badge.svg)
![Build Podman Image](https://github.com/drez3000/7split/actions/workflows/build-podman-image.yml/badge.svg)

Convert .mp4 video frames into a .png sprite sheet. Optionally remove green screen backgrounds.

Based on [ffmpeg](https://ffmpeg.org/) and [imagemagick](https://imagemagick.org/).

## Options:
```
Usage: 7split.sh <input.mp4> <output.png> [OPTIONS]"

Options:
  -h, --help                  Display this help message.
  --fps, --sample-fps         Video sampling rate.
  --msf, --sample-ms-from     Sample video from ms timestamp, defaults to 0.
  --mst, --sample-ms-to       Sample video until ms timestamp, defaults to end of the video.
  --gsh, --greenscreen-hex    Remove greenscreen. If unset, greenscreen removal is disabled.
  --gsf, --greenscreen-fuzz   Greenscreen removal threshold. Defaults to "20%".
```

## Run in a container:

```
./7split-podman.sh <input.mp4> <output.png> --greenscreen-hex="#00FF00"
```

## Run locally:

Ensure you have `bash`, `ffmpeg`, and `imagemagick`.
See Containerfile for pinned dependency versions.
```
./7split.sh <input.mp4> <output.png>
```
