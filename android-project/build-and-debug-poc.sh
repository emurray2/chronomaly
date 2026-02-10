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
echo "Building poc (debug)..."
ndk-build NDK_DEBUG=1 APP_OPTIM=debug || { echo "Build failed!"; exit 1; }
LOCAL_BINARY="libs/arm64-v8a/$BINARY_NAME"
SYMBOLS_BINARY="obj/local/arm64-v8a/$BINARY_NAME"  # has full debug info
if [[ ! -f "$LOCAL_BINARY" ]]; then
  echo "Binary not found at $LOCAL_BINARY"; exit 1;
fi

# === Step 2: Push binary and lldb-server to device ===
echo "Pushing $BINARY_NAME and lldb-server to device..."
adb push "$LOCAL_BINARY" "$REMOTE_DIR/$BINARY_NAME"
adb push "$REMOTE_LLDB"	"$REMOTE_DIR/lldb-server"

# === Step 3: Start lldb-server on device in "launch on attach" mode ===
adb forward tcp:"$PORT" tcp:"$PORT"
echo "Starting lldb-server on device (will launch poc on attach)..."
adb shell "cd $REMOTE_DIR && ./lldb-server g :$PORT -- ./$BINARY_NAME" &

# === Step 4: Launch host lldb, connect, attach ===
SERVER_PID=$!
sleep 2  # give it time to start/listen
# Check if server running
if ! adb shell ps | grep -q lldb-server; then
  echo "lldb-server failed to start! Check adb logcat."
  exit 1
fi
echo "Launching LLDB and attaching..."
"$HOST_LLDB" \
  "$SYMBOLS_BINARY" \
  -o "gdb-remote localhost:$PORT"

# Cleanup function
cleanup() {
    echo "Cleaning up debug session..."

    # Remove old binaries
    adb shell "rm -f $REMOTE_DIR/lldb-server $REMOTE_DIR/$BINARY_NAME"

    # Remove port forward
    adb forward --remove tcp:"$PORT" 2>/dev/null

    echo "Cleanup complete."
}

# === Step 5: Cleanup on exit ===
trap cleanup EXIT INT TERM
