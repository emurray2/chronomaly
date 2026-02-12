#!/usr/bin/env bash
set -euo pipefail

# Functions
ask_yes_no() {
    local question="$1"
    local default="${2:-N}"    # 'Y' or 'N'  (what happens when user just presses Enter)

    local yn_prompt
    case "$default" in
        [Yy]* ) yn_prompt="[Y/n]" ;;
        [Nn]* ) yn_prompt="[y/N]" ;;
        *     ) yn_prompt="[y/n]" ;;
    esac

    local answer
    while true; do
        read -r -p "$question $yn_prompt " answer

        # Handle empty input (just Enter)
        [[ -z "$answer" ]] && answer="$default"

        case "$answer" in
            [Yy]* ) return 0 ;;    # yes → return success (0)
            [Nn]* ) return 1 ;;    # no  → return failure (1)
            *     ) echo "Please answer yes or no." >&2 ;;
        esac
    done
}
cleanup() {
	# === Step 1: Quit debug server and debug process on device ===
	echo "Killing program (PID: $DEBUG_PROGRAM_PID) and debug server (PID: $LLDB_SERVER_PID) on device..."
	adb shell "kill $DEBUG_PROGRAM_PID $LLDB_SERVER_PID"

	# === Step 2: Remove old binaries on device ===
	echo "Removing old binaries on device..."
	adb shell "rm -f $REMOTE_DIR/lldb-server $REMOTE_DIR/$BINARY_NAME"

	# === Step 3: Remove old binaries on host ===
	echo "Removing old binaries on host..."
	ndk-build clean
	rm -rf obj libs

	# === Step 4: Remove port forward ===
	echo "Removing all port forwards in adb..."
	adb forward --remove-all

	# === Step 5: Reboot device ===
	if ask_yes_no "Cleanup complete. Do you want to reboot the device?" "N"; then
		echo "Rebooting device..."
		adb shell "reboot"
	else
		echo "Not rebooting device..."
	fi
}

# === CONFIG ===
PROJECT_DIR="$(pwd)/jni"
BINARY_NAME="poc"
REMOTE_DIR="/data/local/tmp"
PORT="5039"
HOST_LLDB=`which lldb`
REMOTE_LLDB=`find "$ANDROID_NDK_HOME" -name lldb-server | grep aarch64`

# === Step 1: Build with debug symbols ===
echo "Building $BINARY_NAME (debug)..."
ndk-build NDK_DEBUG=1 APP_OPTIM=debug || { echo "Build failed!"; exit 1; }
SYMBOLS_BINARY="obj/local/arm64-v8a/$BINARY_NAME"  # has full debug info

# === Step 2: Push binary and lldb-server to device ===
echo "Pushing $BINARY_NAME and lldb-server to device..."
adb push "$SYMBOLS_BINARY" "$REMOTE_DIR/$BINARY_NAME"
adb push "$REMOTE_LLDB" "$REMOTE_DIR/lldb-server"

# === Step 3: Start lldb-server on device ===
echo "Starting lldb-server on device (will launch poc on attach)..."
adb forward tcp:$PORT tcp:$PORT
adb shell "cd $REMOTE_DIR && ./lldb-server platform --listen *:$PORT --server" &

# === Step 4: Get PID of remote lldb-server ===
echo "Getting PID of lldb-server on device..."
LLDB_SERVER_PID="$(adb shell pidof lldb-server | awk '{print $1}')"
echo "PID: $LLDB_SERVER_PID"

# === Step 5: Launch the program to debug on device ===
echo "Launching $BINARY_NAME on device..."
adb shell "cd $REMOTE_DIR && ./$BINARY_NAME" &

# === Step 6: Get PID of remote program ===
echo "Getting PID of $BINARY_NAME on device..."
DEBUG_PROGRAM_PID="$(adb shell pidof $BINARY_NAME | awk '{print $1}')"
echo "PID: $DEBUG_PROGRAM_PID"

# === Step 7: Launch host lldb, connect, attach ===
echo "Launching LLDB and attaching..."
"$HOST_LLDB" \
  "$SYMBOLS_BINARY" \
  -o "platform select remote-android" \
  -o "platform connect connect://localhost:5039" \
  -o "process attach -p $DEBUG_PROGRAM_PID"

# === Step 8: Cleanup on exit ===
trap cleanup EXIT INT TERM
