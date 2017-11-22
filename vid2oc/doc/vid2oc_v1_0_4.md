#vid2oc (1.0.4)

##Licence
**vid2oc (1.0.4)**  
Copyright 2012-2017 Graz University of Technology – "Educational Technology" https://elearning.tugraz.at  

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.  
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.
You should have received a copy of the GNU General Public License
along with this program. If not, see <http://www.gnu.org/licenses/>.

##Description  
This program is a [Perl](https://www.perl.org/)-script which helps automate the pre-processing of media files before their ingestion in [Opencast](http://www.opencast.org/). A typical use is the preparation of video recordings from [Epiphan](https://www.epiphan.com/) recorders ([Pearl](https://www.epiphan.com/products/pearl/) or [LRx2](https://www.epiphan.com/products/lecture-recorder-x2/)). It can also be used as a general-purpose media processing tool.
It utilises the online audio processing service [Auphonic](https://auphonic.com/) by default.  

**NOTE:**  
Developed and tested on UNIX systems.  
###Dependencies  
* [Perl](https://www.perl.org/)
* [ffmpeg](https://ffmpeg.org/)

###Additional Dependencies (for external audio processing)
* [Auphonic](auphonic.com)
* [cURL](https://curl.haxx.se/)

####About Auphonic
**Auphonic** is an automatic audio post production web service. In order to be used with **vid2oc**, an account must be set on auphonic.com. Credentials and production preset UUIDs are required. The production preset(s) on auphonic.com must be set to produce one ".m4a" audio file output. For more information on how to create a custom preset, see Auphonic's [documentation](https://auphonic.com/help/web/index.html).  
**Privacy note:** Care has been taken to ensure that files sent to Auphonic contain no sensitive information in the file name (e.g.: a lecturer's name). However, please note that metadata are copied from the source file to the file sent to Auphonic. These may potentially contain sensitive information (e.g: a recording device's serial number).

##What's New
####v. 1.0.4
– adaptation after auphonic.com API change (check file size function; optimised command by omitting "grep" and using only "awk")
##Usage
	~ perl vid2oc.pl -i <input-file> [-o <output-base-name> -f <output-file-format> -vmode <video-mode> -vfscr <custom-screen-video-filters> -vfcam <custom-camera-video-filters> -vf <custom-single-video-filters> -pix_fmt <custom-pixel-format> -nopho -ss <start-time> -to <end-time> -au <auphonic-credentials> -ap <auphonic-preset-uuid> -aq <auphonic-quality>]

**vid2oc** features several options. The input-file option is mandatory whereas all others are optional (if not explicitly set, the default values will be used). As shown above, all options can be set directly in the command line. Some user-specific options (e.g.: credentials) can be entered in the configuration file: `./config/config.ini`

###Options

* **-o _output\_base\_name_**  
The output file base name (if omitted, the input file base name will be used).  
**Note:** It is advisable that only alphanumeric characters and the underscore character `_` be used.

* **-f _output\_file\_format_**  
The output file container type. Possible values are as follows:   
	* **'mov'**  
	* **'mp4'**


* **-vmode _mode_**  
The processing mode. There are several variants:
	* **0, 'copy'** passes the input video to the output as a single stream; no encoding (copy stream) (default option)
	* **1, 'single'** passes the input video to the output as a single stream
	* **2, 'double'** crops input video in two separate videos (screen/camera)
	* **3, 'screen'** extracts the screen part of a double input video (cam is discarded)
	* **4, 'camera'** extracts the camera part of a double input video (screen is discarded)
	* **5, 'audio'** discards all video input and generates a new video with a visual representation of the spectrum of the input audio and a custom background (useful mainly for audio-only input)
* **-vfscr _ffmpeg\_parameters_**  
Video filter parameters for the screen part (in `-vmode 2` or `3`; ffmpeg `-vf` syntax).
* **-vfcam _ffmpeg\_parameters_**  
Video filter parameters for the camera part (in `-vmode 2` or `4`; ffmpeg `-vf` syntax).
* **-vf _ffmpeg\_parameters_**  
Video filter parameters in single mode video processing (in `-vmode 1`; ffmpeg syntax).  
​Additionally, the shortcut `-vf r/2` can be used to scale the output video down to the half of the input's resolution.  
​**Note:** Mind that the input resolution must be divisible by 2.
* **-pix_fmt _custom\_pixel\_format_**  
The output video's pixel format (ffmpeg syntax).
* **-ss _start\_time_**  
The position (timestamp) in the input file on which to start processing (thus discarding all that precedes; ffmpeg syntax).
* **-to _end\_time_**  
The position (timestamp) in the input file on which to end processing (thus discarding all that follows; ffmpeg syntax).
* **-au _auphonic\_credentials_**  
The username and password to the Auphonic account (cURL `-u` syntax).
* **-ap _auphonic\_preset\_UUID_**  
The Auphonic production preset UUID to be used.
* **-ap _auphonic\_quality_**  
Selects predefined[^auph] Auphonic production preset based on quality.
* **-nopho**  
Omission of Auphonic processing.


##Examples

* The following will discard the first 35 seconds as well as the content after 4785 seconds of the input file. Additionally, it will reduce the input's resolution to half:  
	
		perl vid2oc.pl -i LV_file_1920x1080.mov -vmode 1 -vf r/2 -ss 35 -to 4785


* The following will scale the input video to a standard format (720p) and will omit Auphonic processing:  
	
		perl vid2oc.pl -i LV_file_1920x1091.mov -vmode 1  -vf scale=1280:720 -nopho


[^auph]: Auphonic production preset UUID's for standard and high quality can be entered in the configuration file: `./config/config.ini`