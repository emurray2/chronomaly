#!/usr/bin/env bash
set -euo pipefail

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

# === Step 4: Launch the program to debug on device
echo "Launching $BINARY_NAME on device"
adb shell "cd $REMOTE_DIR && ./$BINARY_NAME" &

# === Step 5: Get PID of remote program ===
echo "Getting PID of $BINARY_NAME on device"
DEBUG_PROGRAM_PID="$(adb shell pidof $BINARY_NAME | awk '{print $1}')"

# === Step 6: Launch host lldb, connect, attach ===
echo "Launching LLDB and attaching..."
"$HOST_LLDB" \
  "$SYMBOLS_BINARY" \
  -o "platform select remote-android" \
  -o "platform connect connect://localhost:5039" \
  -o "process attach -p $DEBUG_PROGRAM_PID"

# Cleanup function
cleanup() {
    echo "Cleaning up debug session..."

    # Remove old binaries
    adb shell "rm -f $REMOTE_DIR/lldb-server $REMOTE_DIR/$BINARY_NAME"

	# On host side too
	ndk-build clean
	rm -rf obj libs

    # Remove port forward
    adb forward --remove-all

    echo "Cleanup complete."
}

# === Step 5: Cleanup on exit ===
trap cleanup EXIT INT TERM
