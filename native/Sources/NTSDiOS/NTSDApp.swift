import UIKit
import GameController
import NTSDRuntime
#if os(tvOS)
/// On tvOS controller input reaches the game only through GameController
/// (TVOS_WEB T1b): with UIKit interaction off, a gamepad's buttons are not
/// also delivered as presses (its B arrives as Menu there) and the Siri
/// Remote's Menu does not send the app to the background; the remote is read
/// as a micro gamepad (NTSDiOSSessionHost.startRemoteKeys).
typealias NTSDRootViewController = GCEventViewController
#else
typealias NTSDRootViewController = UIViewController
#endif

final class NTSDAppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,configurationForConnecting session: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name:"Default",sessionRole:session.role)
        configuration.delegateClass = NTSDSceneDelegate.self
        return configuration
    }
}

/// One window with the game's view; the session starts once the scene exists.
final class NTSDSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var host: NTSDiOSSessionHost?, session: OriginalRuntimeSession?
    #if !os(tvOS)
    private var inputDevices: NTSDInputDevices?
    #endif
    /// The screen the game is told: the device screen's bounds in points,
    /// landscape (the app runs landscape only), scaled up (same aspect) to at
    /// least 800x600, the desktop the original was made for, as on Android.
    /// An iPad's (the mini's 1133x744 and up) and a TV's are already larger;
    /// an iPhone's 874x402 would leave the 794x550 window partly above the
    /// screen, where the game's first blit is refused (PHONE_CONTROLLER C1;
    /// declared host policy, the picture is fitted to the view anyway).
    static func gameScreen(_ bounds: CGSize) -> CGSize {
        let w = max(bounds.width,bounds.height),h = min(bounds.width,bounds.height)
        guard w > 0,h > 0 else { return bounds }
        let fit = max(1,800/w,600/h)
        return CGSize(width:(w*fit).rounded(.down),height:(h*fit).rounded(.down))
    }
    func scene(_ scene: UIScene,willConnectTo session: UISceneSession,options connectionOptions: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene:scene),controller = NTSDGameViewController()
        // The picture fills the screen keeping its aspect (Apple TV: the TV's
        // whole height); the original format — 794×550 points at the centre —
        // with `--original-window` or the NTSDOriginalWindow default (from the
        // Home screen an Apple TV passes no launch arguments; Xcode, simctl and
        // devicectl can, and `-NTSDOriginalWindow YES` sets the default)
        // (WINDOW_SCALING S1).
        controller.gameView.original = CommandLine.arguments.contains("--original-window")
            || UserDefaults.standard.bool(forKey:"NTSDOriginalWindow")
        window.rootViewController = controller; window.makeKeyAndVisible(); self.window = window
        MainActor.assumeIsolated {
            let host = NTSDiOSSessionHost(arguments:CommandLine.arguments,view:controller.gameView,screen:Self.gameScreen(scene.screen.bounds.size))
            let game = OriginalRuntimeSession(arguments:CommandLine.arguments,host:host)
            host.session = game; controller.gameView.host = host
            self.host = host; self.session = game
            #if !os(tvOS)
            // The on-screen controls (TOUCH_CONTROLS): shown while no keyboard
            // or gamepad is connected (off in scripted checks unless
            // `--touch-controls on|off` says otherwise), their settings in
            // Application Support/controls.txt.
            let support = try? FileManager.default.url(for:.applicationSupportDirectory,in:.userDomainMask,appropriateFor:nil,create:true)
            let controls = OriginalTouchControls(config:support?.appendingPathComponent("controls.txt"))
            controls.forced = OriginalTouchControls.forced(CommandLine.arguments) ?? (host.scripted ? false : nil)
            let devices = NTSDInputDevices(controls)
            controller.gameView.attach(controls,devices:devices); inputDevices = devices
            #endif
            // Start once UIKit has finished connecting the scene: CoreAudio's
            // setup needs the main thread free (it deadlocked inside this
            // callback). A run-loop block rather than a main-queue block: the
            // launch probe for gamepads waits in the run loop for
            // GameController to report the paired ones, which it does on the
            // main queue, and a main-queue block would hold that queue (T1b).
            RunLoop.main.perform { MainActor.assumeIsolated { game.start() } }
        }
    }
}

