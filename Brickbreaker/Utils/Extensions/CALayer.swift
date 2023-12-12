// Copyright © TriumphSDK. All rights reserved.

import UIKit

extension CALayer {
    func applyGradient(of colors: [UIColor], atAngle angle: CGFloat) {
        let gradient = CAGradientLayer()
        gradient.frame = bounds
        gradient.colors = colors.map { $0.cgColor }
        gradient.calculatePoints(for: angle)
        masksToBounds = true
        insertSublayer(gradient, at: 0)
    }
    
    func doGlowAnimation(withColor color: UIColor) {
        masksToBounds = false
        shadowColor = color.cgColor
        shadowRadius = 0
        shadowOpacity = 1
        shadowOffset = .zero
        
        let glowAnimation = CABasicAnimation(keyPath: "shadowRadius")
        glowAnimation.fromValue = 4
        glowAnimation.toValue = 15
        glowAnimation.beginTime = CACurrentMediaTime() + 0.05
        glowAnimation.duration = 1
        glowAnimation.fillMode = .removed
        glowAnimation.autoreverses = true
        glowAnimation.repeatCount = .infinity
        glowAnimation.isRemovedOnCompletion = false
        add(glowAnimation, forKey: "shadowGlowingAnimation")
    }
}
