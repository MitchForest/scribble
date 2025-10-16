import SwiftUI
import UIKit

final class OrientationAppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock: UIInterfaceOrientationMask = .landscape

    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        OrientationAppDelegate.orientationLock
    }
}

enum OrientationManager {
    static func lock(to mask: UIInterfaceOrientationMask,
                     rotateTo orientation: UIInterfaceOrientation) {
        OrientationAppDelegate.orientationLock = mask
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        if #available(iOS 16.0, *) {
            do {
                try scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
            } catch {
                // No-op: fall back to manual rotation.
            }
        }
        UIDevice.current.setValue(orientation.rawValue, forKey: "orientation")
        UINavigationController.attemptRotationToDeviceOrientation()
    }
}
