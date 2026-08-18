#! /bin/bash

container system start

# → kata-static-3.28.0-arm64 から vmlinux-6.18.15-186 を取得して既定化
container system kernel set --recommended --force
