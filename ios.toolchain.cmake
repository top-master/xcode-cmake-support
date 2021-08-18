cmake_minimum_required(VERSION 3.19)

#
# Usage; set PLATFORM_NAME, and ARCHS environment-variables (with valid values),
# or instead, pass command-line like "-D PLATFORM_NAME=iosmac" (without quotes).
#
# Valid values (listed in PLATFORM_NAME = ARCHS format), example:
# ```
# iphoneos = arm64
# iosmac = x86_64
# ```
#
# Note that iosmac means Mac's Catalyst target.
#
# -------===-------
#
# Optionally, pass "-D XCODE_BITCODE=true" to force enabling BitCode.
#
# BitCode or LLVM-intermediate-binary allows Apple's servers to recompile App
# (for different architectures without our involvement, or source-code),
# and is disabled to prevent security-leak, except for watchOS and tvOS.
#
# Because for watchOS and tvOS apps, bitcode is required
# (as watch and tv are not restricted to Apple's choice of CPU).
#

if (NOT DEFINED IOS_TOOLCHAIN_INCLUDED)
set (IOS_TOOLCHAIN_INCLUDED TRUE)



# Function-Override and Macros.
#

# Helper for setting XCode specific properties.
# Example:
# ```
# xcode_build_settings(myLib GCC_GENERATE_DEBUGGING_SYMBOLS YES)
# ```
macro (xcode_build_settings TARGET NAME VALUE)
    set_property (TARGET ${TARGET} PROPERTY "XCODE_ATTRIBUTE_${NAME}" "${VALUE}")
endmacro()

# Helpers for logging in Xcode's "Issue navigator" format.
# Usage:
# ```
# xcode_warn(
#     "Hellp World!"
#     ${CMAKE_CURRENT_LIST_LINE}
# )
# ```
macro(xcode_warn text line)
    message("${CMAKE_CURRENT_LIST_DIR}/CMakeLists.txt:${line}:1: warning: ${text}")
endmacro()
macro(xcode_fail text line)
    message("${CMAKE_CURRENT_LIST_DIR}/CMakeLists.txt:${line}:1: error: ${text}")
endmacro()
macro(xcode_error text line)
    message("${CMAKE_CURRENT_LIST_DIR}/CMakeLists.txt:${line}:1: error: ${text}")
    message(FATAL_ERROR "Can not continue after previous error!")
endmacro()



# Platform type.
#

set (APPLE TRUE)
set (IOS TRUE)
set (UNIX TRUE)

# Skip compiler checks and enable cross-compile.
#set (CMAKE_C_COMPILER_WORKS TRUE)
#set (CMAKE_CXX_COMPILER_WORKS TRUE)
set (CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)
set (CMAKE_CROSSCOMPILING TRUE)

set (CMAKE_DL_LIBS "")
set (CMAKE_MODULE_EXISTS 1)

set (CMAKE_FIND_LIBRARY_SUFFIXES ".dylib" ".so" ".a")
set (CMAKE_SHARED_LIBRARY_PREFIX "lib")
set (CMAKE_SHARED_LIBRARY_SUFFIX ".dylib")
set (CMAKE_SHARED_MODULE_PREFIX "lib")
set (CMAKE_SHARED_MODULE_SUFFIX ".so")

set (CMAKE_SYSTEM_NAME "Darwin" CACHE STRING "Target system.")
set (CMAKE_SYSTEM_VERSION 1)

find_program (_TMP uname /bin /usr/bin /usr/local/bin)
if (_TMP)
    exec_program ("${_TMP}" ARGS -r OUTPUT_VARIABLE CMAKE_HOST_SYSTEM_VERSION)
    # Removes minor version (keeping only major).
    string (REGEX REPLACE "^([0-9]+).*$" "\\1"
            CMAKE_HOST_MAJOR_VERSION "${CMAKE_HOST_SYSTEM_VERSION}")
endif()

if (NOT DEFINED PLATFORM_NAME)
    set (PLATFORM_NAME "$ENV{PLATFORM_NAME}")
endif()
# Commented to ensure we get nice error (as file-names are case-sensitive).
#string (TOLOWER "${PLATFORM_NAME}" PLATFORM_NAME)

# Device-Type.
if (PLATFORM_NAME STREQUAL "iosmac" OR PLATFORM_NAME STREQUAL "macosx")
    set (DEVICE_TYPE "MacOSX")
