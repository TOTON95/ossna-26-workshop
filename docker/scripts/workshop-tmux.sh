#!/usr/bin/env bash
# workshop-tmux: launch a preconfigured tmux layout for the OSSNA 2026
# PX4 + ROS 2 workshop.
#
# Creates one named session ('ossna') with two windows:
#
#   sim     - a 6-pane grid, one pane per long-running foreground
#             process. Four are workshop infrastructure (gazebo / px4 /
#             common.launch.py / QGroundControl); the other two are
#             example panes, because the teleop and precision-land
#             exercises each run TWO ROS 2 example nodes at the same
#             time (e.g. aruco_tracker + precision_land).
#
#                 ┌──────────────┬──────────────┐
#                 │ gazebo       │ px4          │
#                 ├──────────────┼──────────────┤
#                 │ common       │ qgc          │
#                 ├──────────────┼──────────────┤
#                 │ ros2 node 1  │ ros2 node 2  │
#                 └──────────────┴──────────────┘
#
#             Each pane is pre-seeded with comment-only hint lines
#             showing the command you would paste there. The script
#             does not start anything for you — you still copy-paste
#             the actual commands from the workshop docs, but now into
#             ONE terminal window.
#
#   scratch - empty pane for ad-hoc `ros2 topic echo`, `ros2 node list`,
#             editing files with vim/nano, etc.
#
# If the session already exists this reattaches to it. The attach uses
# `-d` to detach any other client first: the 6-pane layout is built from
# percentage splits, so two clients of different terminal sizes attached
# at once make tmux resize the shared window and collapse the panes. One
# client at a time keeps the layout intact, and makes `docker_run.sh
# --tmux` and `docker exec ... workshop-tmux` behave identically.

set -eu

SESSION="ossna"

if tmux has-session -t "${SESSION}" 2>/dev/null; then
    exec tmux attach -d -t "${SESSION}"
fi

# Start the 'sim' window with the first pane (top-left = gazebo).
#
# Every pane is created running `clear; workshop-hint TOPIC; exec bash`:
# it prints the hint card and then `exec bash` hands over to an
# interactive shell that sources ~/.bashrc (the ROS 2 environment).
# Running the hint AS the pane's command — instead of injecting it
# afterwards with `send-keys` — is race-free: there is no freshly-spawned
# shell for the keystrokes to be lost to before it starts reading input.
#
# Pin default-terminal in the SAME tmux invocation that creates the
# session, before new-session. A pane takes its TERM from default-terminal
# at spawn time, and new-session spawns pane %0 immediately — so if
# default-terminal were set afterwards (with the other `set -g` below) %0
# would keep tmux's built-in `screen` default while the later split-window
# panes got tmux-256color. That mismatch shows: `screen` is an 8-colour,
# non-256 TERM, so the gazebo pane loses the 256-colour hint palette and
# its coloured shell prompt (Ubuntu's ~/.bashrc only colours the prompt
# for a *-256color TERM). The two commands must share one `tmux` call —
# a server with no sessions exits, so `start-server` then a separate `set`
# would not persist.
tmux set -g default-terminal "tmux-256color" \; \
     new-session -d -s "${SESSION}" -n sim "clear; workshop-hint gazebo; exec bash"

# --- Friendlier defaults ---
tmux set -g pane-border-status top
tmux set -g history-limit 20000
tmux setw -g mode-keys vi
tmux set -g status-interval 1                # refresh status bar (and animations) every second
tmux set -ga terminal-overrides ",xterm-256color:Tc"   # tell tmux the outer terminal is true-color
tmux set -g pane-border-lines heavy          # thicker borders on tmux 3.2+

# Mouse mode ON so attendees can click panes to focus them and scroll
# back through long-running command output with the wheel.
#
# To copy text, just drag with the mouse. A drag puts tmux into copy-mode,
# which FREEZES that pane for the duration of the selection — so the
# continuous gazebo / px4 output can no longer scroll your selection away
# (the old advice was Shift+drag for a native terminal selection, but that
# is wiped the instant the pane or the animated status bar repaints).
# `set-clipboard on` then forwards whatever tmux copies to the host's
# system clipboard via the OSC 52 escape sequence, so a plain drag is all
# you need — no Shift, and the selection survives screen updates.
tmux set -g mouse on
tmux set -g set-clipboard on

# --- Dracula-inspired palette (synthwave-y, dev-friendly) ---
#   bg     #282a36   bg-dark  #13111c
#   pink   #ff79c6   purple   #bd93f9   cyan #8be9fd
#   green  #50fa7b   yellow   #f1fa8c   orange #ffb86c
#   red    #ff5555   fg       #f8f8f2   comment #6272a4
tmux set -g status-style              "bg=#13111c,fg=#f8f8f2"
tmux set -g message-style             "bg=#ff79c6,fg=#13111c,bold"
tmux set -g pane-border-style         "fg=#3a3a5a"               # dim border for inactive
tmux set -g pane-active-border-style  "fg=#ff79c6,bold"          # hot pink for the active pane

# Pane title in the border: hex-bullets in cyan + bold pink name.
# Active pane gets a brighter title via pane-active-border-style colour, the
# format string itself is the same for all panes.
tmux set -g pane-border-format " #[fg=#8be9fd,bold]⬢#[default] #[fg=#ff79c6,bold]#{pane_title}#[default] #[fg=#8be9fd,bold]⬢#[default] "

