#!/bin/bash

sudo rm -r build/ || true
sudo rm -r busybox-*/ || true
sudo rm -r linux/ || true
sudo rm -r i486-linux-musl-cross/ || true
sudo rm -r nano-*/ || true
sudo rm -r ncurses-*/ || true
sudo rm -r tnftp-*/ || true
sudo rm -r dropbear-*/ || true
sudo rm *.tar.gz || true
sudo rm *.tar.xz || true
sudo rm *.tgz || true
sudo rm -r images/ || true
sudo rm -r __pycache__/ || true