#if !os(tvOS)
/// Whether a keyboard or gamepad is connected, for the on-screen controls,
/// which show only without one (TOUCH_CONTROLS): GameController's keyboard
/// and extended gamepads, or a hardware key press (should a keyboard go
/// unreported), forgotten when a keyboard disconnects. Asked again on the
/// next turn after each notification too (a departing device may still be
/// listed while its notification is delivered), when the app becomes active
/// and for a touch while they are hidden.
@MainActor final class NTSDInputDevices {
    let controls: OriginalTouchControls
    private var typed = false
    init(_ controls: OriginalTouchControls) {
        self.controls = controls
        for name in [Notification.Name.GCKeyboardDidConnect,.GCKeyboardDidDisconnect,.GCControllerDidConnect,.GCControllerDidDisconnect,
                     UIApplication.didBecomeActiveNotification] {
            NotificationCenter.default.addObserver(forName:name,object:nil,queue:.main) { [weak self] note in
                let disconnected = note.name == .GCKeyboardDidDisconnect
                MainActor.assumeIsolated { if disconnected { self?.typed = false }; self?.update() }
                DispatchQueue.main.async { MainActor.assumeIsolated { self?.update() } }
            }
        }
        update()
    }
    func keyPressed() { if !typed { typed = true; update() } }
    /// A touch while they are hidden: the keyboard or gamepad may be gone.
    func touched() { if controls.hardwareConnected { update() } }
    private var reported: [String]?
    /// Reported at launch and on each change (`iosTouchControls`).
    private func update() {
        let keyboard = GCKeyboard.coalesced != nil
        let gamepads = GCController.controllers().filter { $0.extendedGamepad != nil }.map(\.productCategory)   // not names: they may be the owner's
        controls.hardwareConnected = typed || keyboard || !gamepads.isEmpty
        let state = ["\(keyboard)","\(typed)","\(controls.active)"]+gamepads
        if state != reported {
            reported = state
            OriginalRuntimeSession.emit(["event":"iosTouchControls","keyboard":keyboard,"keyPressed":typed,"gamepads":gamepads,"shown":controls.active])
        }
    }
}
#endif

final class NTSDGameViewController: NTSDRootViewController {
    let gameView = NTSDGameView()
    override func loadView() { view = gameView }
    #if os(tvOS)
    override func viewDidLoad() { super.viewDidLoad(); controllerUserInteractionEnabled = false }
    #endif
    #if !os(tvOS)
    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    /// On the iPhone (PHONE_CONTROLLER C1) a swipe from the bottom edge needs a
    /// second swipe to leave the game, as games do, so a thumb sliding off a
    /// clip-on controller or the screen's edge does not close it.
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
        UIDevice.current.userInterfaceIdiom == .phone ? .bottom : []
    }
    #endif
    override var canBecomeFirstResponder: Bool { true }
    override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); becomeFirstResponder() }
    // Hardware keyboard presses reach the responder chain here.
    override func pressesBegan(_ presses: Set<UIPress>,with event: UIPressesEvent?) {
        if !gameView.handle(presses,down:true) { super.pressesBegan(presses,with:event) }
    }
    override func pressesEnded(_ presses: Set<UIPress>,with event: UIPressesEvent?) {
        if !gameView.handle(presses,down:false) { super.pressesEnded(presses,with:event) }
    }
    // iPadOS cancels presses it takes over (app switcher, system shortcuts):
    // release them, or the game would see the key held.
    override func pressesCancelled(_ presses: Set<UIPress>,with event: UIPressesEvent?) {
        if !gameView.handle(presses,down:false) { super.pressesCancelled(presses,with:event) }
    }
}

