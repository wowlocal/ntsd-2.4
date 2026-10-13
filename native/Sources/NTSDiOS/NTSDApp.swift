import UIKit
import NTSDRuntime
#if os(tvOS)
import GameController

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
/// the left mouse button and keyboard presses to the shared HID key table.
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
    override func layoutSubviews() { super.layoutSubviews(); gravity() }
    /// Points per frame pixel.
    private var scale: CGFloat {
        oneToOne ? 1 : min(bounds.width/frameSize.width,bounds.height/frameSize.height)
    }
    override init(frame: CGRect) {
        super.init(frame:frame); backgroundColor = .black
        #if !os(tvOS)
        isMultipleTouchEnabled = false
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
    override func touchesBegan(_ touches: Set<UITouch>,with event: UIEvent?) { touch(touches) { $0.began(x:$1,y:$2) } }
    override func touchesMoved(_ touches: Set<UITouch>,with event: UIEvent?) { touch(touches) { $0.moved(x:$1,y:$2) } }
    override func touchesEnded(_ touches: Set<UITouch>,with event: UIEvent?) { touch(touches) { $0.ended(x:$1,y:$2) } }
    override func touchesCancelled(_ touches: Set<UITouch>,with event: UIEvent?) { touch(touches) { $0.ended(x:$1,y:$2) } }
    private func touch(_ touches: Set<UITouch>,_ phase: (OriginalRuntimeTouchMouse,Int32,Int32) -> Void) {
        guard let t = touches.first,let host else { return }
        let (x,y) = clientPoint(t.location(in:self))
        MainActor.assumeIsolated { phase(host.touch,x,y) }
    }
    #endif
    func handle(_ presses: Set<UIPress>,down: Bool) -> Bool {
        var handled = false
        for press in presses {
            guard let key = press.key,let mapped = OriginalHIDKeys.key(usage:UInt32(key.keyCode.rawValue)) else { continue }
            handled = true
            MainActor.assumeIsolated { host?.key(mapped,down:down,characters:down ? key.characters : nil) }
        }
        return handled
    }

}
