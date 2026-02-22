# The code labeled 'exploit.c' located at the root of this repository may circumvent certain technological protection measures if used improperly and is provided strictly under the narrow DMCA exemption for interoperability/software removal on lawfully owned devices (37 C.F.R. § 201.40(b)(9), effective as of October 28, 2024) (https://www.ecfr.gov/current/title-37/part-201/section-201.40#p-201.40(b)(9)), as well as in compliance with the Computer Fraud and Abuse Act (18 U.S.C. § 1030) (https://www.justice.gov/jm/jm-9-48000-computer-fraud)
# By viewing, downloading, modifying, or redistributing this repository, you agree to the terms set forth in the file 'DISCLAIMER.md' at the root of this repository
# Use of this software is at your own risk, may brick your device, void warranties, and must comply with all applicable laws in your jurisdiction (including outside the US, where no DMCA exemption applies).
# This project is for personal, non-commercial research and experimentation only.

exec ~/Library/Android/sdk/ndk/26.1.10909125/toolchains/llvm/prebuilt/darwin-x86_64/bin/aarch64-linux-android34-clang -o chronomaly -DARM64 exploit.c
