#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Observe CPU ownership at initialized early-menu to catalog attachment.

Executes original initialization and early menus, then attaches MenuLoading.
Does not execute the catalog itself or prove any numeric scan result. This
separates the attached game-thread CRT from the catalog's standalone scanner.
"""
import json
from import_ntsd import ROOT, EXE_SHA256
from oracle_crt import DLL_SHA256
from oracle_initialized_gameplay import InitializedEarlyMenus
from oracle_menu_loading import MenuLoading
from unicorn.x86_const import UC_X86_REG_FPCW, UC_X86_REG_EIP, UC_X86_REG_ESP


def main():
    early = InitializedEarlyMenus()
    early.capture_loop()
    assert early.uc.reg_read(UC_X86_REG_EIP) == 0x41bc90
    loading = MenuLoading(early)
    result = dict(exeSHA256=EXE_SHA256, dllSHA256=DLL_SHA256, scope=__doc__,
        pc=early.uc.reg_read(UC_X86_REG_EIP), sp=early.uc.reg_read(UC_X86_REG_ESP),
        mainControlWord=early.uc.reg_read(UC_X86_REG_FPCW),
        scannerControlWord=loading.crt.uc.reg_read(UC_X86_REG_FPCW),
        settingsCRTSharesGameCPU=early.crt.uc is early.uc,
        catalogEXESharesGameCPU=loading.uc is early.uc,
        catalogScannerSharesGameCPU=loading.crt.uc is early.uc,
        nativeCompared=False, windowsVerified=False)
    assert result['settingsCRTSharesGameCPU'] and result['catalogEXESharesGameCPU']
    assert not result['catalogScannerSharesGameCPU']
    assert result['mainControlWord'] == 0x23f and result['scannerControlWord'] == 0
    (ROOT / 'docs/evidence/catalog-scanner-fpu-boundary.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2), flush=True)


if __name__ == '__main__':
    main()
