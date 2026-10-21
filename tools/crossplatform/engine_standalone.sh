#!/bin/zsh
# ENGINE_SPLIT E7a: the engine package alone. Exports engine/ at REV with
# git archive into OUT/engine (nothing else from the repository), then
#  - macOS: a debug build and test run, and a clean release build and test run,
#    of the package's default products and NTSDEngineTests (release with
#    -enable-testing, as mlgate's engine bundle; checked exclusivity as there);
#  - Linux: a native build and test run of the same folder inside
#    swift:6.4.0-noble as uid 1000 (a container's root keeps a permission-0
#    directory searchable, which OriginalPosixFileFactsTests checks).
# Each run lists its tests first (swift test list) and writes its output to
# OUT/logs. Usage: engine_standalone.sh REV OUT
set -u
REV=$1; OUT=$2
REPO=$(cd "$(dirname "$0")/../.." && pwd)
XB=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin
IMAGE=swift:6.4.0-noble
mkdir -p $OUT/logs && rm -rf $OUT/engine $OUT/build-debug $OUT/build-release $OUT/build-linux && mkdir -p $OUT/engine
git -C $REPO archive $REV engine | tar -x -C $OUT --strip-components 0
echo "export $(git -C $REPO rev-parse ${REV}:engine) files $(find $OUT/engine -type f | wc -l | tr -d ' ')"
cd $OUT/engine
for c in debug release; do
  F=(); [ $c = release ] && F=(-Xswiftc -enable-testing)
  env -u NTSD_UNCHECKED_EXCLUSIVITY $XB/swift-build --scratch-path $OUT/build-$c --build-system native -c $c --build-tests $F > $OUT/logs/mac-$c-build.log 2>&1
  echo "mac $c build exit=$?"
  env -u NTSD_UNCHECKED_EXCLUSIVITY $XB/swift-test --scratch-path $OUT/build-$c --build-system native -c $c $F list > $OUT/logs/mac-$c-list.txt 2>$OUT/logs/mac-$c-list.err
  echo "mac $c list exit=$? tests $(grep -c . $OUT/logs/mac-$c-list.txt)"
  env -u NTSD_UNCHECKED_EXCLUSIVITY $XB/swift-test --scratch-path $OUT/build-$c --build-system native -c $c $F --skip-build > $OUT/logs/mac-$c-test.log 2>&1
  echo "mac $c test exit=$? $(grep -E 'Executed [0-9]+ tests?' $OUT/logs/mac-$c-test.log | tail -1 | sed 's/^[[:space:]]*//')"
done
mkdir -p $OUT/build-linux
docker run --rm --user 1000:1000 -e HOME=/tmp -v $OUT:$OUT -w $OUT/engine $IMAGE \
  sh -c "swift build --scratch-path $OUT/build-linux --build-tests > $OUT/logs/linux-build.log 2>&1; echo linux build exit=\$?;
         swift test --scratch-path $OUT/build-linux list > $OUT/logs/linux-list.txt 2>$OUT/logs/linux-list.err; echo linux list exit=\$? tests \$(grep -c . $OUT/logs/linux-list.txt);
         swift test --scratch-path $OUT/build-linux --skip-build > $OUT/logs/linux-test.log 2>&1; echo linux test exit=\$?"
grep -E 'Executed [0-9]+ tests?' $OUT/logs/linux-test.log | tail -1 | sed 's/^[[:space:]]*//'
echo standalone_done