elseif (PLATFORM_NAME STREQUAL "iphoneos")
    set (DEVICE_TYPE "iPhoneOS")
    #set (CPU_ARCH armv7;armv7s;arm64)
elseif (PLATFORM_NAME STREQUAL "iphonesimulator")
    set (DEVICE_TYPE "iPhoneSimulator")
    #set (CPU_ARCH i386;x86_64)
elseif (PLATFORM_NAME STREQUAL "appletvos")
    set (DEVICE_TYPE "AppleTVOS")
    set (XCODE_BITCODE true)
elseif (PLATFORM_NAME STREQUAL "appletvsimulator")
    set (DEVICE_TYPE "AppleTVSimulator")
    set (XCODE_BITCODE true)
elseif (PLATFORM_NAME STREQUAL "watchos")
    set (DEVICE_TYPE "WatchOS")
    set (XCODE_BITCODE true)
elseif (PLATFORM_NAME STREQUAL "watchsimulator")
    set (DEVICE_TYPE "WatchSimulator")
    set (XCODE_BITCODE true)
else()
    xcode_error ("Unknown PLATFORM_NAME => \"${PLATFORM_NAME}\","
        " define environment-variable (or pass -D PLATFORM_NAME=iphoneos)"
        ${CMAKE_CURRENT_LIST_LINE})
endif()



# SDK.
#

# Resolves "/Applications/Xcode.app/Contents/Developer" path.
if (NOT DEFINED XCODE_BUNDLE)
    exec_program (/usr/bin/xcode-select ARGS -print-path OUTPUT_VARIABLE XCODE_BUNDLE)
endif()
set (XCODE_BUNDLE "${XCODE_BUNDLE}" CACHE PATH "Xcode Developer Materials")

if (NOT DEFINED PLATFORM_BUNDLE)
    set (PLATFORM_BUNDLE "${XCODE_BUNDLE}/Platforms/${DEVICE_TYPE}.platform/Developer")
endif()
set (PLATFORM_BUNDLE "${PLATFORM_BUNDLE}" CACHE PATH "iOS Platform Materials")

if (NOT DEFINED PLATFORM_SDK)
    set (PLATFORM_SDK "${PLATFORM_BUNDLE}/SDKs/${DEVICE_TYPE}.sdk")
    if (NOT EXISTS "${PLATFORM_SDK}")
        xcode_error ("Failed to find SDK in ${PLATFORM_SDK}."
            " Set PLATFORM_SDK manually."
            ${CMAKE_CURRENT_LIST_LINE})
    endif()
endif()
set (PLATFORM_SDK "${PLATFORM_SDK}" CACHE PATH "SDK chosen")
set (CMAKE_OSX_SYSROOT "${PLATFORM_SDK}" CACHE PATH "For iOS, Sysroot is same as SDK-root")

# Load CMAKE_OSX_ARCHITECTURES from SDK's JSON definition.
file (READ "${PLATFORM_SDK}/SDKSettings.json" XCODE_SDK_JSON)
string (JSON CPU_ARCH GET "${XCODE_SDK_JSON}" SupportedTargets ${PLATFORM_NAME} Archs)
string (JSON CPU_ARCH_COUNT LENGTH "${CPU_ARCH}")
if (CPU_ARCH_COUNT LESS 1)
    xcode_error ("Failed to find architectures list"
        " in file \"${PLATFORM_SDK}/SDKSettings.json\""
        ${CMAKE_CURRENT_LIST_LINE})
endif()
foreach (ID RANGE MATH(EXPR VAR "${CPU_ARCH_COUNT} - 1"))
    string (JSON _TMP GET ${CPU_ARCH} ${ID})
    list (APPEND CMAKE_OSX_ARCHITECTURES ${_TMP})
endforeach()
list (REMOVE_DUPLICATES CMAKE_OSX_ARCHITECTURES)

# Validate JSON matches Xcode-settings (those passed in environment).
if (NOT DEFINED ARCHS)
    set (ARCHS "$ENV{ARCHS}")
