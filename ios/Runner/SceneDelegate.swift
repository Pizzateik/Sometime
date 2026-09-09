import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions) {
    guard let windowScene = scene as? UIWindowScene,
      let app = UIApplication.shared.delegate as? AppDelegate else { return }
    let engine = app.taskEngine()
    let sceneWindow = UIWindow(windowScene: windowScene)
    sceneWindow.rootViewController = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
    window = sceneWindow
    registerSceneLifeCycle(with: engine)
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    sceneWindow.makeKeyAndVisible()
    for item in connectionOptions.urlContexts { SometimeWidgetBridge.open(item.url) }
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    for item in URLContexts { SometimeWidgetBridge.open(item.url) }
    super.scene(scene, openURLContexts: URLContexts)
  }
}
