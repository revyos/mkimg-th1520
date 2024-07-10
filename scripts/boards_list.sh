#!/bin/bash

BOARD_LPI4A="lpi4a"
BOARD_AHEAD="ahead"
BOARD_CONSOLE4A="console"
BOARD_LAPTOP4A="laptop"
BOARD_LPI4A_MAINLINE="lpi4amain"
BOARD_MELES="meles"

check_board_vaild()
{
    if [[ ! -v BOARD ]]; then
        echo "env BOARD is not set!"
        exit 2
    elif [[ -z "$BOARD" ]]; then
        echo "env BOARD is set to the empty string!"
        exit 2
    else
        if [ $BOARD == $BOARD_LPI4A ]; then
            echo "building lpi4a image..."
        elif [ $BOARD == $BOARD_AHEAD ]; then
            echo "building AHead image..."
        elif [ $BOARD == $BOARD_CONSOLE4A ]; then
            echo "building Console4A image..."
        elif [ $BOARD == $BOARD_LAPTOP4A ]; then
            echo "building Laptop4A image..."
        elif [ $BOARD == $BOARD_LPI4A_MAINLINE ]; then
            echo "building lpi4a mainline image..."
        elif [ $BOARD == $BOARD_MELES ]; then
            echo "building Meles image..."
        else
            echo "No matching board found, exit..."
            exit 3
        fi
    fi
}