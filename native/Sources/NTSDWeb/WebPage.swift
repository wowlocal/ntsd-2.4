// The page's side of the browser host (TVOS_WEB W2b): functions of the "ntsd"
// import module that tools/crossplatform/web/wasi-worker.js provides when the
// worker has a canvas. Each call returns at once; the worker does the drawing.

/// Shows a finished crop: `width × height` XRGB8888 words (little-endian
/// 0x00RRGGBB, `OriginalFramebuffer`'s layout) at `pixels`.
@_extern(wasm, module: "ntsd", name: "present")
func ntsdPresent(_ pixels: UnsafeRawPointer, _ width: Int32, _ height: Int32)
