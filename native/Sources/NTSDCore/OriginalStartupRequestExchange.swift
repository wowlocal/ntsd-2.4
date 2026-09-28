/// One chronological journal for the complete startup's external requests.
/// Prepared file bytes, environmentTZ, panelIO and aggregate sound remain inputs;
/// this type does not turn them into observed device results.
public enum OriginalStartupRequest: OriginalExchangeRequest {
    public typealias Reply = OriginalStartupResponse
    case milliseconds, initializeCriticalSection(UInt32), initializeCOM
    case window(OriginalWindowInitialization.Request)
    case panelWrite([UInt8]), panelClose, allocatePanel, panelBitmap(String), panelDevice
    case filetime, timezone, allocateCalendar(Int), zoneName(String,Int)
    case music(OriginalMusicEvent), cursor(Bool,[UInt32])
    case joystick(OriginalInputStartup.Request)
    case wave(OriginalApplicationPreparedStartupPlatform.Wave)
    case sound(OriginalMenuSoundStartup.Event), waveAudio(OriginalWaveBinding,OriginalWaveRequest)

    public func accepts(_ response: Reply) -> Bool {
        switch (self,response) {
        case (.milliseconds,.milliseconds),(.initializeCriticalSection,.initializeCriticalSection),
             (.initializeCOM,.initializeCOM),(.window,.window),(.panelWrite,.panelWrite),
             (.panelClose,.panelClose),(.allocatePanel,.allocatePanel),(.panelBitmap,.panelBitmap),
             (.panelDevice,.panelDevice),(.filetime,.filetime),(.timezone,.timezone),
             (.allocateCalendar,.allocateCalendar),(.zoneName,.zoneName),(.music,.music),
             (.cursor,.cursor),(.joystick,.joystick),(.wave,.wave): return true
        case (.sound,.sound):return true
        case let (.waveAudio(_,q),.waveAudio(r)):return q.accepts(r)
        default: return false
        }
    }
}
public enum OriginalStartupResponse {
    case milliseconds(UInt32), initializeCriticalSection([UInt8]), initializeCOM(UInt32)
    case window(OriginalWindowInitialization.Response)
    case panelWrite(Int32), panelClose(Int32), allocatePanel(OriginalInterfaceAllocation)
    case panelBitmap(OriginalBitmapInput), panelDevice(OriginalApplicationPreparedStartupPlatform.PanelDevice)
    case filetime(UInt64), timezone(OriginalApplicationPreparedStartupPlatform.Zone)
    case allocateCalendar(OriginalInterfaceAllocation), zoneName([UInt8]), music(OriginalMusicResponse)
    case cursor(UInt32), joystick(OriginalInputStartup.Response), wave(OriginalWavePlatform)
    case sound(OriginalSoundResponse), waveAudio(OriginalWaveResponse)
}
public typealias OriginalStartupRequestExchange = OriginalRequestExchange<
    OriginalStartupRequest, any OriginalApplicationStartupResource>
