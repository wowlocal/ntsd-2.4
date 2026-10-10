# Third-party licence texts for the cross-platform packages

The Swift runtime's Foundation carries ICU (statically linked on Linux,
`_FoundationICU.dll` on Windows). ICU's sources state the Unicode licence; the
Swift repository that packages them states Apache 2.0 with the Runtime Library
Exception. Both texts ship in each package's `LICENSES`.

| File | Source | SHA-256 |
|---|---|---|
| `ICU-LICENSE.txt` | unicode-org/icu `LICENSE` at tag `release-76-1` (8eca245c7484ac6cc179e3e5f7c1ea7680810f39); ICU 76.1 is the version in swift-foundation-icu's `uvernum.h` | 01edac20612b1e590c1c1cfb02b7218c6adc7b0a944eda7a1e03aeee10725aed |
| `swift-foundation-icu-LICENSE.md` | swiftlang/swift-foundation-icu `LICENSE.md` at tag `swift-6.4.0-RELEASE` (f986d0728da0766cf81f371521b909d4a11681d2) | 2245a990b635558be210fb3eb4f8a6f7a49aebc0fefbf5859146a65ddc7ddcf3 |
