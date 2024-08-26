#!/bin/bash

RED="\x1B[31m"
GRN="\x1B[1;32m"
YEL="\x1B[33m"
BLU="\x1B[34m"
MAG="\x1B[35m"
BMAG="\x1B[1;35m"
CYN="\x1B[36m"
BCYN="\x1B[1;36m"
WHT="\x1B[37m"
RESET="\x1B[0m"
LINEP="\033[75G" 
FAIL=false
LOG_DIR=logs/
FDF_LOG=fdf.log
FDF_MLOG=fdf_memory.log
FDF_MAP=fdf_map.log
ESC=ESC
CLOSE=CLOSE

usage() {
	cat <<EOF
Usage: $0 [options] [--] [file...]

Arguments:

  -f <val>, --file <val>, --file=<val>
	After setting this parameter, an argument must follow with relative 
	path to the directory where the norminette check should take place.
	e.g. [bash ./norminette_tester -d ./src]
	Without this paramater the program will not continue

  -h, --help
	Display this usage message and exit.

EOF
}

#prepare xdotool
make -C ./xdotool

make -C ../ re

# handy logging and error handling functions
log() { printf '%s\n' "$*"; }
error() { log "ERROR: $*" >&2; }
fatal() { error "$*"; exit 1; }
usage_fatal() { error "$*"; usage >&2; exit 1; }

# parse options
while [ "$#" -gt 0 ]; do
	arg=$1
	case $1 in
		# convert "--opt=the value" to --opt "the value".
		# the quotes around the equals sign is to work around a
		# bug in emacs' syntax parsing
		--*'='*) 
		shift;
		set -- "${arg%%=*}" "${arg#*=}" "$@";
		continue;;
		-f|--file) 
		file=$2
		shift 2
		;;
		-h|--help)
		usage;
		exit 0
		;;
		--)
		shift;
		break
		;;
		-*)
		usage_fatal "unknown option:'$1'"
		;;
		*)
		break
		;; # reached the list of file names
	esac
done

# arguments are now the file names


if [ -n "$file" ];
then :
else 
usage_fatal "option '-f, --file' requires a value"
exit 1
fi

mkdir -p logs

truncate -s 0 $LOG_DIR/$FDF_LOG
truncate -s 0 $LOG_DIR/$FDF_MLOG
truncate -s 0 $LOG_DIR/$FDF_MAP 

fail_unittest () {
printf "${BMAG} $file $1${RESET}"

coproc { timeout --preserve-status 1s sh -c " ./$file $1 >> $LOG_DIR/$FDF_LOG 2>&1"; }
COPROC_PID_backup=$COPROC_PID
wait $COPROC_PID_backup
status=$?

coproc { timeout --preserve-status 1s sh -c "valgrind --error-exitcode=42 --leak-check=full ./$file $1 >> $LOG_DIR/$FDF_MLOG 2>&1"; }
COPROC_PID_backup=$COPROC_PID
wait $COPROC_PID_backup
mstatus=$?

if [ $status == 0 ] || [ $status == 143 ];
	then 
	printf "${BMAG} ${LINEP}${RED}FAIL ${RESET}";
	echo -e "Test: $file $1: expected status = 1; received status $status" >> $LOG_DIR/$FDF_MAP 
	FAIL=true;
	if [ $mstatus == 42 ];
		then 
		printf "${RED}MKO${RESET}\n";
		echo -e "Test: $file $1: expected memory_status = 1; received memory_status $mstatus" >> $LOG_DIR/$FDF_MAP 
		FAIL=true;
		else 
			if [ $mstatus == 143 ];
				then
				printf "${RED}MKO${RESET}\n";
				echo -e "Test: $file $1: expected memory_status = 1; received memory_status $mstatus" >> $LOG_DIR/$FDF_MAP 
				FAIL=true;
			else
				printf "${GRN}MOK${RESET}\n";
			fi
	fi
else
	printf "${BMAG} ${LINEP}${GRN}OK ${RESET}";
	if [ $mstatus == 42 ];
		then 
		printf "${RED}MKO${RESET}\n";
		echo -e "Test: $file $1: expected memory_status = 1; received memory_status $mstatus" >> $LOG_DIR/$FDF_MAP 
		FAIL=true;
		else 
			if [ $mstatus == 143 ];
				then
				printf "${RED}MKO${RESET}\n";
				echo -e "Test: $file $1: expected memory_status = 1; received memory_status $mstatus" >> $LOG_DIR/$FDF_MAP 
				FAIL=true;
			else
				printf "${GRN}MOK${RESET}\n";
			fi
	fi
FAIL=true;
fi
}

