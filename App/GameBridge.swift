//
//  GameBridge.swift
//  App
//
//  Created by Alex Oakley on 12/5/23.
//

import GameCore
import UIKit

// MARK: - Base bridge implementation

public final class GameTriumphBridge: GameDelegate {
    
    private let swiftGame: (() -> SwiftGame)?
    
    public init(swiftGame: (() -> SwiftGame)? = nil) {
        self.swiftGame = swiftGame
    }
    
    public weak var window: UIWindow?
    fileprivate weak var currentSwiftGame: SwiftGame?

    public func nextRandom(minimumInclusive min: Float, maximumInclusive max: Float) -> Float {
        Float.random(in: (min...max))
    }
    
    public var primaryColor: UIColor {
        .orange
    }
    
    public var primaryLabel: String {
        ""
    }
    
    public var primaryLabelColor: UIColor? {
        nil
    }
    
    public var secondaryLabel: String {
        ""
    }
    
    public func scoreUpdated(_ score: Double) {}
    
    public func tutorialFinished() {}
    
    public func gamePaused() {}
    
    public func gameResumed() {}
    
    public func gameFinished(with score: Double) {
        window?.rootViewController?.dismiss(animated: true)
        currentSwiftGame?.gameDelegate = nil
    }
        
    fileprivate func withSwiftGame(_ game: SwiftGame, handler: (Game) -> Void) {
        game.gameDelegate = self
        currentSwiftGame = game
        
        game.modalPresentationStyle = .fullScreen
        window?.rootViewController?.present(game, animated: true)
        
        handler(game)
    }
    
    private func withGame(handler: (Game) -> Void) {
        if let game = swiftGame?() {
            withSwiftGame(game, handler: handler)
        } else {
            assertionFailure()
        }
    }
    
    public func startGame() {
        withGame { game in
            game.start()
        }
    }
}
