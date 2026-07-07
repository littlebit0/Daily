import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    let googleContexts = URLContexts.filter { context in
      context.url.scheme?.lowercased().hasPrefix("com.googleusercontent.apps.") == true
    }

    let remainingContexts = URLContexts.subtracting(googleContexts)
    if !remainingContexts.isEmpty {
      super.scene(scene, openURLContexts: remainingContexts)
    }
  }
}
