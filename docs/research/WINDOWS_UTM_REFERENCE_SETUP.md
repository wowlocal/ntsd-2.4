# UTM reference VM configured; Windows ISO download live

2026-09-26. [Plan](WINDOWS_UTM_REFERENCE_SETUP_PLAN.md),
[checkpoint](../evidence/windows-utm-reference-setup.json).
User authorized Windows through UTM, installed UTM, and confirmed CrossOver and
the old NTSD24XP bottle are not installed on this Mac. CrossOver's existing clean
launch instructions remain available; it is not an actual Windows API reference.

UTM4.7.5 now registers `NTSD Windows 11 ARM Reference`, UUID
98DFE348-2BA4-426E-9E40-7214229E8E45, in task-owned X5 directory
/Volumes/X5/ntsd-2.4-research/01a0dc49-738f-7972-8fb0-e98fb2f34408/windows-utm-reference-20260926.
It is stopped and Windows is not installed. Configuration verification confirms
ARM64/QEMU virt/hypervisor,4vCPU,8192MiB RAM,UEFI,TPM2, a thin64GiB NVMe qcow2
(its header virtual-size field checked), no NIC, no directory share and no shared
clipboard. Microsoft Secure Boot key preload was selected for the new VM;
actual guest Secure Boot status remains unobserved. UTM is downloading Windows
guest tools independently. No shared host home/workspace or credentials.

The official [Microsoft ARM64 page](https://www.microsoft.com/en-us/software-download/windows11arm64)
provided Windows11 25H2 English ARM64 v2, total7,994,415,104 bytes. Vendor SHA256:
638aa2c88e94385b00f4f178d071e3df0b7d9e335577a83bd533b7f2eb65adf0.
The [UTM guide](https://docs.getutm.app/guides/windows/) informed the ordinary
installation configuration. The older rejected IoT redirect2276103 remains open
and was not retried. This is the separately available retail ISO endpoint.

First transfer PID85410/curl85413 stalled at16MiB. A separate1MiB range probe
returned exact HTTP206/Content-Range/ETag in1.114s. After identity/start/cwd
revalidation, original curl was terminated; its terminal-15 job/log and16MiB
partial remain. The original producer is unchanged. The diagnosed transport
correction uses the same authorized URL, fixed8MiB ranges, up to8 requests,
180s each/2h total, no automatic retries. Each206/Content-Range/ETag/length is
verified; all bytes must pass the vendor hash after ordered reassembly.
This is not a game/source capture or safety-refusal retry.

At checkpoint download2 PID94629 is identity-verified live, with201,326,592 bytes
confirmed including the retained prefix. It writes on T7 under
ntsd-2.4-artifacts/windows-utm-reference-20260926. Do not restart for quiet output.
Job/producer/input pins and the correction plan are in the checkpoint. The VM's
current CD bookmark still points to the first partial: replace it with the
verified complete ISO before boot. Do not boot the partial file.

Transfer preparation PID95892 completed0 in4.281s. The separate read-only
NTSD-Reference-Transfer.iso contains1,595 game files/854,489,099 game bytes, the
previously verified NLS kit and explicit provenance. Its1,605 files were mounted
read-only and compared byte-for-byte with the exact membership before detaching.
ISO857,237,504 bytes, SHA256
a12d5692ac4bf350c175787a0219130cf1ac535e4168d2c811f55ca2b9e9c3a2.
The baseline EXE/DLL hashes and every copied source file were rechecked unchanged.
No original game, Windows collector or Native code executed. New guest captures
must use their own finite plans; no historical masks/expected values changed.

NEXT: revalidate existing download2/UTM guest-tools progress; preserve any nonpass,
verify full ISO/vendor SHA, replace VM's partial CD bookmark, then install Windows
through supported setup. Any needed account/terms action remains explicit.
Record actual guest build, translation, display/DC/font/DPI before cursor/GDI or
NLS evidence claims. VM boot alone is not compatibility acceptance. Independent
review, Windows observations, full first-menu pixels, Native raster/integration,
input/audio, clean-Mac and complete match/game remain open. No Native build/test
was required for this configuration and transfer-media increment.
