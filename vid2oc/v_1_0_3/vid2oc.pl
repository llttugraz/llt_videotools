#!/usr/bin/perl
use strict;
use warnings;
#use diagnostics;

# This program's main use is to automate the pre-processing of video/audio recordings (of arbitrary format) before their ingestion in Opencast[1]. It can also be used as a general-purpose video processing tool.
# It utilises the online audio processing service Auphonic[2] by default; account credentials and production preset UUIDs are required.
# NOTE: the production preset on auphonic.com must be set to produce one ".m4a" audio file output. For more information on how to create a custom preset see the Auphonic documentation[3].
#
# Developed for UNIX systems.
# Dependencies:
# 	– ffmpeg (https://ffmpeg.org/)
#	– cURL (https://curl.haxx.se/) (only if Auphonic processing is activated)
#	– Auphonic account with presets (auphonic.com) (only if Auphonic processing is activated)
#
# Usage: ~ perl vid2oc.pl -i <input-file> [-o <output-base-name> -f <output-file-format> -vmode <video-mode> -vfscr <custom-screen-video-filters> -vfcam <custom-camera-video-filters> -vf <custom-single-video-filters> -pix_fmt <custom-pixel-format> -nopho -ss <cutin-time> -to <cutout-time> -au <auphonic-credentials> -ap <auphonic-preset-uuid> -aq <auphonic-quality>]
#
# [1] http://www.opencast.org/
# [2] https://auphonic.com/
# [3] https://auphonic.com/help/web/index.html
#
#
# vid2oc (v.1.0.3)
# Copyright 2012-2017 Graz University of Technology – "Educational Technology" https://elearning.tugraz.at
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.


