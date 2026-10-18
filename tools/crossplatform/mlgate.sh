#!/bin/zsh
# MEMORY_LOADING gates for one increment: mlgate.sh LABEL PREV SUITE...
# Run a copy (gate-run-LABEL.sh): a shell reads its script while running it.
# Pins the working native/tools trees, clean-builds the checked headless and
# AppKit gate binaries, an unchecked headless (shipping configuration), the
# APK and the checked release test bundle, then runs in parallel:
#  - phone: load_memory.py A/B on the A12 (an unmeasured PREV warm-up, then
#    LABEL, PREV, LABEL, PREV, LABEL),
#    music and sounds as in play, each run going on to body 1800 for its frame
#    time (main, render and whole-process ms per tick over bodies 600-1800)
#    and its memory at the match's end,
#    then the emulator's vs and its frames;
#  - Mac: 20 AppKit launches, all 10 scenarios + frames (checked), AppKit vs and
#    playback + frames, unchecked vs and Demo + frames, then load_memory.py A/B
#    of the unchecked binaries (3 runs each, interleaved, with the game
#    thread's and the process's ms per tick over bodies 600-1500);
#  - the named Core suites (and the exclusivity check) in the release test build.
# Copied from X5 crossplatform/ml-tools/mlgate.sh (SHA-256 3312b3e9…f89d0b) for
# ENGINE_SPLIT E0. Unset variables keep that script's paths and behaviour:
#  GATE_REPO     tree to gate (default the main worktree)
#  GATE_OUT      outputs: logs, APKs, scenario runs, the Android build folder
#  GATE_REFS     frozen references, read only (m1-frames-ref, rt-4w-appkit,
#                android-app-ref)
#  GATE_SCRATCH  index files and frozen binaries (the next gate's PREV)
#  GATE_PHONE=0  skip the A12 A/B, reported as skipped (no device on adb)
set -u
L=$1; P=$2; shift 2; SUITES=("$@")
cd ${GATE_REPO:-/Users/michael/Developer/ntsd-2.4}
X=${GATE_OUT:-/Volumes/X5/ntsd-2.4-research/crossplatform}
R=${GATE_REFS:-/Volumes/X5/ntsd-2.4-research/crossplatform}
S=${GATE_SCRATCH:-/private/tmp/claude-501/-Users-michael-Developer-ntsd-2-4/1f9218ae-9d5d-4c4e-a8dd-d5254994839c/scratchpad}
mkdir -p $X/logs $X/apks $S
XB=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift-build
ADB=/opt/homebrew/share/android-commandlinetools/platform-tools/adb
APPREF=$R/rt-4w-appkit
# The tested trees: native/ and tools/ as `git add -A` stages them (deletions,
# renames and modes included; ENGINE_SPLIT E1a review), in a copy of the index.
IDX=$(git rev-parse --git-path index)
export GIT_INDEX_FILE=$S/index-$L-test; rm -f $GIT_INDEX_FILE; cp "$IDX" $GIT_INDEX_FILE
git add -A -- native tools
TR=$(git write-tree); unset GIT_INDEX_FILE
echo "native $(git rev-parse "${TR}:native") tools $(git rev-parse "${TR}:tools")" | tee $X/logs/$L-tested-trees.txt
B1=build/swiftpm-headless; B1U=build/swiftpm-headless-unchecked; B2=build/swiftpm-app; B3=${GATE_TEST_SCRATCH:-build/swiftpm-test-release-b}; B4=$X/build-android-aarch64; export NTSD_ANDROID_SCRATCH=$B4
F=$S/frozen-$L; FU=$S/frozen-unchecked-$L; FA=$S/frozen-app-$L
rm -rf "${B1:?}" "${B1U:?}" "${B2:?}" "${B4:?}" "${F:?}" "${FU:?}" "${FA:?}"
env -u NTSD_UNCHECKED_EXCLUSIVITY $XB --package-path native --scratch-path $B1 --build-system native -c release --product NTSDHeadless > $X/logs/$L-headless-build.log 2>&1 || { echo "headless build failed"; grep -E 'error:' $X/logs/$L-headless-build.log | head -8 | cut -c1-250; exit 1; }
mkdir -p $F && cp -R $B1/release/NTSDHeadless $B1/release/*.bundle $F/
echo "headless built (checked: $(otool -tV $F/NTSDHeadless | grep -c swift_beginAccess) beginAccess)"
env -u NTSD_UNCHECKED_EXCLUSIVITY $XB --package-path native --scratch-path $B2 --build-system native -c release --product NTSDNative > $X/logs/$L-app-build.log 2>&1 || { echo "app build failed"; grep -E 'error:' $X/logs/$L-app-build.log | head -8 | cut -c1-250; exit 1; }
mkdir -p $FA && cp -R $B2/release/NTSDNative $B2/release/*.bundle $FA/
echo "app built (checked: $(otool -tV $FA/NTSDNative | grep -c swift_beginAccess) beginAccess)"
NTSD_UNCHECKED_EXCLUSIVITY=1 $XB --package-path native --scratch-path $B1U --build-system native -c release --product NTSDHeadless > $X/logs/$L-headless-unchecked-build.log 2>&1 || { echo "unchecked headless build failed"; exit 1; }
mkdir -p $FU && cp -R $B1U/release/NTSDHeadless $B1U/release/*.bundle $FU/
echo "unchecked headless built ($(otool -tV $FU/NTSDHeadless | grep -c swift_beginAccess) beginAccess)"
rm -rf "${B1U:?}"
python3 tools/crossplatform/android_app.py $X/android-phone --no-install > $X/logs/$L-apk.log 2>&1 || { echo "apk build failed"; tail -5 $X/logs/$L-apk.log; exit 1; }
rm -rf "${X:?}/android-phone/stage"; cp -p $X/android-phone/ntsd.apk $X/apks/$L.apk && echo "apk saved"
# The unstripped libraries of this APK, for symbolizing phone profiles later
# (the next gate's clean build replaces the build folder).
rm -rf $X/apklib-$L && mkdir -p $X/apklib-$L && cp -p $B4/out/Products/Release-android-aarch64/*.so $X/apklib-$L/ && echo "apk libraries kept"
(
  if [ "${GATE_PHONE:-1}" = 0 ]; then echo "phone A/B skipped (GATE_PHONE=0)"; else
  python3 tools/crossplatform/load_memory.py $X/ml-load --android --apk $X/apks/$L.apk --apk $X/apks/$P.apk --apk $X/apks/$L.apk \
    --apk $X/apks/$P.apk --apk $X/apks/$L.apk --label $L-ab --ticks 600,1800 --sounds --music --warmup --restore-stayon > $X/logs/$L-phone-ab.log 2>&1
  echo "phone A/B exit=$?"; grep -E '^\{"summary' $X/logs/$L-phone-ab.log | cut -c1-1000
  $ADB -s R58R36F7VFD shell svc power stayon false; echo phone_done
  fi
  export ANDROID_SERIAL=emulator-5554; cp -p $X/apks/$L.apk $X/android-phone/ntsd.apk
  python3 tools/crossplatform/android_app.py $X/android-phone --skip-build --scenario vs > $X/logs/$L-emu-vs.log 2>&1; echo "emu exit=$?"
  tail -1 $X/logs/$L-emu-vs.log | cut -c1-200
  python3 tools/crossplatform/compare_frames.py $R/android-app-ref/android-app $X/android-phone 2>&1 | tail -1 | tee $X/logs/$L-emu-frames.txt
  rm -rf "${X:?}/android-phone/stage"
) &
(
  python3 - "$FA" "$S/launch-$L" <<'PY'
import subprocess, sys, os, shutil
app, out = sys.argv[1], sys.argv[2]; music = "native/Sources/NTSDContent/Resources/OriginalMusic"; codes = []
for i in range(20):
    shutil.rmtree(out, ignore_errors=True); os.makedirs(out)
    p = subprocess.run([f"{app}/NTSDNative", "--music-dir", music, "--original", "--exit-after-startup", "--overlay", out, "--virtual-clock", "123456789", "8", "--mute-music", "--mute-sounds", "--no-activate"], capture_output=True, text=True, timeout=60, env={**os.environ, "TZ": "Etc/GMT-1"})
    codes.append(p.returncode)
shutil.rmtree(out, ignore_errors=True)
print('launches: crashes', sum(1 for c in codes if c != 0), 'of 20', flush=True)
PY
  rm -rf $X/rt-$L-all $X/rt-$L-appkit $X/rt-$L-unchecked
  python3 tools/crossplatform/run_headless_scenarios.py $X/rt-$L-all --local $F/NTSDHeadless 2>&1 | tail -10 | tee $X/logs/$L-scenarios.txt
  python3 tools/crossplatform/compare_frames.py $R/m1-frames-ref $X/rt-$L-all | tail -1 | tee -a $X/logs/$L-scenarios.txt
  python3 tools/crossplatform/run_headless_scenarios.py $X/rt-$L-appkit --local $FA/NTSDNative vs playback 2>&1 | tail -2 | tee $X/logs/$L-appkit.txt
  python3 tools/crossplatform/compare_frames.py $APPREF $X/rt-$L-appkit | tail -1 | tee -a $X/logs/$L-appkit.txt
  python3 tools/crossplatform/run_headless_scenarios.py $X/rt-$L-unchecked --local $FU/NTSDHeadless vs demo 2>&1 | tail -2 | tee $X/logs/$L-unchecked.txt
  python3 tools/crossplatform/compare_frames.py $R/m1-frames-ref $X/rt-$L-unchecked | tail -1 | tee -a $X/logs/$L-unchecked.txt
  echo scenarios_done
  python3 tools/crossplatform/load_memory.py $X/ml-load --local $FU/NTSDHeadless --local $S/frozen-unchecked-$P/NTSDHeadless --runs 3 --ticks 600,1500 --warmup --label $L-mac-ab > $X/logs/$L-mac-ab.log 2>&1
  echo "mac A/B exit=$?"; grep -E '^\{"summary' $X/logs/$L-mac-ab.log | cut -c1-1000
) &
(
  rm -rf "${B3:?}"
  env -u NTSD_UNCHECKED_EXCLUSIVITY $XB --package-path native --scratch-path $B3 --build-system native -c release --build-tests -Xswiftc -enable-testing > $X/logs/$L-tests-build.log 2>&1
  code=$?; echo "bundle exit=$code"; grep -E 'error:' $X/logs/$L-tests-build.log | head -6 | cut -c1-250
  [ $code -eq 0 ] || exit 1
  BA=$(find $B3 -maxdepth 4 -name 'NTSDNativePackageTests.xctest' | head -1)
  for c in OriginalExclusivityChecksTests $SUITES; do
    start=$(date +%s); xcrun xctest -XCTest NTSDCoreTests.$c "$BA" > $X/logs/$L-$c.log 2>&1; code=$?
    echo "$c exit=$code $(( $(date +%s)-start ))s $(grep -E 'Executed [0-9]+ tests?' $X/logs/$L-$c.log | tail -1 | sed 's/^ *//')"
    [ $code -eq 0 ] || grep -E 'error:' $X/logs/$L-$c.log | head -6 | cut -c1-300
  done
  echo suites_done
) &
wait
echo gate_done
