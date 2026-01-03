# Lumixor

This project attempts to fill the gap of a simple VJ controller that runs smoothly on small systems (i.e. Raspberry Pi) and covers basic features such as
- video playback
- slideshow of images
- blackout and crossfade functionality
- multi screen with preview in control window

## Installation

At the moment, there are no pre-build binaries available.
You can easily build the application yourself by
1. Installing the required dependencies
```
./install-build-dependencies.sh
```
2. Building the application
```
./build.sh
```
3. The output is then in `./build/lumixor-qt`

## Usage

On startup, two windows will open. One is the so called "Output Window", the other is the "Control Window".
In the control window, the program shows the main tab. Here you can add media either by selecting individual files or complete folders.
The selected images or videos are then sorted into separate tabs from where you can start the playback of slideshows or videos respectively.
Each tab has an alpha slider, controlling the transparency of the media.
You can add more media (slideshows/ videos) by clicking on the "+" at the right hand side of the tab bar.
Note that the media is rendered in the order of the tabs from left to right (i.e. the rightmost tab will be rendered on top of the others).
You can get a preview in the right panel, where you can also find a blackout slider that allows you to darken the output in the second window.

## Known Bugs and Limitations

- no webm support
- ui scaling doesn't work
- layout is not responsive
- no support for OS != Linux atm.

## Roadmap (prioritized)

1. MIDI & OSC control + learn mode; hotcues & cue lists.
2. Shader effects, blending modes, per-layer transforms.
3. Audio analysis (beat detection / FFT) and audio-reactive parameters.
4. Timeline/cue automation + snapshot save/load.
5. Projection mapping tools and multi-output layout editor.
6. Better video backend (GStreamer/FFmpeg) & NDI / virtual output.

## Disclaimer

As my skills in the C++/QT-QML Language are quite limited, I heavily relied on LLM-assistance when creating this project.
Altough I'm trying to keep things as clean and structured as possible, expect some LLM typical artifacts of code generation. 