correct_unittest () {
coproc { ./$file $1 >> $LOG_DIR/$FDF_LOG 2>&1; }
sleep 1
activewindow=$(xwininfo -root -tree | grep -P 'fdf(?!_)' | awk '{print $1}')
sleep 9
LD_LIBRARY_PATH=xdotool ./xdotool/xdotool windowactivate $activewindow
if [ $2 == $ESC ] ;
	then
	LD_LIBRARY_PATH=xdotool ./xdotool/xdotool key Escape
fi
if [ $2 == $CLOSE ] ;
	then
	LD_LIBRARY_PATH=xdotool ./xdotool/xdotool key Alt_L+F4
fi
COPROC_PID_backup=$COPROC_PID
wait $COPROC_PID_backup
status=$?

coproc { valgrind --error-exitcode=42 --leak-check=full ./$file $1 >> $LOG_DIR/$FDF_MLOG 2>&1; }
sleep 1
activewindow=$(xwininfo -root -tree | grep -P 'fdf(?!_)' | awk '{print $1}')
sleep 9
LD_LIBRARY_PATH=xdotool ./xdotool/xdotool windowactivate $activewindow
if [ $2 == $ESC ] ;
	then
	LD_LIBRARY_PATH=xdotool ./xdotool/xdotool key Escape
fi
if [ $2 == $CLOSE ] ;
	then
	LD_LIBRARY_PATH=xdotool ./xdotool/xdotool key Alt_L+F4
fi
COPROC_PID_backup=$COPROC_PID
wait $COPROC_PID_backup
mstatus=$?

printf "${BMAG} $file $1${RESET}"

if [ $status != 0 ] ;
	then 
	printf "${BMAG} ${LINEP}${RED}FAIL ${RESET}";
	echo -e "Test: $file $1: expected status = 0; received status $status" >> $LOG_DIR/$FDF_MAP 
	FAIL=true;
		if [ $mstatus != 0 ];
		then 
		printf "${RED}MKO${RESET}\n";
		echo -e "Test: $file $1: expected memory_status = 0; received memory_status $mstatus" >> $LOG_DIR/$FDF_MAP 
		FAIL=true;
		else
		printf "${GRN}MOK${RESET}\n";
		fi
else
	printf "${BMAG} ${LINEP}${GRN}OK ${RESET}";
		if [ $mstatus != 0 ];
		then 
		printf "${RED}MKO${RESET}\n";
		echo -e "Test: $file $1: expected memory_status = 0; received memory_status $mstatus" >> $LOG_DIR/$FDF_MAP 
		FAIL=true;
		else
		printf "${GRN}MOK${RESET}\n";
		fi
fi

}
##### input tests

echo -e "${BLU}----------------------------------
|            input tests          |
----------------------------------${RESET}" 

ARGS='lol "lol lol" "lol lol lol" "lol lol lol lol" "" no_exits.fdf ../random/test.fdf ../resources/invalid_maps/*'

eval set -- $ARGS
for ARG in "$@";
do
fail_unittest "$ARG"
done

# ##### testing maps 
# #https://stackoverflow.com/questions/20017805/bash-capture-output-of-command-run-in-background
# #https://stackoverflow.com/questions/9954794/execute-a-shell-function-with-timeout
# #https://stackoverflow.com/questions/57877451/retrieving-output-and-exit-code-of-a-coprocess

echo -e "${BLU}----------------------------------
|       Incorrect Map tests       |
----------------------------------${RESET}" 


invalids=$(find ../resources/incorrect_maps -type f)

for invalid in $invalids
do
fail_unittest "$invalid"
done


echo -e "${BLU}----------------------------------
|        Correct Map tests ESC    |
----------------------------------${RESET}" 

#https://groups.google.com/g/xdotool-users/c/Z8g4ZHKYAsE This is important fot the xdo tool command!
#https://unix.stackexchange.com/questions/85205/is-there-a-way-to-simulate-a-close-event-on-various-windows-using-the-terminal
#https://askubuntu.com/questions/695017/why-does-my-xdotool-key-command-not-work

valids=$(find ../resources/correct_maps -type f)

for valid in $valids
do
correct_unittest "$valid" "$ESC"
done

# echo -e "${BLU}----------------------------------
# |      Correct Map tests ALT+F4   |
# ----------------------------------${RESET}" 

valids=$(find ../resources/correct_maps -type f)

for valid in $valids
do
correct_unittest "$valid" "$CLOSE"
done


if [ $FAIL = true ];
then echo -e "${RED}Check logs/*.log for errors${RESET}"
else echo -e "${GRE}Congratulations, all tests are succesfull :)${RESET}"
fi
exit 0