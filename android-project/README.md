# Android project (for easy building)

## Step 1:
Download NDK: [https://developer.android.com/ndk/downloads](https://developer.android.com/ndk/downloads)

## Step 2:
Edit your path (i.e. `.zshrc` or `.bashrc`) to point to the NDK

```sh
# Last 2 lines of ~/.zshrc on my Mac
export ANDROID_NDK_HOME=/Users/evanmurray/NDK
export PATH=$ANDROID_NDK_HOME:$PATH
```

If you're in an active terminal session, you can run `source ~/.zshrc` or `source ~/.bashrc` to reload the file which updates the environment variables.

## Step 3:
Run `ndk-build NDK_DEBUG=1` from this folder

## Step 4:
Push to device: `adb push libs/arm64-v8a/poc /data/local/tmp/poc`

## Step 5:
Launch shell: `adb shell`

## Step 6:
Go to folder: `cd /data/local/tmp`

## Step 7:
Run the program: `./poc`