endif()
if (NOT ARCHS MATCHES "^\\s*$")
    string (REPLACE " " ";" ARCHS "${ARCHS}")
    foreach (ID IN LISTS CMAKE_OSX_ARCHITECTURES)
        if (NOT ID IN_LIST ARCHS)
            xcode_warn (
                "Xcode's ARCHS environment-variable forced override"
                " (of the SDK default: '${CMAKE_OSX_ARCHITECTURES}')"
                ${CMAKE_CURRENT_LIST_LINE}
            )
            set (CMAKE_OSX_ARCHITECTURES ${ARCHS})
            break()
        endif()
    endforeach()
endif()
set (CMAKE_OSX_ARCHITECTURES "${CMAKE_OSX_ARCHITECTURES}" CACHE STRING "CPU architecture")



# Override CMake defaults.
#

if (NOT CMAKE_MAKE_PROGRAM)
    # Using path-constant till Apple fixes taking more than 30 seconds to run:
    # exec_program("xcodebuild" ARGS -find make OUTPUT_VARIABLE CMAKE_MAKE_PROGRAM)
    set (CMAKE_MAKE_PROGRAM "${XCODE_BUNDLE}/usr/bin/make")
    if (NOT EXISTS CMAKE_MAKE_PROGRAM)
        set (CMAKE_MAKE_PROGRAM "make")
    endif()
endif()
set (CMAKE_MAKE_PROGRAM "${CMAKE_MAKE_PROGRAM}" CACHE INTERNAL "" FORCE)

if (NOT DEFINED CMAKE_C_COMPILER)
    set (CMAKE_C_COMPILER "${XCODE_BUNDLE}/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang")
    if (NOT EXISTS CMAKE_C_COMPILER)
        find_program (CMAKE_C_COMPILER clang /bin /usr/bin /usr/local/bin)
    endif()
endif()
set (CMAKE_C_COMPILER "${CMAKE_C_COMPILER}" CACHE FILEPATH "" FORCE)

if (NOT DEFINED CMAKE_CXX_COMPILER)
    set (CMAKE_CXX_COMPILER "${XCODE_BUNDLE}/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang++")
    if (NOT EXISTS CMAKE_CXX_COMPILER)
        find_program (CMAKE_CXX_COMPILER clang++ /bin /usr/bin /usr/local/bin)
    endif()
endif()
set (CMAKE_CXX_COMPILER "${CMAKE_CXX_COMPILER}" CACHE FILEPATH "" FORCE)

set (CMAKE_AR "${XCODE_BUNDLE}/Toolchains/XcodeDefault.xctoolchain/usr/bin/ar" CACHE FILEPATH "" FORCE)
set (CMAKE_RANLIB "${XCODE_BUNDLE}/Toolchains/XcodeDefault.xctoolchain/usr/bin/ranlib" CACHE FILEPATH "" FORCE)
# Undo iOS deployment target (set since CMake 2.8.10).
set (CMAKE_OSX_DEPLOYMENT_TARGET "" CACHE STRING "" FORCE)



# Target system's architecture (or device) definition.
#

if (NOT DEFINED PLATFORM_ARCH)
    list (GET CMAKE_OSX_ARCHITECTURES 0 PLATFORM_ARCH)
    if (DEFINED ENV{PLATFORM_PREFERRED_ARCH})
        if ("$ENV{PLATFORM_PREFERRED_ARCH}" IN_LIST CMAKE_OSX_ARCHITECTURES)
            set (PLATFORM_ARCH "$ENV{PLATFORM_PREFERRED_ARCH}")
        else()
            xcode_error ("Invalid PLATFORM_PREFERRED_ARCH environment-variable"
                " => \"$ENV{PLATFORM_PREFERRED_ARCH}\""
                " - available-archs: \"${CMAKE_OSX_ARCHITECTURES}\""
                ${CMAKE_CURRENT_LIST_LINE})
        endif()
    endif()
endif()
set (PLATFORM_ARCH "${PLATFORM_ARCH}" CACHE STRING "")

if (NOT DEFINED CMAKE_SYSTEM_PROCESSOR)
    set (CMAKE_SYSTEM_PROCESSOR "${PLATFORM_ARCH}")
    if (CMAKE_SYSTEM_PROCESSOR MATCHES "^arm64")
        set (CMAKE_SYSTEM_PROCESSOR "aarch64")
    endif()
endif()
set (CMAKE_SYSTEM_PROCESSOR "${CMAKE_SYSTEM_PROCESSOR}" CACHE STRING "")

