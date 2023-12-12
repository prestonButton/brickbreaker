import Foundation
import UIKit

public protocol Game: AnyObject {
    var gameDelegate: GameDelegate? { get set }
    
    func showTutorial()
    func start()
}

public protocol SwiftGame: Game, UIViewController {
    var customFontNames: [String]? { get }
}

public struct UnityGame {
    public let frameworkPath: String
    public init(frameworkPath: String) {
        self.frameworkPath = frameworkPath
    }
}
