#!/bin/zsh
tmux new -d
tmux send-keys "zuikaku" C-m
tmux split-window -h
tmux send-keys 'ssh -t mjun_zuikaku "watch nvidia-smi"' C-m
tmux split-window -v
tmux resize-pane -D 30 

tmux select-paneA -t 0
tmux a
