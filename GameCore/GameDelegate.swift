import UIKit

public protocol GameDelegate: AnyObject {
    var primaryColor: UIColor { get }
    var primaryLabel: String { get }
    var primaryLabelColor: UIColor? { get }
    var secondaryLabel: String { get }
    
    func nextRandom(minimumInclusive min: Float, maximumInclusive max: Float) -> Float
    
    func tutorialFinished()
    func gamePaused()
    func gameResumed()
    func scoreUpdated(_ score: Double)
    func gameFinished(with score: Double)
}

extension GameDelegate {
    public func nextRandom() -> Float {
        nextRandom(minimumInclusive: 0, maximumInclusive: 1)
    }
}
