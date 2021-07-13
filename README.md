# cmake-ios-toolchain

Implements toolchain for `CMake` ("CeeMake"),<br>
which supports `iOS`, Mac's `Catalyst` and maybe `tvOS` and `watchOS` targets<br>
(not tested, but they should work as well).

Let's appreciate that this does not just add EyeOhEss support to CeeMake,<br>
and the example also demonstrates running CMake directly from ExCode.

# Why?
Because even in 2021, CeeMake still does not have built-in support.

Also, I just did NOT want to use CeeMake's generate-project feature (and then modify result into `iOS` version).
Basically, that would break to whole point of using CeeMake in the first place! (which was reusing same script to compile on multiple platforms).