# Ensures CMAKE_INSTALL_LIBDIR gets automatically set.
if (NOT DEFINED CMAKE_SIZEOF_VOID_P)
    set (CMAKE_SIZEOF_VOID_P 8)
    if (CMAKE_SYSTEM_PROCESSOR STREQUAL "armv7")
        set (CMAKE_SIZEOF_VOID_P 4)
    elseif (CMAKE_SYSTEM_PROCESSOR MATCHES "(^i.86$)")
        set (CMAKE_SIZEOF_VOID_P 4)
    endif()
endif()
set (CMAKE_SIZEOF_VOID_P "${CMAKE_SIZEOF_VOID_P}" CACHE STRING "")



# Flags (same as "add_link_options(...)" call).
#

# CMAKE_STATIC_LINKER_FLAGS CMAKE_SHARED_LINKER_FLAGS CMAKE_EXE_LINKER_FLAGS

if (PLATFORM_NAME STREQUAL "iosmac")
    set (CMAKE_C_FLAGS
        -target ${PLATFORM_ARCH}-apple-ios13.6-macabi
        -miphoneos-version-min=13.6
        -isystem    "${PLATFORM_SDK}/System/iOSSupport/usr/include"
        -iframework "${PLATFORM_SDK}/System/iOSSupport/System/Library/Frameworks"
    )
elseif (PLATFORM_NAME STREQUAL "iphoneos")
    set (CMAKE_C_FLAGS
        -target ${PLATFORM_ARCH}-apple-ios13.6 # arm-apple-darwin
        -miphoneos-version-min=13.6
    )
elseif (PLATFORM_NAME STREQUAL "iphonesimulator")
    set (CMAKE_C_FLAGS
        -target ${PLATFORM_ARCH}-apple-ios13.6-simulator
        -mios-simulator-version-min=13.6
    )
elseif (PLATFORM_NAME STREQUAL "macosx")
    set (CMAKE_C_FLAGS
        -target ${PLATFORM_ARCH}-apple-macosx10.15
        -mmacosx-version-min=10.15
    )
elseif (PLATFORM_NAME STREQUAL "appletvos")
    set (CMAKE_C_FLAGS
        -target ${PLATFORM_ARCH}-apple-tvos13.4
        -mappletvos-version-min=13.4
    )
elseif (PLATFORM_NAME STREQUAL "appletvsimulator")
    set (CMAKE_C_FLAGS
        -target ${PLATFORM_ARCH}-apple-tvos13.4
        -mappletvsimulator-version-min=13.4
    )
elseif (PLATFORM_NAME STREQUAL "watchos")
    set (CMAKE_C_FLAGS
        -target ${PLATFORM_ARCH}-apple-watchos6.2
        -mwatchos-version-min=6.2
    )
elseif (PLATFORM_NAME STREQUAL "watchsimulator")
    set (CMAKE_C_FLAGS
        -target ${PLATFORM_ARCH}-apple-watchos6.2
        -mwatchsimulator-version-min=6.2
    )
endif()

