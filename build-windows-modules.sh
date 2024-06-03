#!/usr/bin/env bash

set -eu

# List of solution configurations to build.
# Default configurations generated by Visual Studio are "Release" and "Debug".
CPP_BUILD_MODES=${CPP_BUILD_MODES:-"Debug"}
# List of target platforms to build for.
# Common platforms include "x86" and "x64".
CPP_BUILD_TARGETS=${CPP_BUILD_TARGETS:-"x64"}

IS_RELEASE=${IS_RELEASE:-"false"}

function clean_solution {
    local path="$1"

    if [[ "$IS_RELEASE" == "true" ]]; then
        # Clean all intermediate and output files
        rm -r "${path:?}/bin/"* || true
    else
        echo "Will NOT clean intermediate files in $path/bin/ in dev builds"
    fi
}

function build_solution_config {
    local sln="$1"
    local config="$2"
    local platform="$3"

    set -x
    cmd.exe "/c msbuild.exe /m $(to_win_path "$sln") /p:Configuration=$config /p:Platform=$platform"
    set +x
}

# Builds visual studio solution in all (specified) configurations
function build_solution {
    local path="$1"
    local sln="$1/$2"

    clean_solution "$path"

    for mode in $CPP_BUILD_MODES; do
        for target in $CPP_BUILD_TARGETS; do
            build_solution_config "$sln" "$mode" "$target"
        done
    done
}

function to_win_path {
    local unixpath="$1"
    # if it's a relative path and starts with a dot (.), don't transform the
    # drive prefix (/c/ -> C:\)
    if echo "$unixpath" | grep '^\.' >/dev/null; then
        echo "$unixpath" | sed -e 's/^\///' -e 's/\//\\/g'
    # if it's an absolute path, transform the drive prefix
    else
        # remove the cygrdive prefix if it's there
        unixpath=$(echo "$unixpath" | sed -e 's/^\/cygdrive//')
        echo "$unixpath" | sed -e 's/^\///' -e 's/\//\\/g' -e 's/^./\0:/'
    fi
}

function get_solution_output_path {
    local solution_root="$1"
    local build_target="$2"
    local build_mode="$3"

    case $build_target in
        "x86") echo "$solution_root/bin/Win32-$build_mode";;
        "x64") echo "$solution_root/bin/x64-$build_mode";;
        "ARM64") echo "$solution_root/bin/ARM64-$build_mode";;
        *)
            echo "Unknown build target: $build_target"
            exit 1
            ;;
    esac
}

function build_nsis_plugins {
    local nsis_root_path="./windows/nsis-plugins"

    clean_solution "$nsis_root_path"
    build_solution_config "$nsis_root_path/nsis-plugins.sln" "Release" "x86"
}

function clean_libraries {
    clean_solution "./windows/libshared"
    clean_solution "./windows/windows-libraries"
    clean_solution "./windows/libwfp"
}

function main {
    clean_libraries

    build_solution "./windows/winfw" "winfw.sln"

    build_solution "./windows/driverlogic" "driverlogic.sln"

    build_nsis_plugins
}

main
