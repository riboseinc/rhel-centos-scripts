#!/bin/bash

find . -name *.sh | while read bin; do
	install -m 0755 -o root -g root "${bin}" /usr/local/bin || \
		exit 1
done
