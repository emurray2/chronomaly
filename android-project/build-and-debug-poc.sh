#!/usr/bin/env bash
set -euo pipefail

# Functions
get_device_properties() {
    local serial="$1"
    local app_abi
    local sdk app_platform

    app_abi=$(adb -s "$serial" shell getprop ro.product.cpu.abi 2>/dev/null | tr -d '\r')
    if [[ -z "$app_abi" ]]; then
        echo "Warning: Could not read ro.product.cpu.abi → falling back to arm64-v8a" >&2
        app_abi="arm64-v8a"
    fi
    sdk=$(adb -s "$serial" shell getprop ro.build.version.sdk 2>/dev/null | tr -d '\r')
    if [[ -z "$sdk" || ! "$sdk" =~ ^[0-9]+$ ]]; then
        echo "Warning: Could not read ro.build.version.sdk → defaulting to android-34" >&2
        sdk=34
    fi
    app_platform="android-$sdk"

    echo "$app_abi $app_platform"
}
write_build_files() {
    local serial="$1"
    local app_abi="$2"
    local app_platform="$3"
    local BINARY_NAME="$4"

    mkdir jni
    cd jni
    touch Application.mk
    touch Android.mk
    cd ..

    cat > jni/Application.mk <<EOL
# Generated automatically for device $serial
APP_ABI := $app_abi
APP_PLATFORM := $app_platform
APP_OPTIM := debug
APP_PIE := true
# Optional: for better gdbserver compatibility on older devices
# APP_STL := c++_static   # or system / gnustl_static etc. if needed
EOL

    cat > jni/Android.mk <<EOL
# Generated automatically for device $serial

LOCAL_PATH := \$(call my-dir)

include \$(CLEAR_VARS)
LOCAL_MODULE := $BINARY_NAME
LOCAL_SRC_FILES := ../../exploit.c

# Common flags
LOCAL_CFLAGS += -Wall -Wextra -g -O0
LOCAL_LDFLAGS += -pie

# Define based on detected architecture
ifeq (\$(filter arm64-v8a,\$(APP_ABI)),arm64-v8a)
    LOCAL_CFLAGS += -DARM64
endif
# Add more conditionals if needed, e.g. for armeabi-v7a → -DARMV7 etc.

include \$(BUILD_EXECUTABLE)
EOL

    echo "Files written:"
    ls -l jni/Application.mk jni/Android.mk
}
select_device() {
    # Get raw lines, skip header, only keep "device" lines
    device_lines=()
    while IFS= read -r line; do
        device_lines+=("$line")
        done < <(adb devices -l | awk '
        $2 == "device" {
            serial = $1
            model = "unknown"
            for (i=3; i<=NF; i++) {
                if ($i ~ /^model:/) {
                    sub(/^model:/, "", $i)
                    model = $i
                    break
                }
            }
        print serial " " model
    }')

    if [ ${#device_lines[@]} -eq 0 ]; then
        echo "No devices connected."
        exit 1
    fi

    # Create numbered list for user
        select choice in "${device_lines[@]}"; do
        if [[ -n "$choice" ]]; then
            # Extract serial (first word)
            selected_serial=$(echo "$choice" | awk '{print $1}')
            echo $selected_serial
            # You can now use it, e.g.:
            # adb -s "$selected_serial" shell ...
            break
        else
            echo "Invalid selection, try again."
        fi
    done
}
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
	local serial="$1"
	# === Step 1: Quit debug server and debug process on device ===
	echo "Killing program (PID: $DEBUG_PROGRAM_PID) and debug server (PID: $LLDB_SERVER_PID) on device..."
	adb -s $serial shell "kill $DEBUG_PROGRAM_PID $LLDB_SERVER_PID"

	# === Step 2: Remove old binaries on device ===
	echo "Removing old binaries on device..."
	adb -s $serial shell "rm -f $REMOTE_DIR/lldb-server $REMOTE_DIR/$BINARY_NAME"

	# === Step 3: Remove old binaries on host ===
	echo "Removing old binaries on host..."
	ndk-build clean
	rm -rf obj libs

	# === Step 4: Remove build configs ===
	echo "Removing build configs..."
	rm -rf jni

	# === Step 5: Remove port forward ===
	echo "Removing all port forwards in adb..."
	adb -s $serial forward --remove-all

	# === Step 6: Reboot device ===
	if ask_yes_no "Cleanup complete. Do you want to reboot the device?" "N"; then
		echo "Rebooting device..."
		adb -s $serial shell "reboot"
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

# === Step 0: Generate build config files ===
echo "Generating build config files..."
echo Select a device:
serial=$(select_device)
if [[ -z "$serial" ]]; then
    echo "No device selected or no devices connected."
    exit 1
fi
echo "Selected device: $serial"
echo "Querying device properties..."
read -r app_abi app_platform <<< "$(get_device_properties $serial)"
echo "Detected values:"
echo "  APP_ABI     = $app_abi"
echo "  APP_PLATFORM = $app_platform"
write_build_files $serial $app_abi $app_platform $BINARY_NAME

# === Step 1: Build with debug symbols ===
echo "Building $BINARY_NAME (debug)..."
ndk-build NDK_DEBUG=1 APP_OPTIM=debug || { echo "Build failed!"; exit 1; }
SYMBOLS_BINARY="obj/local/arm64-v8a/$BINARY_NAME"  # has full debug info

# === Step 2: Push binary and lldb-server to device ===
echo "Pushing $BINARY_NAME and lldb-server to device..."
adb -s $serial push "$SYMBOLS_BINARY" "$REMOTE_DIR/$BINARY_NAME"
adb -s $serial push "$REMOTE_LLDB" "$REMOTE_DIR/lldb-server"

# === Step 3: Start lldb-server on device ===
echo "Starting lldb-server on device (will launch poc on attach)..."
adb -s $serial shell "cd $REMOTE_DIR && ./lldb-server platform --listen *:$PORT --server" &

# === Step 4: Get PID of remote lldb-server ===
echo "Getting PID of lldb-server on device..."
LLDB_SERVER_PID="$(adb -s $serial shell pidof lldb-server | awk '{print $1}')"
echo "PID: $LLDB_SERVER_PID"

# === Step 5: Launch the program to debug on device ===
echo "Launching $BINARY_NAME on device..."
adb -s $serial shell "cd $REMOTE_DIR && ./$BINARY_NAME" &

# === Step 6: Get PID of remote program ===
echo "Getting PID of $BINARY_NAME on device..."
DEBUG_PROGRAM_PID="$(adb -s $serial shell pidof $BINARY_NAME | awk '{print $1}')"
echo "PID: $DEBUG_PROGRAM_PID"

# === Step 7: Launch host lldb, connect, attach ===
echo "Launching LLDB and attaching..."
"$HOST_LLDB" \
  "$SYMBOLS_BINARY" \
  -o "platform select remote-android" \
  -o "platform connect connect://$serial:5039" \
  -o "process attach -p $DEBUG_PROGRAM_PID"

# === Step 8: Cleanup on exit ===
trap 'cleanup $serial' EXIT INT TERM
