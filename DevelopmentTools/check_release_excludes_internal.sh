#!/bin/sh
# Rejects internal-testing code in public builds (Build 7; V1_RELEASE_GATE.md "Internal builds").
#
#   sh DevelopmentTools/check_release_excludes_internal.sh
#       Checks that the Release configuration and the StayGrubby scheme's Archive action do not enable
#       INTERNAL_TESTING, then builds Release (unsigned, generic iOS) and scans the app for internal code.
#   sh DevelopmentTools/check_release_excludes_internal.sh PATH
#       Scans an .xcarchive, .app or .ipa. Run it on every archive before App Store or external
#       TestFlight submission: an Internal archive fails.
#   sh DevelopmentTools/check_release_excludes_internal.sh --expect-internal PATH
#       Positive control: passes only when PATH *is* an Internal build.
set -eu

cd "$(dirname "$0")/.."
MARKERS="STAYGRUBBY-INTERNAL-TESTING-BUILD
Preview First-Time Experience
PreviewSocialBackend
FirstRunPreview"
expect_internal=0
if [ "${1:-}" = "--expect-internal" ]; then expect_internal=1; shift; fi

scan() { # $1 = .app directory; prints each marker found in any Mach-O inside it
    find "$1" -type f \( -perm -u+x -o -name '*.dylib' \) | while IFS= read -r file; do
        if file "$file" | grep -q 'Mach-O'; then
            printf '%s\n' "$MARKERS" | while IFS= read -r marker; do
                if LC_ALL=C grep -a -q -F "$marker" "$file"; then printf '%s\t%s\n' "$marker" "${file#"$1"/}"; fi
            done
        fi
    done
}

app_in() { # resolves an .xcarchive, .ipa or .app to an .app directory
    case "$1" in
        *.xcarchive) find "$1/Products/Applications" -maxdepth 1 -name '*.app' | head -n 1 ;;
        *.ipa) tmp=$(mktemp -d); unzip -q "$1" -d "$tmp"; find "$tmp/Payload" -maxdepth 1 -name '*.app' | head -n 1 ;;
        *.app) printf '%s\n' "$1" ;;
        *) echo "Unsupported path: $1" >&2; exit 2 ;;
    esac
}

if [ $# -eq 0 ]; then
    conditions=$(xcodebuild -project StayGrubby.xcodeproj -scheme StayGrubby -configuration Release -showBuildSettings 2>/dev/null \
        | awk -F' = ' '/ SWIFT_ACTIVE_COMPILATION_CONDITIONS = /{print $2; exit}')
    case " $conditions " in *INTERNAL_TESTING*) echo "FAIL Release enables INTERNAL_TESTING ($conditions)"; exit 1 ;; esac
    archive=$(sed -n 's/.*<ArchiveAction buildConfiguration="\([^"]*\)".*/\1/p' StayGrubby.xcodeproj/xcshareddata/xcschemes/StayGrubby.xcscheme)
    [ "$archive" = "Release" ] || { echo "FAIL StayGrubby scheme archives '$archive', not Release"; exit 1; }
    derived=$(mktemp -d)
    xcodebuild build -project StayGrubby.xcodeproj -scheme StayGrubby -configuration Release -destination 'generic/platform=iOS' \
        -derivedDataPath "$derived" CODE_SIGNING_ALLOWED=NO -quiet >/dev/null 2>&1 || { echo "FAIL Release build"; exit 1; }
    app="$derived/Build/Products/Release-iphoneos/StayGrubby.app"
else
    app=$(app_in "$1")
fi
[ -n "$app" ] && [ -d "$app" ] || { echo "FAIL no app found"; exit 2; }

found=$(scan "$app")
if [ "$expect_internal" -eq 1 ]; then
    [ -n "$found" ] || { echo "FAIL expected an Internal build, found no internal code: $app"; exit 1; }
    echo "PASS Internal build identified:"; printf '%s\n' "$found"; exit 0
fi
if [ -n "$found" ]; then
    echo "FAIL internal-testing code is present. Do not submit this build to App Store review or external TestFlight:"
    printf '%s\n' "$found"; exit 1
fi
echo "PASS no internal-testing code in $(basename "$app") (Release configuration and StayGrubby scheme archive Release)"
