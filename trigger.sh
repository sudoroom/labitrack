#!/bin/sh

printer="$1"
queue_dir="$2"
printed_dir=$queue_dir/printed/

mkdir -p $printed_dir

for file in $(ls $queue_dir/new/* 2>/dev/null); do
	echo printing $file
	./ql570/ql570 $printer w $file
	status=$?
	if [ $status -ne 0 ] ; then
		exit $status
	fi
	mv $file $printed_dir
done

exit 0