# Window list in the status bar (powerline-ish flat segments)
tmux setw -g window-status-style           "fg=#6272a4"
tmux setw -g window-status-current-style   "fg=#13111c,bold,bg=#8be9fd"
tmux setw -g window-status-format          "  #I⋅#W  "
tmux setw -g window-status-current-format  "  #I⋅#W  "
tmux setw -g window-status-separator       ""

# Flash window name yellow when an inactive window has new output
tmux set -g monitor-activity on
tmux set -g visual-activity off
tmux setw -g window-status-activity-style  "fg=#f1fa8c,bold,blink"

# --- Animations ---
# status-left: synthwave title with a traveling "scanner" highlight that
#              sweeps across the text twice per second (workshop-banner
#              emits the tmux format string).
# status-right: 5-bar EQ visualiser + cyan workshop label + magenta clock.
tmux set -g status-left-length 60
tmux set -g status-right-length 80
tmux set -g status-left  "#(workshop-banner) "
tmux set -g status-right "#[fg=#6272a4]┤ #(workshop-spinner) #[fg=#8be9fd,bold]workshop #[fg=#6272a4]│ #[fg=#bd93f9,bold]%H:%M:%S #[fg=#6272a4]├"

# Make the prefix indicator obvious when prefix is held
tmux set -g status-keys vi

# --- Easy-to-reach shortcuts (NO PREFIX needed) -----------------------------
# Some terminals (notably VSCode's built-in one) eat tmux's mouse events or
# block Ctrl-b. Bind a few common navigations to bare Alt-something so they
# work everywhere.
tmux bind -n M-1     select-window -t 0           # Alt+1 -> sim window
tmux bind -n M-2     select-window -t 1           # Alt+2 -> scratch window
tmux bind -n M-Left  previous-window              # Alt+Left -> prev window
tmux bind -n M-Right next-window                  # Alt+Right -> next window
tmux bind -n M-h     select-pane -L               # Alt+h/j/k/l -> move pane
tmux bind -n M-j     select-pane -D
tmux bind -n M-k     select-pane -U
tmux bind -n M-l     select-pane -R
tmux bind -n M-z     resize-pane -Z               # Alt+z toggles pane zoom

# Build the 6-pane grid described in the header comment (3 rows x 2
# columns). Use stable pane IDs (#{pane_id}, %0/%1/...) instead of numeric
# pane_index because tmux re-numbers pane_index in reading order whenever
# the layout changes, which would scramble titles applied after all splits.
#
# Each split-window is given its `clear; workshop-hint TOPIC; exec bash`
# command directly, so the pane shows its hint with no send-keys race.

# Pane 0 is the existing pane we got from new-session = top-left (gazebo).
GZ_PANE="$(tmux display-message -p -t "${SESSION}:sim" '#{pane_id}')"

# Split horizontally → new pane is the whole right column = px4 (top-right).
PX4_PANE="$(tmux split-window -h -p 50 -t "${GZ_PANE}" -PF '#{pane_id}' \
    "clear; workshop-hint px4; exec bash")"

# Right column: split px4 into thirds → qgc (middle), example node 2 (bottom).
QGC_PANE="$(tmux split-window -v -p 67 -t "${PX4_PANE}" -PF '#{pane_id}' \
    "clear; workshop-hint qgc; exec bash")"
EXAMPLE2_PANE="$(tmux split-window -v -p 50 -t "${QGC_PANE}" -PF '#{pane_id}' \
    "clear; workshop-hint example2; exec bash")"

# Left column: split gazebo into thirds → common (middle), example node 1 (bottom).
COMMON_PANE="$(tmux split-window -v -p 67 -t "${GZ_PANE}" -PF '#{pane_id}' \
    "clear; workshop-hint common; exec bash")"
EXAMPLE1_PANE="$(tmux split-window -v -p 50 -t "${COMMON_PANE}" -PF '#{pane_id}' \
    "clear; workshop-hint example1; exec bash")"

# Title every pane by stable ID (titles render in the pane border
# thanks to the `pane-border-status top` option set above).
tmux select-pane -t "${GZ_PANE}"       -T "gazebo"
tmux select-pane -t "${PX4_PANE}"      -T "px4"
tmux select-pane -t "${QGC_PANE}"      -T "qgc"
tmux select-pane -t "${COMMON_PANE}"   -T "ros2 common.launch.py"
tmux select-pane -t "${EXAMPLE1_PANE}" -T "ros2 node 1"
tmux select-pane -t "${EXAMPLE2_PANE}" -T "ros2 node 2"

# Scratch window: title it so the pane-border-format does not render the
# default (container hostname); the welcome banner is the first thing
# attendees see when they switch to this window with Ctrl-b 1.
tmux new-window -t "${SESSION}" -n scratch \
    "clear; workshop-welcome 2>/dev/null || true; exec bash"
SCRATCH_PANE="$(tmux display-message -p -t "${SESSION}:scratch" '#{pane_id}')"
tmux select-pane -t "${SCRATCH_PANE}" -T "scratch"

# Focus the first pane and attach (-d: detach any other client, see above).
tmux select-window -t "${SESSION}:sim"
tmux select-pane -t "${SESSION}:sim.0"
exec tmux attach -d -t "${SESSION}"
