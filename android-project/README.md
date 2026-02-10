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
Run `./build-and-debug-poc.sh` from this folder

You should see a window with LLDB open up. You can type `continue` and press ENTER to continue the program or enter other commands for debugging. Running `quit` will stop the program (if it hasn't already crashed lol) and the debugger.
