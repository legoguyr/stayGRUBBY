#!/bin/sh
# Confirms public builds contain no Debug-only first-run preview code (Build 7; V1_RELEASE_GATE.md
# "Debug-only first-run preview"). TestFlight and App Store builds are Release builds.
#
#   sh DevelopmentTools/check_release_excludes_preview.sh
#       Checks that Release does not compile DEBUG and that the StayGrubby scheme archives Release, then
#       builds Release (unsigned, generic iOS) and scans the app for preview code.
#   sh DevelopmentTools/check_release_excludes_preview.sh PATH
#       Scans an .xcarchive, .app or .ipa (for example before App Store submission); fails if preview code is present.
#   sh DevelopmentTools/check_release_excludes_preview.sh --expect-preview PATH
#       Positive control: passes only when PATH is a build that contains the preview (a Debug build).
set -eu

cd "$(dirname "$0")/.."
MARKERS="Preview First-Time Experience
Developer Tools — Debug Only
PreviewSocialBackend
FirstRunPreview"
expect_preview=0
if [ "${1:-}" = "--expect-preview" ]; then expect_preview=1; shift; fi

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
    case " $conditions " in *DEBUG*) echo "FAIL Release compiles DEBUG ($conditions)"; exit 1 ;; esac
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
if [ "$expect_preview" -eq 1 ]; then
    [ -n "$found" ] || { echo "FAIL expected a build with the preview, found none: $app"; exit 1; }
    echo "PASS preview present (Debug build):"; printf '%s\n' "$found"; exit 0
fi
if [ -n "$found" ]; then
    echo "FAIL Debug-only preview code is present. Do not upload or submit this build:"
    printf '%s\n' "$found"; exit 1
fi
echo "PASS no preview code in $(basename "$app") (Release configuration; StayGrubby scheme archives Release)"
