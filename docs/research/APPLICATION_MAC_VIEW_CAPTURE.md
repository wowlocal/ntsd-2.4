# Profile-aware capture controls — monitor-profile blue mismatch preserved

The new owned capture agrees with a separate per-pixel ICC calculation on all128
opaque samples. The complete control matrix nevertheless fails: four pure-blue
samples in default/screen-profile windows differ from the declared input by7/255
in red, exceeding the unchanged2/255 tolerance. Explicit sRGB windows and direct
image controls match their inputs. This is additional evidence about the native
window color path, not permission to waive the four mismatches or accept all34.

[Plan](APPLICATION_MAC_VIEW_CAPTURE_PLAN.md),
[preceding diagnosis](APPLICATION_MAC_DISPLAY_COLOR_DIAGNOSIS.md).
HEAD6ba168e; task build/research/application-mac-view-capture-20260926. No original
EXE/DLL, emulator, source capture or refused operation ran. Production remains
unchanged. This work targets the readback/display gate for Naruto/Sasuke District.

## Implemented candidate and controls

OriginalMacViewCapture obtains the actual cached bitmap CGImage and its tagged
profile, draws it into a same-size explicit sRGB8 premultiplied RGBA CGContext,
then owns a copied byte array. colorAt checks bounds and returns an sRGB NSColor
after undoing premultiplication; zero alpha returns transparent black. Checked
dimension arithmetic and a byte budget precede allocation. It receives no expected
colors, game framebuffer or source after-state. The helper is not yet integrated.

The probe uses two reversed4x4 patterns of16 fixed colors and three window profile
policies. Six view cases and two direct images supply128 opaque samples. A separate
calculation uses raw getPixel values and the actual bitmap NSColorSpace; it avoids
the legacy colorAt interpretation and the helper's whole-image CGContext path.
Four alpha cases, four bounds, two source-mutation ownership cases, an explicit
budget rejection and simulated missing image provide additional finite controls.
These distinct calculations are author checks, not independent review.

## Preserved first failure and bounded input correction

Build84810 passed in3.151s. Probe86213 terminated with SIGABRT/exit-6 in2.135s:
NSBitmapImageRep() raises NSInvalidArgumentException for its unavailable init.
The negative-input constructor ran before result publication; no color observations
from this run were saved or accepted. The read-only checker then encountered the
missing result file; both errors are recorded in failure-diagnosis1.json.

control-amendment1.md declares one separate candidate2: initialize a valid bitmap
subclass from the existing image and override cgImage to return nil. This is an
explicit simulated dependency failure, not an actual view observation. The capture
helper, colors, expectations, tolerance and assertions remain unchanged. Build88675
passed in1.140s. Probe89462 returned1 in1.110s with a complete report and eight
failed assertions at four positions. The existing checker correctly rejected the
nonempty failure list. All processes are terminal/absent, without guards or residuals.

## Actual comparison

In both pattern orders, default and explicit screen-profile windows produce raw
RGBA(0,4,245,255) for input sRGB blue(0,0,255). The owned capture returns
(0.027450980392156862,0,1,1); the separate ICC calculation returns
(0.027135031297802925,0,1,1). Both exceed the original tolerance against the input.
The maximum difference between the two readers across all128 samples is
0.0027391579951725753, within2/255. Alpha samples agree exactly with component
arithmetic; all ownership/bounds/budget/simulated-missing checks pass.

The actual screen profile is Pro Display XDR, ICC SHA256
`1b548790cbe545fd80739f440ad3058c527a3e8dce27d9691825d137eee82d22`.
Every declared RGB input passes at the sampled positions in the explicit sRGB
window and direct image cases. The failure is upstream of the new reader;
clipping/quantization or profile conversion as its detailed cause is not independently
established. General rendering, HDR/gamut/device output and Windows equivalence
remain unproved. The old failed colors and masks have not been changed or excluded.

## Next implementation contract and preservation

NEXT: explicitly define the native window backing as sRGB, consistent with the
already declared sRGB CGImage/framebuffer policy, and integrate this profile-aware
snapshot in a separate display correction2. Apple's
[NSWindow.colorSpace](https://developer.apple.com/documentation/appkit/nswindow/colorspace)
is the window color-space property; the passing explicit-profile controls are
actual local evidence for that host mapping. This remains a Native policy, not a
recovered Windows format. Require the unchanged34 methods plus a nonuniform native
window/pattern regression; preserve the default-profile failures as historical
counterexamples. Do not edit the old probes or represent this matrix as all-passing.

Finalizer93739 terminal0/absent in5.699s verifies47 PAX members, full bodies/modes/
nsmtimes/membership and root1034/failed candidate2261/source55 preservation. Both
candidates, binaries, failures, complete second report and unchanged helper are
archived; task frozen. [Publication](../evidence/application-mac-view-capture.json),
[closure](../evidence/application-mac-view-capture-close.json).
Independent review/all34/root promotion/general graphics/providers/loading/Windows/
input/audio/clean-Mac/full match/full game remain open. Source59727 is terminal34
Objects, not137; NTSDApp still Practice. EXE envelope not recalculated; safety
incidents remain open. Author review is not independent acceptance.
