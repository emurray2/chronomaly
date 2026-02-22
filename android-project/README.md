# LEGAL NOTICE

[exploit.c](../exploit.c) may circumvent certain technological protection measures if used improperly and is provided **strictly** under the narrow DMCA exemption for interoperability/software removal on lawfully owned devices (37 C.F.R. § 201.40(b)(9), effective as of October 28, 2024) [https://www.ecfr.gov/current/title-37/part-201/section-201.40#p-201.40(b)(9)](https://www.ecfr.gov/current/title-37/part-201/section-201.40#p-201.40(b)(9)), as well as in compliance with the Computer Fraud and Abuse Act (18 U.S.C. § 1030) [https://www.justice.gov/jm/jm-9-48000-computer-fraud](https://www.justice.gov/jm/jm-9-48000-computer-fraud)

By viewing, downloading, modifying, or redistributing this repository, you agree to the terms set forth in [DISCLAIMER.md](../DISCLAIMER.md).

Use of this software is at your own risk, may brick your device, void warranties, and must comply with all applicable laws in your jurisdiction (including outside the US, where no DMCA exemption applies).

# Android project (for easy building)

## Step 1 Download development utilities:

### ADB (Android Debug Bridge)
`sudo apt install android-sdk-platform-tools-common`

### Android NDK (Native Development Kit)
Download here: [https://developer.android.com/ndk/downloads](https://developer.android.com/ndk/downloads)

### LLDB (Low Level Debugger)
`sudo apt install lldb`

Tip: **If some packages are not found a Google search or using an alternative package manager or platform to obtain packages, such as Homebrew ([https://brew.sh/](https://brew.sh/) - macOS) or WSL ([https://learn.microsoft.com/en-us/windows/wsl/install](https://learn.microsoft.com/en-us/windows/wsl/install) - Windows) may suffice**

Additional tip: _Missing packages can often be found on Debian systems using `apt search foo` or `apt search bar`. A similar approach may be applied to any package manager. Run the package manager with the `--help` flag or `-h` to see if a search command is possible._

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

You will be asked to select any connected devices or emulators. Then if everything else was successful, you should see a window with LLDB open up showing the program in a paused state. You can type `continue` and press ENTER to continue the program or enter other commands for debugging. Running `quit` will stop the program (if it hasn't already crashed lol) and the debugger.
