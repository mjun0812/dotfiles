#!/bin/bash

if [ -n "$TMUX" ]; then
    tmux new-window
    
    # create right pane
    tmux split-window -h -l 25%
    
    # create bottom pane
    tmux split-window -v -l 25% -t 1

    # splot bottom pane
    tmux split-window -h -t 2
    
    tmux select-pane -t 1
else
    tmux new-session -d

    SESSION_ID=$(tmux ls | tail -n 1 | cut -d: -f1)
    echo "Session ID: $SESSION_ID"
    
    tmux split-window -h -l 25% -t ${SESSION_ID}:1
    
    tmux split-window -v -l 25% -t ${SESSION_ID}:1.1
    
    tmux split-window -h -t ${SESSION_ID}:1.2
    
    tmux attach-session -t ${SESSION_ID}.1
fi
