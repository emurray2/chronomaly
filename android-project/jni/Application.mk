APP_ABI := arm64-v8a          # only build for aarch64 (Meta Quest)

APP_PLATFORM := android-34    # matches your clang version / API level

# Very useful for debugging
APP_OPTIM := debug

# Optional but recommended for gdbserver compatibility
APP_PIE := true
