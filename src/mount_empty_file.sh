#!/bin/bash
if ! test -f myempty.img; then
  ./create_empty_file.sh
fi

sudo losetup -f -P myempty.img
