# Termux-SDK
Termux-sdk is a script that can install sdk packages using [sdkmanager](https://developer.android.com/tools/sdkmanager) and configure the binaries that are in the packages so that they can run in Termux. Binaries in sdk packages can run in Termux using `box64` from the [glibc-packages](https://github.com/termux-pacman/glibc-packages) repo.

Note that due to the fact that `box64` is used here, termux-sdk is only supported on `arm64` (`aarch64`).

## Installation
```bash
# If you use apt as your main package manager in Termux, you need to access the glibc packages before installing
pkg install glibc-repo -y

# Installing the required packages and termux-sdk script
yes | pkg install python-pip box64-glibc glibc-runner
curl https://raw.githubusercontent.com/Maxython/termux-sdk/main/termux-sdk.sh -o $PREFIX/bin/termux-sdk
chmod +x $PREFIX/bin/termux-sdk

# Enjoy
termux-sdk --help
```

## Example of using termux-sdk
```bash
# Getting a list of available sdk packages
termux-sdk --list

# Installing the sdk package "platform-tools" and using one of its programs
termux-sdk "platform-tools"
$PREFIX/opt/android-sdk/platform-tools/sqlite3 --help
```