/// Shows the presented framebuffer scaled to fit (nearest) — or, in the
/// original format, at one point per pixel at the centre — maps touches to
/// the on-screen controls and the left mouse button and keyboard presses to
/// the shared HID key table.
final class NTSDGameView: UIView {
    weak var host: NTSDiOSSessionHost?
    private(set) var frameSize = CGSize.zero
    /// The original format: the frame at one point per pixel, centred — but
    /// the game's own full-screen popup (Alt+Enter) still fills the screen, as
    /// the shared backend declares it and the macOS host shows it, and a
    /// screen smaller than the frame (an iPhone's 402-point height) fits it
    /// rather than cropping it, as the browser and Android do.
    var original = false { didSet { gravity() } }
    private var popup = false
    private var oneToOne: Bool {
        original && !popup && bounds.width >= frameSize.width && bounds.height >= frameSize.height
    }
    /// Centred at its own size, one pixel to a point (aspect fit ignores the
    /// scale; set again whenever UIKit may have reset it).
    private func gravity() {
        let gravity: CALayerContentsGravity = oneToOne ? .center : .resizeAspect
        if layer.contentsGravity != gravity { layer.contentsGravity = gravity }
        if oneToOne && layer.contentsScale != 1 { layer.contentsScale = 1 }
    }
    override func didMoveToWindow() { super.didMoveToWindow(); gravity() }
    override func layoutSubviews() {
        super.layoutSubviews(); gravity()
        #if !os(tvOS)
        if controlsLayer.frame != controlsFrame { controlsLayer.frame = controlsFrame; showControls() }
        #endif
    }
    /// Points per frame pixel.
    private var scale: CGFloat {
        oneToOne ? 1 : min(bounds.width/frameSize.width,bounds.height/frameSize.height)
    }
    override init(frame: CGRect) {
        super.init(frame:frame); backgroundColor = .black
        #if !os(tvOS)
        isMultipleTouchEnabled = true
        controlsLayer.actions = ["contents":NSNull(),"bounds":NSNull(),"position":NSNull()]
        layer.addSublayer(controlsLayer)
        #endif
        layer.contentsGravity = .resizeAspect; layer.magnificationFilter = .nearest
        // An output switched between 1080p and 4K (or an external screen) may reset the layer's scale.
        registerForTraitChanges([UITraitDisplayScale.self]) { (view: NTSDGameView, _: UITraitCollection) in view.gravity() }
    }
    required init?(coder: NSCoder) { fatalError("not used") }
    func show(_ image: CGImage,size: CGSize,popup: Bool) {
        let changed = self.popup != popup || frameSize != size
        frameSize = size; self.popup = popup
        if changed { gravity() }
        layer.contents = image
    }
    /// A view point as the game's client point (the drawn frame's pixels).
    func clientPoint(_ p: CGPoint) -> (Int32,Int32) {
        guard frameSize.width > 0,bounds.width > 0 else { return (Int32(p.x),Int32(p.y)) }
        let scale = self.scale
        let x0 = (bounds.width-frameSize.width*scale)/2,y0 = (bounds.height-frameSize.height*scale)/2
        return (Int32(((p.x-x0)/scale).rounded(.down)),Int32(((p.y-y0)/scale).rounded(.down)))
    }
    // The Siri Remote's touch surface sends indirect touches: on tvOS they
    // must not become mouse clicks (its input comes through GameController).
    #if !os(tvOS)
    /// The on-screen controls (TOUCH_CONTROLS) on their own layer over the
    /// picture, in points within the left and right safe-area insets (a
    /// landscape iPhone's Dynamic Island; the iPad has none), rendered again
    /// at up to two pixels per point when they change or that area does.
    /// Every touch goes through them; one that begins on empty screen is the
    /// touch mouse.
    private var controls: OriginalTouchControls?, devices: NTSDInputDevices?
    private let controlsLayer = CALayer()
    private var controlsFrame: CGRect { bounds.inset(by:UIEdgeInsets(top:0,left:safeAreaInsets.left,bottom:0,right:safeAreaInsets.right)) }
    override func safeAreaInsetsDidChange() { super.safeAreaInsetsDidChange(); setNeedsLayout() }
    /// A view point in the controls' canvas, and back.
    private func canvasPoint(_ t: UITouch) -> (x: Float,y: Float) {
        let p = t.location(in:self),o = controlsFrame.origin
        return (Float(p.x-o.x),Float(p.y-o.y))
    }
    private var touchIDs: [ObjectIdentifier: Int] = [:], lastTouchID = 0
    func attach(_ controls: OriginalTouchControls,devices: NTSDInputDevices) {
        controls.key = { [weak self] usage,down in
            if let key = OriginalHIDKeys.key(usage:usage) { self?.host?.key(key,down:down,characters:down ? OriginalTouchControls.characters(usage) : nil) }
        }
        controls.mouse = { [weak self] phase,x,y in
            guard let self,let host = self.host else { return }
            let o = self.controlsFrame.origin
            let (cx,cy) = self.clientPoint(CGPoint(x:o.x+CGFloat(x),y:o.y+CGFloat(y)))
            switch phase {
            case .began: host.touch.began(x:cx,y:cy)
            case .moved: host.touch.moved(x:cx,y:cy)
            case .ended: host.touch.ended(x:cx,y:cy)
            }
        }
        controls.changed = { [weak self] in self?.showControls() }
        self.controls = controls; self.devices = devices; showControls()
    }
    /// Rasterized off the main (game) thread, one picture at a time; the
    /// newest waiting picture follows (`rendering`, `waiting`: main thread).
    private static let renderQueue = DispatchQueue(label:"NTSD.touchControls",qos:.userInteractive)
    private var rendering = false, waiting: (OriginalTouchControls.Picture?,Int,Int,Float)?
    private func showControls() {
        let size = controlsFrame.size
        guard let controls,size.width > 0,size.height > 0 else { controlsLayer.contents = nil; return }
        controls.layout(width:Float(size.width),height:Float(size.height),maxUnit:OriginalTouchControls.maxUnitPoints)
        // Up to two pixels per point, and about 3 million pixels (a 13-inch
        // iPad at 1.48).
        let scale = min(2,max(1,traitCollection.displayScale),max(1,(3_000_000/(size.width*size.height)).squareRoot()))
        waiting = (controls.picture,Int((size.width*scale).rounded()),Int((size.height*scale).rounded()),OriginalTouchControls.maxUnitPoints*Float(scale))
        renderNext()
    }
    private func renderNext() {
        guard !rendering,let (picture,width,height,maxUnit) = waiting else { return }
        waiting = nil
        guard let picture else { controlsLayer.contents = nil; return }
        rendering = true
        Self.renderQueue.async { [weak self] in
            let image = Self.image(picture.render(width:width,height:height,maxUnit:maxUnit))
            DispatchQueue.main.async { MainActor.assumeIsolated {
                guard let self else { return }
                self.rendering = false; self.controlsLayer.contents = image
                self.renderNext()
            } }
        }
    }
    /// R,G,B,A bytes, premultiplied.
    private nonisolated static func image(_ o: OriginalTouchOverlay) -> CGImage? {
        guard o.width > 0,o.height > 0,let space = CGColorSpace(name:CGColorSpace.sRGB),
              let provider = CGDataProvider(data:o.pixels.withUnsafeBytes { Data($0) } as CFData) else { return nil }
        return CGImage(width:o.width,height:o.height,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:o.width*4,space:space,
                       bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider:provider,decode:nil,shouldInterpolate:true,intent:.defaultIntent)
    }
    private func touchID(_ t: UITouch) -> Int {
        if let id = touchIDs[ObjectIdentifier(t)] { return id }
        lastTouchID += 1; touchIDs[ObjectIdentifier(t)] = lastTouchID; return lastTouchID
    }
    // The Siri Remote's touch surface sends indirect touches: on tvOS they
    // must not become mouse clicks (its input comes through GameController).
    override func touchesBegan(_ touches: Set<UITouch>,with event: UIEvent?) {
        devices?.touched()
        for t in touches { let p = canvasPoint(t); controls?.began(touchID(t),x:p.x,y:p.y) }
    }
    override func touchesMoved(_ touches: Set<UITouch>,with event: UIEvent?) {
        for t in touches { let p = canvasPoint(t); controls?.moved(touchID(t),x:p.x,y:p.y) }
    }
    override func touchesEnded(_ touches: Set<UITouch>,with event: UIEvent?) { lift(touches) }
    override func touchesCancelled(_ touches: Set<UITouch>,with event: UIEvent?) { lift(touches) }
    private func lift(_ touches: Set<UITouch>) {
        for t in touches {
            let p = canvasPoint(t); controls?.ended(touchID(t),x:p.x,y:p.y); touchIDs[ObjectIdentifier(t)] = nil
        }
    }
    #endif
    func handle(_ presses: Set<UIPress>,down: Bool) -> Bool {
        var handled = false
        #if !os(tvOS)
        // A keyboard is there: the on-screen controls hide (and let go)
        // before its key goes to the game. Only a key going down: a late
        // release after the keyboard left must not bring it back.
        if down,presses.contains(where:{ $0.key.map { OriginalHIDKeys.key(usage:UInt32($0.keyCode.rawValue)) != nil } ?? false }) { devices?.keyPressed() }
        #endif
        for press in presses {
            guard let key = press.key,let mapped = OriginalHIDKeys.key(usage:UInt32(key.keyCode.rawValue)) else { continue }
            handled = true
            MainActor.assumeIsolated { host?.key(mapped,down:down,characters:down ? key.characters : nil) }
        }
        return handled
    }

}