if (XCODE_BITCODE)
    # Speeds up compile by asking linker to handle embedding (stores info required).
    set (CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fembed-bitcode-marker")
endif()

set (CMAKE_C_FLAGS ${CMAKE_C_FLAGS}
    -fmessage-length=0 -fmacro-backtrace-limit=0
    -DOBJC_OLD_DISPATCH_PROTOTYPES=0
    -Wnon-modular-include-in-framework-module -Werror=non-modular-include-in-framework-module
    -Werror=partial-availability
    -fapplication-extension
    -fpascal-strings
    -fno-common
    -fasm-blocks -fstrict-aliasing
)

# Simply inherits (possible because Obj-C is just extending C-language),
# other possible options: -rewrite-objc
# -fdiagnostics-show-note-include-stack -fcoverage-mapping
#
set (CMAKE_OBJC_FLAGS
    ${CMAKE_C_FLAGS}
    -fobjc-arc -fobjc-weak
    -fmodules
    #-fmodules-cache-path=/Users/admin/Library/Developer/Xcode/DerivedData/ModuleCache.noindex
    #-fmodules-prune-interval=86400
    #-fmodules-prune-after=345600
    #-fbuild-session-file=/Users/admin/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/Session.modulevalidation
    #-fmodules-validate-once-per-build-session
)
set (CMAKE_OBJCXX_FLAGS ${CMAKE_OBJC_FLAGS} -fcxx-modules)

# Maybe add -fprofile-instr-generate (to enable Code-Coverage),
# but that forces turning on the same setting in Xcode's scheme,
# like, Edit Scheme -> Test -> Options -> Code Coverage.
set (CMAKE_OBJC_FLAGS_DEBUG -gmodules -O0)
set (CMAKE_OBJCXX_FLAGS_DEBUG ${CMAKE_OBJC_FLAGS_DEBUG})

set (CMAKE_C_FLAGS
    ${CMAKE_C_FLAGS}
    # Enables Hidden-visibilty for C++ (required by iOS).
    -fvisibility=hidden -fvisibility-inlines-hidden
    # Other.
    #-Wl,-search_paths_first -Wl,-headerpad_max_install_name
)

set (CMAKE_CXX_FLAGS
    ${CMAKE_C_FLAGS}
    -stdlib=libc++ -std=c++11
)

# Converts above defined arrays to strings.
string (REPLACE ";" " " CMAKE_C_FLAGS "${CMAKE_C_FLAGS}")
string (REPLACE ";" " " CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS}")
string (REPLACE ";" " " CMAKE_OBJC_FLAGS "${CMAKE_OBJC_FLAGS}")
string (REPLACE ";" " " CMAKE_OBJCXX_FLAGS "${CMAKE_OBJCXX_FLAGS}")
string (REPLACE ";" " " CMAKE_OBJC_FLAGS_DEBUG "${CMAKE_OBJC_FLAGS_DEBUG}")
string (REPLACE ";" " " CMAKE_OBJCXX_FLAGS_DEBUG "${CMAKE_OBJCXX_FLAGS_DEBUG}")

set (CMAKE_C_OSX_COMPATIBILITY_VERSION_FLAG "-compatibility_version ")
set (CMAKE_C_OSX_CURRENT_VERSION_FLAG "-current_version ")
set (CMAKE_CXX_OSX_COMPATIBILITY_VERSION_FLAG "${CMAKE_C_OSX_COMPATIBILITY_VERSION_FLAG}")
set (CMAKE_CXX_OSX_CURRENT_VERSION_FLAG "${CMAKE_C_OSX_CURRENT_VERSION_FLAG}")

set (CMAKE_PLATFORM_HAS_INSTALLNAME 1)
if (NOT DEFINED CMAKE_INSTALL_NAME_TOOL)
    find_program (CMAKE_INSTALL_NAME_TOOL install_name_tool)
endif()
set (CMAKE_SHARED_LIBRARY_CREATE_C_FLAGS "-dynamiclib -headerpad_max_install_names")
set (CMAKE_SHARED_MODULE_CREATE_C_FLAGS "-bundle -headerpad_max_install_names")
set (CMAKE_SHARED_MODULE_LOADER_C_FLAG "-Wl,-bundle_loader")
set (CMAKE_SHARED_MODULE_LOADER_CXX_FLAG "-Wl,-bundle_loader")



# Search paths.
#

set (CMAKE_FIND_ROOT_PATH "${PLATFORM_BUNDLE} ${PLATFORM_SDK} ${CMAKE_PREFIX_PATH}" CACHE STRING  "iOS search-paths")

# Limits searchs to directories set above (excluding other host filesystem).
set (CMAKE_FIND_ROOT_PATH_MODE_PROGRAM ONLY)
set (CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set (CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

# Allows finding package in host-system (outside of iOS's SDK search-paths).
macro (find_host_package)
    set (IOS FALSE)
    set (CMAKE_FIND_ROOT_PATH_MODE_INCLUDE NEVER)
    set (CMAKE_FIND_ROOT_PATH_MODE_LIBRARY NEVER)
    set (CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)

    find_package (${ARGN})

    set (CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
    set (CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
    set (CMAKE_FIND_ROOT_PATH_MODE_PROGRAM ONLY)
    set (IOS TRUE)
endmacro()

# Ensure searching for frameworks first.
set (CMAKE_FIND_FRAMEWORK FIRST)

# Default directory-list for framework searchs.
set (CMAKE_SYSTEM_FRAMEWORK_PATH
    ${PLATFORM_SDK}/System/Library/Frameworks
    ${PLATFORM_SDK}/System/Library/PrivateFrameworks
    ${PLATFORM_SDK}/Developer/Library/Frameworks
)

endif() # IOS_TOOLCHAIN_INCLUDED
