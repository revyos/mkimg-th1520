#!/bin/bash

# thank ice
if (cat /proc/device-tree/model | grep LicheeConsole4A);
then
	xinput set-prop 'ydx' 'Coordinate Transformation Matrix' 1 0 0 0 1 0 0 0 1
	ROTATE=1
else
	ROTATE=0
fi

if [ -z "$DISPLAY" ]
then
	export DSIPLAY=:0.0
fi

xinput_dev="pointer:Goodix Capacitive TouchScreen"

if [ ! -d "/sys/class/drm/card0-DSI-1" ]; then
    xrandr --output HDMI-1 --auto --primary
    #echo off > /sys/class/drm/card0-DSI-1/status
else
    HDMI_STATUS="$(cat /sys/class/drm/card0-HDMI-A-1/status)"
    if [ "${HDMI_STATUS}" = "disconnected" ]; then
        if [ "${ROTATE}" = "1" ]; then
            xrandr --output DSI-1 --auto --rotate right --primary
            xinput map-to-output "$xinput_dev" DSI-1
	fi
    elif [ "${HDMI_STATUS}" = "connected" ]; then
        xrandr --output HDMI-1 --auto --primary
        if [ "${ROTATE}" = "1" ]; then
            xrandr --output DSI-1 --auto --rotate right --below HDMI-1
            xinput map-to-output "$xinput_dev" DSI-1
	fi
    fi
fi