{ # MAIN
	$| = 1;
	
	# initialise and/or define main variables
	my $usage = '~ perl vid2oc.pl -i <input-file> [-o <output-base-name> -f <output-file-format> -vmode <video-mode> -vfscr <custom-screen-video-filters> -vfcam <custom-camera-video-filters> -vf <custom-single-video-filters> -pix_fmt <custom-pixel-format> -nopho -ss <cut-in time> -to <cut-out time> -au <auphonic-credentials> -ap <auphonic-preset-uuid> -aq <auphonic-quality-preset>]';
	my $input_file;
	my $out_base_name;
	my $out_SCR_name;
	my $out_CAM_name;
	my $out_vmode5_name;
	my $out_name;
	my $auphonic_name_pre;
	my $auphonic_base_name;
	my $suffix; # set output container type in the config file
	my $ff_command;
	my $vmode = 0;
	my $vfSCR; # crop-filter setting (ffmpeg) for the extraction of the screen part from a double video (two videos on one canvas)
	my $vfCAM; # crop-filter setting (ffmpeg) for the extraction of the camera part from a double video (two videos on one canvas)
	my $vf = '';
	my $pix_fmt; # the pixel format of the output video file(s) (ffmpeg); it can be set in the config file
	my $option_nopho = 0;
	my $option_ff_ss = '';
	my $option_ff_to = '';
	my $tmp_FINAL_name = '';
	my $out_FINAL_name = '';
	my $auph_cred; # enter your auphonic.com credentials in the config file (form: "<username>:<password>")
	my $auph_preset; # the aphonic preset UUID which will be used
	my $auph_preset_sq;
	my $auph_preset_hq;
	my $auph_quality;
	my $curl_output = '';
	my $auph_edit_page = '';
	my $auph_prod_uuid = '';
	my $auph_dl_url_base = 'https://auphonic.com/api/download/audio-result/';
	my $auph_dl_url = '';
	my $tmp_dir;
	my $config_file = './config/config.ini'; # the config file path (relative to the wherabouts of the main script)
	my $spectrumBG_file;
	my $vmode5_lavfi_input; # the lavfi-format input (ffmpeg) from which the audio spectrum will be generated (in -vmode 5)
	my $vmode5_filter_complex = '"[1][0] overlay"';
	
	
	# check config file
	print "Reading configuration parameters...\n";
	open (my $cfh, '<:encoding(UTF-8)', $config_file) or die "Could not open file '$config_file' $!";

	while (my $row = <$cfh>) {
  		chomp $row;
  		if ($row =~ /^\#.*/) {
  			next;
  		}
  		elsif ($row =~ /^auphonic_credentials\:(.*)/) {
  			$auph_cred = $1;
  		}
  		elsif ($row =~ /^auphonic_preset_sq\:(.*)/) {
  			$auph_preset_sq = $1;
  		}
  		elsif ($row =~ /^auphonic_preset_hq\:(.*)/) {
  			$auph_preset_hq = $1;
  		}
  		elsif ($row =~ /^screen_crop\:(.*)/) {
  			$vfSCR = $1;
  		}
  		elsif ($row =~ /^camera_crop\:(.*)/) {
  			$vfCAM = $1;
  		}
  		elsif ($row =~ /^output_container\:(.*)/) {
  			$suffix = $1;
  		}
  		elsif ($row =~ /^pixel_format\:(.*)/) {
  			$pix_fmt = $1;
  		}
  		elsif ($row =~ /^spectrumBG_file\:(.*)/) {
  			$spectrumBG_file = $1;
  		}
	}
	close $cfh;
	
	# set default auphonic preset to standard quality
	$auph_preset = $auph_preset_sq;
	
	# check input arguments
	my $argvi = 0;
	foreach (@ARGV) {
		if ($_ eq '-i') { # input file name
			$input_file = $ARGV[$argvi + 1];
		}
		elsif ($_ eq '-o') { # output base name (optional)
			$out_base_name = $ARGV[$argvi + 1];
		}
		elsif ($_ eq '-f') { # output file container format (mp4, mov (default))
			$suffix = $ARGV[$argvi + 1];
		}
		elsif ($_ eq '-vmode') { # video mode
			$vmode = $ARGV[$argvi + 1];
			if ($vmode eq 'copy' or $vmode == 0) { # 0 or 'copy' -> passes the input video to the output as a single stream; no encoding (copy stream) (default option)
				$vmode = 0;
				$auph_preset = $auph_preset_hq; # high-quality auphonic preset
			}
			elsif ($vmode eq 'single' or $vmode == 1) { # 1 or 'single' -> passes the input video to the output as a single stream
				$vmode = 1;
			}
			elsif ($vmode eq 'double' or $vmode == 2) { # 2 or 'double' -> crops input video in two separate videos (screen/cam)
				$vmode = 2;
			}
			elsif ($vmode eq 'screen' or $vmode == 3) { # 3 or 'screen' -> extracts the screen part of a double input video (cam is discarded)
				$vmode = 3;
			}
			elsif ($vmode eq 'camera' or $vmode == 4) { # 4 or 'camera' -> extracts the camera part of a double input video (screen is discarded)
				$vmode = 4;
			}
			elsif ($vmode eq 'audio' or $vmode == 5) { # 5 or 'audio' -> discards all video input and generates a new video with a visual representation of the spectrum of the input audio and a custom background (useful mainly for audio-only input)
				$vmode = 5;
			}
		}
		elsif ($_ eq '-vfscr') { # custom video filters (ffmpeg) for the screen part. NOTE: overrides default crop values
			$vfSCR = $ARGV[$argvi + 1];
		}
		elsif ($_ eq '-vfcam') { # custom video filters (ffmpeg) for the camera part. NOTE: overrides default crop values
			$vfCAM = $ARGV[$argvi + 1];
		}
		elsif ($_ eq '-vf') { # custom video filters (ffmpeg) for single video mode
			$vf = $ARGV[$argvi + 1];
			if ($vf =~ /r((es(olution)?)?\/2)|h/i) { # shortcut to halve resolution: 'rh' or 'r/2' or 'res/2' or 'resolution/2'
				$vf = 'scale=-1:ih/2';
			}
		}
		elsif ($_ eq '-pix_fmt') { # custom pixel format (ffmpeg)
			$pix_fmt = $ARGV[$argvi + 1];
		}
		elsif ($_ eq '-nopho') { # skip auphonic processing
			$option_nopho = 1;
		}
		elsif ($_ eq '-ss') { # start time (ffmpeg)
			$option_ff_ss = '-ss ' . $ARGV[$argvi + 1];
		}
		elsif ($_ eq '-to') { # end time (ffmpeg)
			$option_ff_to = '-to ' . $ARGV[$argvi + 1];
		}
		elsif ($_ eq '-au') { # auphonic.com custom credentials
			$auph_cred = $ARGV[$argvi + 1];
		}
		elsif ($_ eq '-ap') { # auphonic.com custom preset uuid
			$auph_preset = $ARGV[$argvi + 1];
		}
		elsif ($_ eq '-aq') { # auphonic choose between two given presets: high or standard quality. NOTE: put after "-vmode copy" to override automatic auphonic preset setting
			$auph_quality = $ARGV[$argvi + 1];
			if ($auph_quality =~ /hi(gh)?/i) { # "high" or "hi" for high quality
				$auph_preset = $auph_preset_hq;
			}
			elsif ($auph_quality =~ /(st(an)?d(ard)?|(lo)(w)?)/i) { # "standard", "std", "low", or "lo" for standard/low quality
				$auph_preset = $auph_preset_sq;
			}
		}
		$argvi++;
	}
	
	# additional definition of main variables
	$input_file =~ /(.+\/)([^\/]+)\.[^\.]+/;
	my $input_dir = $1;
	print "Input directory:\n$input_dir\n";
	unless (defined $out_base_name) {
		$out_base_name = $2;
	}
	$tmp_dir = $input_dir . '_tmp_' . $out_base_name . '/';
	mkdir $tmp_dir;
	$auphonic_base_name = time();
	$auphonic_name_pre = $tmp_dir . $auphonic_base_name . '.flac';
	unless ($vfSCR eq '') {
		$vfSCR = '-filter:v ' . $vfSCR;
	}
	unless ($vfCAM eq '') {
		$vfCAM = '-filter:v ' . $vfCAM;
	}
	unless ($vf eq '') {
		$vf = '-filter:v ' . $vf;
	}
	
	
	###############################
	# auphonic processing: part 1 #
	###############################
	if ($option_nopho == 0) {
		print "preparing file for auphonic..\n";
		system "ffmpeg -i $input_file $option_ff_ss $option_ff_to -vn -c:a flac -filter:a aresample=async=1000 $auphonic_name_pre";
		my $auph_command = 'curl -k -v -X POST https://auphonic.com/api/simple/productions.json -u ' . $auph_cred . ' -F "preset=' . $auph_preset . '" -F "input_file=@' . $auphonic_name_pre . '" -F "title=' . $auphonic_base_name . '" -F "action=start"';
		if (-s $auphonic_name_pre > 4096) {
			print "done\nsending file to auphonic..\n";
			if ($curl_output = `$auph_command`) { # grab cURL output to extract aphonic production uuid (will be needed in part 2 in order to download the processed audio file from auphonic.com)
				print "done\n";
				$curl_output =~ /edit_page\"[^\"]*\"([^\"]*)/;
				$auph_edit_page = $1;
				$auph_edit_page =~ /\/([^\/]*)$/;
				$auph_prod_uuid = $1;
				print "auphonic production UUID: $auph_prod_uuid\n";
			}
			else {
				die "could not send file to auphonic.com: $!";
			}
		}
		else {
			die "$auphonic_name_pre not found or epmty: $!";
		}
		print "start encoding video while waiting for auphonic.com...\n";
	}
	
	
	####################
	# video processing #
	####################
	# definition of output names
	if ($option_nopho == 0) {
		$out_name = $input_dir . $out_base_name . '_AUPH.' . $suffix;
		$out_SCR_name = $input_dir . $out_base_name . '_AUPH_SCR.' . $suffix;
		$out_CAM_name = $input_dir . $out_base_name . '_AUPH_CAM.' . $suffix;
		$out_vmode5_name = $input_dir . $out_base_name . '_AUPH_V5.' . $suffix;
	}
	else {
		$out_name = $input_dir . $out_base_name . '_ONE.' . $suffix;
		$out_SCR_name = $input_dir . $out_base_name . '_SCR.' . $suffix;
		$out_CAM_name = $input_dir . $out_base_name . '_CAM.' . $suffix;
		$out_vmode5_name = $input_dir . $out_base_name . '_V5.' . $suffix;
	}
	
	# check output video mode and proceed accordingly
	if ($vmode == 0) {
		if ($option_nopho == 1) {
			# remove tmp
			system "rm -r $tmp_dir";
			die "\nStream copy combined with omission of auphonic processing would result in the original file remuxed; you may want to use ffmpeg for this. Exiting.\n\n";
		}
		else {
			system "ffmpeg -i $input_file $option_ff_ss $option_ff_to -c:v copy -c:a aac -strict -2 -b:a 128k -movflags faststart $out_name";
			if ((-s $out_name) > 4096) {
				$out_FINAL_name = $out_name;
				print "\nvideo done\n";
			}
			else {
				die "\ncould not process video: $!";
			}
		}
	}
	elsif ($vmode == 1) {
		system "ffmpeg -vsync 1 -i $input_file $option_ff_ss $option_ff_to -c:v libx264 -pix_fmt $pix_fmt $vf -c:a aac -strict -2 -b:a 64k $vf -movflags faststart $out_name";
		if ((-s $out_name) > 4096) {
			$out_FINAL_name = $out_name;
			print "\nvideo done\n";
		}
		else {
			die "\ncould not process video: $!";
		}
	}
	elsif ($vmode == 2) {
		system "ffmpeg -vsync 1 -i $input_file $option_ff_ss $option_ff_to -c:v libx264 -an $vfSCR -pix_fmt $pix_fmt -movflags faststart $out_SCR_name $option_ff_ss $option_ff_to -c:v libx264 $vfCAM -pix_fmt $pix_fmt -c:a aac -strict -2 -b:a 64k -movflags faststart $out_CAM_name";
		if ((-s $out_SCR_name) > 4096 and (-s $out_CAM_name) > 4096) {
			$out_FINAL_name = $out_CAM_name;
			print "\nvideo done\n";
		}
		else {
			die "\ncould not process video: $!";
		}
	}
	elsif ($vmode == 3) {
		system "ffmpeg -vsync 1 -i $input_file $option_ff_ss $option_ff_to -c:v libx264 $vfSCR -pix_fmt $pix_fmt -c:a aac -strict -2 -b:a 64k -movflags faststart $out_SCR_name";
		if ((-s $out_SCR_name) > 4096) {
			$out_FINAL_name = $out_SCR_name;
			print "\nvideo done\n";
		}
		else {
			die "\ncould not process video: $!";
		}
	}
	elsif ($vmode == 4) {
		system "ffmpeg -vsync 1 -i $input_file $option_ff_ss $option_ff_to -c:v libx264 $vfCAM -pix_fmt $pix_fmt -c:a aac -strict -2 -b:a 64k -movflags faststart $out_CAM_name";
		if ((-s $out_CAM_name) > 4096) {
			$out_FINAL_name = $out_CAM_name;
			print "\nvideo done\n";
		}
		else {
			die "\ncould not process video: $!";
		}
	}
	elsif ($vmode == 5) {
		if ($option_nopho == 1) {
			#my $input_file_esc = quotemeta ($input_file);
			$vmode5_lavfi_input = '"amovie=' . $input_file . ',showspectrum=s=640x360"';
			# debugging print
			#print "auphCredentials: $auph_cred\nauphPresets: $auph_preset_sq, $auph_preset_hq\nauphChosen: $auph_preset\nscreen crop: $vfSCR\ncamera crop: $vfCAM\npixel format: $pix_fmt\nlavfi input: $vmode5_lavfi_input\n" and die;
			system "ffmpeg -i $spectrumBG_file -f lavfi -i $vmode5_lavfi_input -i $input_file -r 25 $option_ff_ss $option_ff_to -pix_fmt $pix_fmt -filter_complex $vmode5_filter_complex -c:v libx264 -crf 26 -c:a aac -strict -2 -b:a 64k -movflags faststart $out_vmode5_name";
			if ((-s $out_vmode5_name) > 4096) {
				print "\nvideo done\n";
			}
			else {
				die "\ncould not process video: $!";
			}
		}
	}
	
	
	###############################
	# auphonic processing: part 2 #
	###############################
	if ($option_nopho == 0) {
		my $aupho_wait_ii = 0;
		my $auph_presize = 0;
		my $auphonic_name_post = $auphonic_base_name . '.m4a';
		my $auphonic_name_post_loc = $tmp_dir . $auphonic_name_post;
		$auph_dl_url = $auph_dl_url_base . $auph_prod_uuid . '/' . $auphonic_name_post;

		while ($aupho_wait_ii < 360) {
			print "checking file on auphonic.com...\n";
			my $curl_chksz = "curl -sI $auph_dl_url -u $auph_cred \| grep Content-Length \| awk \'\{print \$2\}\'";
			if (my $auph_size = `$curl_chksz`) {
				if ($auph_size > $auph_presize) {
					print "current file size: $auph_size\n";
					sleep 10;
					$auph_presize = $auph_size;
					next;
				}
				elsif ($auph_size < 4096) {
					print "current file size: $auph_size: file too small...";
					$aupho_wait_ii++;
					sleep 10;
					next;
				}
				else {
					print "OK\n";
				}
			}
			else {
				print "\nfile not online: attempting again in a few moments...\n";
				sleep 10;
				$aupho_wait_ii++;
				next;
			}
			print "retrieving file from auphonic.com...\n";
			system "curl -o $auphonic_name_post_loc $auph_dl_url -u $auph_cred";
			if ((-s $auphonic_name_post_loc) > 4096) {
				print "done\n";
				print "producing final video...\n";
				$tmp_FINAL_name = $tmp_dir . $out_base_name . '_TMP.' . $suffix;
				rename $out_FINAL_name, $tmp_FINAL_name;
				if ($vmode == 5) {
					$vmode5_lavfi_input = '"amovie=' . $auphonic_name_post_loc . ',showspectrum=s=640x360"';
					$out_FINAL_name = $out_vmode5_name;
					system "ffmpeg -i $spectrumBG_file -f lavfi -i $vmode5_lavfi_input -i $auphonic_name_post_loc -r 25 -pix_fmt $pix_fmt -filter_complex $vmode5_filter_complex -c:v libx264 -crf 26 -c:a aac -movflags faststart $out_FINAL_name";
				}
				else {
					system "ffmpeg -i $tmp_FINAL_name -i $auphonic_name_post_loc -map 0:v -map 1:a -c copy -movflags faststart -y $out_FINAL_name";
				}
				if ((-s $out_FINAL_name) > 4096) {
					print "done\n";
				}
				else {
					die "\ncould not produce final video: $!";
				}
				# remove tmp
				system "rm -r $tmp_dir";
				print "bye\n\n";
				exit 0;
			}
			else {
				die "\ncould not download auphonic file: $!";
			}
		}
		print "ERROR: after several attempts it was not possible to retrieve the .m4a file from auphonic.com:\nproceeding using the original audio\n";
		if ($vmode == 5) {
			$vmode5_lavfi_input = '"amovie=' . $input_file . ',showspectrum=s=640x360"';
			system "ffmpeg -i $spectrumBG_file -f lavfi -i $vmode5_lavfi_input -i $input_file -r 25 $option_ff_ss $option_ff_to -pix_fmt $pix_fmt -filter_complex $vmode5_filter_complex -c:v libx264 -crf 26 -c:a aac -strict -2 -b:a 64k -movflags faststart $out_vmode5_name";
			if ((-s $out_vmode5_name) > 4096) {
				print "done\n";
			}
			else {
				die "\ncould not create video with spectrum: $!";
			}
		}
	}
	else {
		# remove tmp
		system "rm -r $tmp_dir";
		print "bye\n\n";
		exit 0;
	}
}
exit 0;