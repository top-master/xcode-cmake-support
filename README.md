# CMake support for Xcode,

Implements toolchain for `CMake` ("CeeMake"),<br>
which supports `iOS`, Mac's `Catalyst` and maybe `tvOS` and `watchOS` targets<br>
(not tested, but they should work as well).

## cmake-ios-toolchain
Let's appreciate that the example demonstrates running CeeMake directly from ExCode<br>
(and this does not just add EyeOhEss support into CeeMake).

# Why?
Because even in 2021, CeeMake still does not have built-in support.

Also, I just did NOT want to use CeeMake's generate-project feature (and then modify result into `iOS` version).
Basically, that would break the whole point of using CeeMake in the first place! (which was editing a single script to update all platforms).
