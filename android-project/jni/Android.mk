LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

LOCAL_MODULE := poc
LOCAL_SRC_FILES := ../../exploit.c

# Equivalent to -DARM64 from your command
LOCAL_CFLAGS += -DARM64

# Target modern Android API level (matches your android34-clang)
# Meta Quest devices typically need at least android-23 or higher;
# android-34 is fine if your NDK supports it.
LOCAL_SDK_VERSION := 34   # or use APP_PLATFORM in Application.mk instead

# Very important for executables you want to run from adb shell
LOCAL_LDFLAGS += -pie

# Debugging: include debug info suitable for GDB
LOCAL_CFLAGS   += -g -O0
# Optional: add line numbers, better backtraces
# LOCAL_CFLAGS   += -fno-omit-frame-pointer

# Optional: turn on common warnings
LOCAL_CFLAGS   += -Wall -Wextra

# If you need extra headers or libraries, add them here, e.g.:
# LOCAL_C_INCLUDES += path/to/extra/headers
# LOCAL_LDLIBS     += -llog   # if you use __android_log_print

include $(BUILD_EXECUTABLE)
