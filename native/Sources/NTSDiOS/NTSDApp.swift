import UIKit
import NTSDRuntime

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
    func scene(_ scene: UIScene,willConnectTo session: UISceneSession,options connectionOptions: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene:scene),controller = NTSDGameViewController()
        window.rootViewController = controller; window.makeKeyAndVisible(); self.window = window
        MainActor.assumeIsolated {
            let host = NTSDiOSSessionHost(arguments:CommandLine.arguments,view:controller.gameView,screen:scene.screen.bounds.size)
            let game = OriginalRuntimeSession(arguments:CommandLine.arguments,host:host)
            host.session = game; controller.gameView.host = host
            self.host = host; self.session = game
            // Start once UIKit has finished connecting the scene: CoreAudio's
            // setup needs the main thread free (it deadlocked inside this callback).
            DispatchQueue.main.async { MainActor.assumeIsolated { game.start() } }
        }
    }
}

final class NTSDGameViewController: UIViewController {
    let gameView = NTSDGameView()
    override func loadView() { view = gameView }
    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
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

/// Shows the presented framebuffer scaled to fit (nearest), maps touches to
/// the left mouse button and keyboard presses to the shared HID key table.
final class NTSDGameView: UIView {
    weak var host: NTSDiOSSessionHost?
    private(set) var frameSize = CGSize.zero
    override init(frame: CGRect) {
        super.init(frame:frame); backgroundColor = .black; isMultipleTouchEnabled = false
        layer.contentsGravity = .resizeAspect; layer.magnificationFilter = .nearest
    }
    required init?(coder: NSCoder) { fatalError("not used") }
    func show(_ image: CGImage,size: CGSize) { frameSize = size; layer.contents = image }
    /// A view point as the game's client point (the drawn frame's pixels).
    func clientPoint(_ p: CGPoint) -> (Int32,Int32) {
        guard frameSize.width > 0,bounds.width > 0 else { return (Int32(p.x),Int32(p.y)) }
        let scale = min(bounds.width/frameSize.width,bounds.height/frameSize.height)
        let x0 = (bounds.width-frameSize.width*scale)/2,y0 = (bounds.height-frameSize.height*scale)/2
        return (Int32(((p.x-x0)/scale).rounded(.down)),Int32(((p.y-y0)/scale).rounded(.down)))
    }
    override func touchesBegan(_ touches: Set<UITouch>,with event: UIEvent?) { touch(touches) { $0.began(x:$1,y:$2) } }
    override func touchesMoved(_ touches: Set<UITouch>,with event: UIEvent?) { touch(touches) { $0.moved(x:$1,y:$2) } }
    override func touchesEnded(_ touches: Set<UITouch>,with event: UIEvent?) { touch(touches) { $0.ended(x:$1,y:$2) } }
    override func touchesCancelled(_ touches: Set<UITouch>,with event: UIEvent?) { touch(touches) { $0.ended(x:$1,y:$2) } }
    private func touch(_ touches: Set<UITouch>,_ phase: (OriginalRuntimeTouchMouse,Int32,Int32) -> Void) {
        guard let t = touches.first,let host else { return }
        let (x,y) = clientPoint(t.location(in:self))
        MainActor.assumeIsolated { phase(host.touch,x,y) }
    }
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
