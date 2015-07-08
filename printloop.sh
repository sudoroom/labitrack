#!/bin/sh

printer="/dev/usb/lp0"
queuedir=queue

print_queue(){
	for job in $(ls -1 "$queuedir/new"); do
		./trigger.sh "$printer" "$queuedir"
	done
}

print_queue
while true; do
	if inotifywait --quiet --timeout 30 "$queuedir/new"; then
		print_queue
	fi
done
