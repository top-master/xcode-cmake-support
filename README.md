# CMake support for Xcode,

Implements toolchain for `CMake` (CeeMake),<br>
which supports `iOS` (EyeOhEss), Mac's `Catalyst` and `MacOS` targets fully,<br>
but `tvOS` and `watchOS` targets should work as well (I mean, just not tested).

## cmake-ios-toolchain
Let's appreciate that the example demonstrates running CMake directly from `Xcode`<br>
(and this does not just add iOS support into CMake).

# Why?
Because even in 2021, CMake still does not have built-in support.

Also, I just did NOT want to use CMake's generate-project feature (and then modify result into `iOS` version).
Basically, that would break the whole point of using CMake in the first place! (which was editing a single script to update all platforms).
