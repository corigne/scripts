#!/usr/bin/env bash
echo pre-run, HYPRGAMEMODE=$HYPRGAMEMODE
export HYPRGAMEMODE=$(hyprctl getoption animations:enabled | awk 'NR==1{print $2}')
if [ "$HYPRGAMEMODE" = "true" ]; then
    hyprctl eval """
    hl.config({
        animations = { enabled = false },
        decoration = {
            shadow = { enabled = false },
            blur = { enabled = false },
            rounding = false
        },
        general = {
            gaps_in = 0,
            gaps_out = 0,
            border_size = true
        }
    })
    """
    kill -SIGUSR2 $(cat /tmp/awww-randomize-pidfile.txt)
else
    kill -SIGUSR1 $(cat /tmp/awww-randomize-pidfile.txt)
    hyprctl reload
fi
echo post-run, HYPRGAMEMODE=$HYPRGAMEMODE
