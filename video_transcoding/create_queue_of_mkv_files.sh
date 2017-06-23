#!/usr/bin/env bash

#This script is a batch wrapper for Don  Me 
#Docker Verion: sudo docker run -i -t -v "`pwd`":/data -v /media/data/4tb/Media/Movies2:/in ntodd/video-transcoding bash /data/create_queue_of_mkv_files.sh /in 1
#docker pull ntodd/video-transcoding

#readonly target="/home/bob/scripts/docker"
#readonly queue="$work/queue.txt"


#########################
#functions
#########################

transcodeme() {
	#1 title_file_name
	#2 title_dir
	#3 title_name
	#4 detect_out
	#5 line
	#6 number file in name

	#From the argument 6 value to add to the file name
	if [ $6 ]; then
		argfilename=" $6"
	else
		# argfilename is empty if not pass
		argfilename=""
	fi

	echo Starting transcoding of $3
	echo transcode-video --crop $4 "$5"
	#Run the Transcode here
	transcode_out=$(transcode-video --crop $4 "$5")
	OUT2=$?
	OUT2=0
	echo transcode-video return code $OUT2
	#echo $transcode_out
	if [ $OUT2 -eq 0 ]; then
		ls -ltrh "./$1"
		mv "./$1" "$2/$3 - 1080p$argfilename.mkv"
		OUT3=$?
		if [ $OUT3 -ne 0 ]; then
			ERROR_CODE=1
			e1="ERROR: There was an issue moving the new $3"
			error_msg="\n$e1"
			echo $e1
		fi
	else
		ERROR_CODE=1
		e1="ERROR: There was an issue with transcoding $3"
		error_msg="\n$e1"
		echo $e1
	fi
}


#########################
#Start
#########################



START=$(date +%s);

#If no arguments are base exit.
if [ $# -eq 0 ]; then
	echo usage: $(basename $0) "Path to MKVs"
	exit 1
fi

#Not longer need, remove
#if [ $1 ]; then
#	readonly target="$1"
#	find "$target" -name '*.mkv' -size +14G
#else 
#	echo usage: $(basename $0) "Path to MKVs"
#	exit 1
#fi

echo $(curl -s 'http://192.168.1.203:8080/?AutoRemoteSnd_Message_To_Group&MKVCon&Starting')

#From the arguments get the target path
if [ $1 ]; then
	readonly target="$1"
	input="$(find "$target" -name '*.mkv' -size +12G)"
else 
	echo usage: $(basename $0) "Path to MKVs"
	exit 1
fi

#From the arguments get the runtime length in minutes, default is 999
if [ $2 ]; then
	runtime="$2"
else 
	echo "Runtime was not set, defaulting to 999 minutes"
	runtime="999"
fi

ERROR_CODE=0
error_msg="There was an error"


printf %s "$input" | while IFS= read -r line; do
	{
	title_name="$(basename "$line" | sed 's/\.[^.]*$//')"
	title_file_name="$(basename "$line")"
	title_dir=$(dirname "$line")
	echo Working on Tile: "$title_name"
	echo File Name: "$title_file_name"
	echo Dictory: "$title_dir"

	title_count="$(find "$title_dir" -name '*.mkv' | wc -l)"
	echo Title Count: "$title_count"

	ls -ltrh "$title_dir" | grep .mkv

	if [ $title_count -gt 1 ]; then
		echo "No need to transcode, already done."
	else
		#Get the crop value
		detect_out="$(detect-crop --values-only "$line")"
		OUT=$?
		echo Detect1: detect-crop return code $OUT
		echo Detect1: $detect_out

		#The magic, only if the crop setting is good
		#if grep -q -i 'HandBrakeCLI and mplayer differ' <<<$string; then
		#	echo Skipping
	    #fi

	    #Transcode
	    if [ $OUT -eq 0 ]; then

	    	echo Transcode: Start transcodeme
	    	#Calls are function to transcode the video.
	    	transcodeme "$title_file_name" "$title_dir" "$title_name" "$detect_out" "$line"
	    	echo Transcode: End transcodeme
	    else
	    	echo Transcode Else: Start
	    	detect_out="$(detect-crop "$line")"
	    	OUT=$?
	    	echo Transcode Else: detect-crop return code $OUT
	    	echo Transcode Else: $detect_out
	    	if grep -q 'From HandBrakeCLI.*From ffmpeg' <<<$detect_out; then
	    		crop1=$(echo $detect_out | awk -F'#' '{print $2}' | awk -F'--crop ' '{print $2}' | awk '{print $1}')
	    		echo crop1 is $crop1
	    		echo Transcode Else : Start transcodeme crop1
	    		#Calls are function to transcode the video.
	    		transcodeme "$title_file_name" "$title_dir" "$title_name" "$crop1" "$line" "1"
	    		echo Transcode Else: End transcodeme crop1



	    		crop2=$(echo $detect_out | awk -F'#' '{print $3}' | awk -F'--crop ' '{print $2}' | awk '{print $1}')
	    		echo crop2 is $crop2
	    		echo Transcode Else : Start transcodeme crop2
	    		#Calls are function to transcode the video.
	    		transcodeme "$title_file_name" "$title_dir" "$title_name" "$crop2" "$line" "2"
	    		echo Transcode Else: End transcodeme crop2
	    	else
	    		ERROR_CODE=1
	    		e1="ERROR: Skipping $title_name, detect-crop failed"
	    		error_msg="\n$e1"
	    		echo $e1
	    	fi

	    	echo Transcode Else: End
	    fi
	fi

	NOW=$(date +%s);
	TD=$((NOW-START));
	(( TD = TD / 60 ));
	echo Current Run Time is $TD minutes   #| awk '{print int($1/60)":"int($1%60)}'
	echo "========================================"
	if [ $TD -gt $runtime ]; then
		break
	fi
} < /dev/null;
done


END=$(date +%s);
ED=$((END-START));
(( ED = ED / 60 ));
echo "========================================"
echo Total Runtime: $ED
echo $(curl -s 'http://192.168.1.203:8080/?AutoRemoteSnd_Message_To_Group&MKVCon&Complete')
echo $ERROR_CODE
if [ $ERROR_CODE -eq 1 ]; then
	echo $error_msg
fi
