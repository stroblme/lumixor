# Lumixor

This project attempts to fill the gap of a simple VJ controller that runs smoothly on small systems (i.e. Raspberry Pi) and covers basic features such as
- video playback
- slideshow of images
- blackout and crossfade functionality
- multi screen with preview in control window

## Usage

On startup, the program shows the main tab. Here you can add media either by selecting individual files or complete folders.
The selected images or videos are then sorted into separate tabs from where you can start the playback of slideshows or videos respectively.
Each tab has an alpha slider, controlling the transparency of the media.
You can add more media (slideshows/ videos) by clicking on the "+" at the right hand side of the tab bar.
Note that the media is rendered in the order of the tabs from left to right (i.e. the rightmost tab will be rendered on top of the others).
You can get a preview in the right panel, where you can also find a blackout slider that allows you to darken the output in the second window.

## Disclaimer

As my skills in the C++/QT-QML Language are quite limited, I heavily relied on LLM-assistance when creating this project.
Altough I'm trying to keep things as clean and structured as possible, expect some LLM typical artifacts of code generation. 