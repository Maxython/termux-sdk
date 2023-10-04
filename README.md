# Termux-SDK
Termux-sdk is a script that can install sdk packages using [sdkmanager](https://developer.android.com/tools/sdkmanager) and configure the binaries that are in the packages so that they can run in Termux. Binaries in sdk packages can run in Termux using `box64` from the [glibc-packages](https://github.com/termux-pacman/glibc-packages) repo.

Note that due to the fact that `box64` is used here, termux-sdk is only supported on `arm64` (`aarch64`).

## Installation
```bash
pacman -S python-pip box64-glibc glibc-runner
curl https://raw.githubusercontent.com/Maxython/termux-sdk/main/termux-sdk.sh -o $PREFIX/bin/termux-sdk
chmod +x $PREFIX/bin/termux-sdk
termux-sdk --help
```

## Example of using termux-sdk
```bash
termux-sdk --list # get a list of available sdk packages

termux-sdk "platform-tools" # installing "platform-tools"

$PREFIX/opt/android-sdk/platform-tools/sqlite3 --help
```
