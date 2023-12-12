import AVFoundation
import GameCore
import GameplayKit
import SpriteKit

struct PhysicsCategory
{
    static let Brick : UInt32 = 0x01 << 1
    static let Ball : UInt32 = 0x01 << 2
    static let Border : UInt32 = 0x01 << 3
    static let Powerup : UInt32 = 0x01 << 4
    static let Bonus : UInt32 = 0x01 << 5
}

enum BreakerGameState
{
    case StartMenu
    case GameOver
    case Playing
    case Paused
    case BallStore
}

final class GameScene: SKScene, SKPhysicsContactDelegate {
    weak var gameDelegate: GameDelegate?
    
    //MARK: - Blitz mode code to refactor

    func updateToBeatLabel() {
        gameDelegate?.scoreUpdated(Double(self.totalScore))

        scoreLabel.text = gameDelegate?.primaryLabel    
        if let color = gameDelegate?.primaryLabelColor {
            scoreLabel.fontColor = color
        } else {
            scoreLabel.fontColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
        }
        positionLabel.text = gameDelegate?.secondaryLabel
    }
    
    var leaderboardChanged = false // keep track of when leaderboard changes as we will always want to update
    var intRanking = [Int]()
    var targetScore = 0
    let formatter = NumberFormatter()

    
    weak var presentingViewController: BreakerViewController?
    var levelNumber = Int()
    
    // Information about the balls
    var numBallsTotal = Int()
    var ballSize = CGFloat()
    var ballColor = SKColor()
    var ballsReleased = Int()
    var ballTimer = Timer()                     // How fast are balls launched?
    var ballsRemainingLabel = SKLabelNode() // Countdown on screen as we release balls
    var haptics = CustomImpactFeedbackGenerator()
    var totalScore = 0
    let tik: SystemSoundID = 1104      // tik
    let vibrate: SystemSoundID = 4095     // vibrate


    var ballOriginLocation = CGPoint()          // Balls starting point
    var ballLaunchPosition = SKShapeNode()      // Ball stays in background at starting location
    var ballStartingLocation = SKShapeNode()    // Where did the balls start (show when balls not launching)
    var ballTargetLocation = CGPoint()          // Target where balls fly towards

    // Borders
    var borderRight = SKSpriteNode()
    var borderLeft = SKSpriteNode()
    var borderTop = SKSpriteNode()
    var borderBottom = SKSpriteNode()

    // Box Starting Positions
    var xBrickStart = CGFloat()     // First box x
    var yBrickRowStart = CGFloat()  // All boxes start at the same y offset
    var yBrickStart = CGFloat()     // Balls have to start at the bottom
    var ballZoneHeight = CGFloat()  // The zone height for detecting balls stuck

    var colorsSecondary = [Int : SKColor]()
    var colorsPrimary = [Int :SKColor]()
    var randomColor = SKColor()
    
    // BBTAN Style timer
    var timeLeftMin = Int()
    var timeLeftSec = Int()
    var labelTimer = Timer()            // the timer which updates the time at the bottom in the main game
    var timeRect = SKShapeNode()
    var timeLabel = SKLabelNode()

    // Menu on running screen
    var menuRect = SKShapeNode()
    var scoreLabel = SKLabelNode()
    var positionLabel = SKLabelNode()

    var roundOver = Bool()              // Is this round done?
    var gameOver = Bool()
    var touchIsEnabled = Bool() {       // Touch off while balls being released
        didSet {
            guard ProcessInfo.processInfo.environment["PLAY_TEST_GAME_AUTOMATICALLY"] == "YES" else { return }
            
            if touchIsEnabled {
                let x = CGFloat.random(in: -300...300)
                let y = -CGFloat.random(in: 500...700)
                let location = CGPoint(x: x, y: y)

                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.deletePointer()
                    self.touchDidMove(location: location)
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                    guard let self = self else { return }
                    self.prepareToThrow(location: location)
                    self.deletePointer()
                }
            }
        }
    }
    var startedBallTouch = Bool()
    var hasFirstBallReturned = Bool()   // has the first ball returned?
    public var menuVisible = Bool()
    var gameOverVisible = Bool()
    
    var quitButton = SKShapeNode()
    var darkerBackgroundRect = SKShapeNode()
    var endGameLabel = SKLabelNode()
    var oneMoreLabel = SKLabelNode()
    var chanceLabel = SKLabelNode()

    var gameState = BreakerGameState.StartMenu

    // MAIN MENU
    var bouncingBall = SKSpriteNode()       // Demo of the current ball
    var bounceBottom = SKSpriteNode()       // Line to bounce off
    var playButtonShape = SKShapeNode()     // Play button
    var circleShape = SKShapeNode()         // Change ball
    var gameNameLabel = SKLabelNode()
    var upperLine = SKShapeNode()
    var bottomLine = SKShapeNode()
    var playBackGround = SKShapeNode()
    var ballBackGround = SKShapeNode()
    
    var lastHaptic: Date?
    
    func runUpdateLabels(intensity: CGFloat) {
        guard let lastHaptic = lastHaptic else {
            updateToBeatLabel()
            haptics.impactOccurred(intensity: intensity)
            playSystemSound(tik)
            self.lastHaptic = Date()
            return
        }
        let delta = lastHaptic.distance(to: Date())
        
        if delta >= 0.05 {
            updateToBeatLabel()
            haptics.impactOccurred(intensity: intensity)
            playSystemSound(tik)
            self.lastHaptic = Date()
        }
    }
    
    func createBorder()
    {
        formatter.numberStyle = .ordinal

        borderRight = SKSpriteNode()
        borderRight.size = CGSize(width: 1, height: self.frame.height)
        borderRight.position = CGPoint(x: self.frame.width / 2 , y: 0)
        borderRight.physicsBody = SKPhysicsBody(rectangleOf: borderRight.size)
        borderRight.physicsBody?.affectedByGravity = false
        borderRight.physicsBody?.isDynamic = false
        borderRight.physicsBody?.categoryBitMask = PhysicsCategory.Border
        borderRight.physicsBody?.collisionBitMask = 0
        borderRight.physicsBody?.contactTestBitMask = PhysicsCategory.Ball
        borderRight.physicsBody?.friction = 0.0
        borderRight.color = #colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1)
        borderRight.name = "border"
        
        borderLeft = SKSpriteNode()
        borderLeft.size = CGSize(width: 1, height: self.frame.height)
        borderLeft.position = CGPoint(x: -self.frame.width / 2 , y: 0)
        borderLeft.physicsBody = SKPhysicsBody(rectangleOf: borderLeft.size)
        borderLeft.physicsBody?.affectedByGravity = false
        borderLeft.physicsBody?.isDynamic = false
        borderLeft.physicsBody?.categoryBitMask = PhysicsCategory.Border
        borderLeft.physicsBody?.collisionBitMask = 0
        borderLeft.physicsBody?.contactTestBitMask = PhysicsCategory.Ball
        borderLeft.physicsBody?.friction = 0.0
        borderLeft.color = #colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1)
        borderLeft.name = "borderLeft"
        
        borderTop = SKSpriteNode()
        borderTop.size = CGSize(width: self.frame.width, height: 1)
        borderTop.position = CGPoint(x: 0, y: yBrickRowStart)
        borderTop.zPosition = 3
        borderTop.physicsBody = SKPhysicsBody(rectangleOf: borderTop.size)
        borderTop.physicsBody?.affectedByGravity = false
        borderTop.physicsBody?.isDynamic = false
        borderTop.physicsBody?.categoryBitMask = PhysicsCategory.Border
        borderTop.physicsBody?.collisionBitMask = 0
        borderTop.physicsBody?.contactTestBitMask = PhysicsCategory.Ball
        borderTop.physicsBody?.friction = 0.0
        borderTop.color = #colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1)
        borderTop.name = "border"
        
        borderBottom = SKSpriteNode()
        borderBottom.size = CGSize(width: self.frame.width, height: 1)
        borderBottom.position = CGPoint(x: 0, y: yBrickStart - self.frame.width / 14 - 8 * self.frame.width / 7)
        borderBottom.zPosition = 3
        borderBottom.physicsBody = SKPhysicsBody(rectangleOf: borderBottom.size)
        borderBottom.physicsBody?.affectedByGravity = false
        borderBottom.physicsBody?.isDynamic = false
        borderBottom.physicsBody?.categoryBitMask = PhysicsCategory.Border
        borderBottom.physicsBody?.collisionBitMask = 0
        borderBottom.physicsBody?.contactTestBitMask = PhysicsCategory.Ball
        borderBottom.physicsBody?.friction = 1.0
        borderBottom.color = #colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1)
        borderBottom.name = "borderBottom"
        
        self.addChild(borderTop)
        self.addChild(borderLeft)
        self.addChild(borderRight)
        self.addChild(borderBottom)
    }
    
    func BrickHit( nodeHit:SKNode  )
    {
        if let node = nodeHit as? SKSpriteNode as? Brick
        {
            totalScore += 1
                                    
            node.hitpoints -= 1
            if node.hitpoints < 1
            {
                runUpdateLabels(intensity: 1)
                // We have an emitter for explosions
                if let explosion = SKEmitterNode(fileNamed: "Explosion2") {
                    explosion.position = node.position
                    addChild(explosion)

                    // Build up the explosion
                    let wait = SKAction.wait(forDuration: 0.5)
                    let removeMe = SKAction.removeFromParent()
                    let explode = SKAction.sequence([wait, removeMe])
                    
                    // Run explosion!
                    explosion.run(explode)
                }
              

                let DeathAnim = SKAction.run {
                    node.removeAllChildren()
                    node.removeFromParent()
                }
                self.run(DeathAnim)
            }
            else
            {
                runUpdateLabels(intensity: 0.3)
                node.hitpointsLabel.text = "\(Int(node.hitpoints))"
            }
        }
    }
    
    func BallHitBottom( ball:SKPhysicsBody )
    {
        // First ball to hit bottom stays until next round
        if hasFirstBallReturned
        {
            ballStartingLocation.removeFromParent()
            // This is now the NEXT starting location (while we still have balls in flight we can't change origin!)
            if let node = ball.node {
                ballStartingLocation.position = node.position
                // Make sure the Y lines up with the border (someties due to velocity it didn't quite line up
               
            }
            ballStartingLocation.position.y = borderBottom.position.y + ballStartingLocation.frame.height / 2 + 5
            self.addChild(ballStartingLocation)
            // Remove the ball
            ball.node?.removeFromParent()
            hasFirstBallReturned = false
        }
        else
        {
            
            // Freeze movement
            ball.node?.physicsBody?.restitution = 1.0
            ball.isDynamic = false
            if let node = ball.node {
                let moveBall = SKAction.moveTo(y: borderBottom.position.y + node.frame.height / 2, duration: 0.2)
                node.run(moveBall)
            }
            // if it is not the first ball, we are animate it so that it goes to the first ball
            
            let moveToCenter = SKAction.moveTo(x: ballStartingLocation.position.x, duration: 0.4)
            let remove = SKAction.removeFromParent()
            let check = SKAction.run(checkIfRoundIsOver)
            let moveAndRemove = SKAction.sequence([moveToCenter, remove, check])
            ball.node?.run(moveAndRemove)
        }
    }

    // algorithm to detect if a ball is flying horizontally -> prevention from a never ending game
    func isBallStuckSideways( ballHit:SKPhysicsBody )
    {
        if let ball = ballHit.node as? GameBall
        {
            let bandNum = Int(abs( ball.position.y/ballZoneHeight) )

            if ball.previousBand == bandNum
            {
                // We are still in the same bracket...
                ball.samePositionCount += 1
                
                if ball.samePositionCount >= 3
                {
                    // Shove the ball out of alignment a random amount
                    ball.physicsBody?.applyImpulse(CGVector(dx: 0, dy: Int.random(in: 35...90)))
                    ball.samePositionCount = 0
                    
                    #if DEBUG
                    print("Band: \(bandNum) Previous Band: \(ball.previousBand) SamePositionCount: \(ball.samePositionCount)")
                    print("GIVING BALL A SHOVE")
                    #endif
                }
            }
            else
            {
                ball.previousBand = bandNum
            }
        }
    }
    
    // A collision has happened!
    func didBegin(_ contact: SKPhysicsContact)
    {
        let firstBody = contact.bodyA
        let secondBody = contact.bodyB
        
        if (firstBody.node?.name == "borderBottom" && secondBody.categoryBitMask == PhysicsCategory.Ball)
        {
            BallHitBottom(ball: secondBody)
        }
        else if (firstBody.categoryBitMask == PhysicsCategory.Ball && secondBody.node?.name == "borderBottom")
        {
            BallHitBottom(ball: firstBody)
        }
        else if (firstBody.categoryBitMask == PhysicsCategory.Ball && secondBody.categoryBitMask == PhysicsCategory.Brick)
        {
            if let secondBody = secondBody.node {
                BrickHit( nodeHit: secondBody )
            }
        }
        else if (secondBody.categoryBitMask == PhysicsCategory.Ball && firstBody.categoryBitMask == PhysicsCategory.Brick)
        {
            if let firstBody = firstBody.node {
                BrickHit( nodeHit: firstBody )
            }
        }
        else if (firstBody.categoryBitMask == PhysicsCategory.Ball && secondBody.node?.name == "borderLeft")
        {
            isBallStuckSideways(ballHit: firstBody)
        }
        else if (firstBody.node?.name == "borderLeft" && secondBody.categoryBitMask == PhysicsCategory.Ball)
        {
            isBallStuckSideways(ballHit: secondBody)
        }
        
        // See if all moving balls have stopped
        checkIfRoundIsOver()

    }
    func checkIfRoundIsOver()
    {
        if !gameOver
        {
            roundOver = true
            for node in self.children
            {
                // Do we still have balls being released?  Or any active ones?
                if node.name == "ball" || ballsReleased < numBallsTotal
                {
                    //TODO:  What if it has been a LONG time?  Ball could be stuck.
                    roundOver = false
                }
            }
            
            if roundOver
            {
                presentingViewController?.finalScore = totalScore
                gameDelegate?.scoreUpdated(Double(totalScore))
                createBricks()
                createNumberBallsLabel()

                if ballStartingLocation.position.x >= 0
                {
                    ballsRemainingLabel.position = CGPoint(x: ballStartingLocation.position.x -  ballStartingLocation.frame.width, y: ballStartingLocation.position.y - ballsRemainingLabel.frame.height / 2)
                } else {
                    ballsRemainingLabel.position = CGPoint(x: ballStartingLocation.position.x +  ballStartingLocation.frame.width, y: ballStartingLocation.position.y - ballsRemainingLabel.frame.height / 2)
                }
                
                //scoreLabel.text = "\(totalScore)"
                touchIsEnabled = true
                hasFirstBallReturned = true
            }
        }
    }
    
    func checkIfGameIsOver()
    {
        // the game is over when a box has moved to the bottom
        if !gameOver
        {
            for node in self.children
            {
                // We only care about Brick objects
                if let brick = node as? Brick
                {
                    // 9 means they have hit bottom
                    if brick.rowsMoved >= 9
                    {
                        //pauseButton.isHidden = true
                        gameOver = true
                    }
                }
            }
            
            if gameOver {
                labelTimer.invalidate()
                executeGameOver()
                totalScore = 0
            }
        }
    }
    
    func createMainMenuBallDisplay()
    {
        showBall()
        ballStartingLocation.position = CGPoint(x: playBackGround.position.x, y: playBackGround.position.x + playBackGround.frame.height * 2)
        ballStartingLocation.physicsBody = SKPhysicsBody(circleOfRadius: ballStartingLocation.frame.width / 2)
        ballStartingLocation.physicsBody?.affectedByGravity = true
        ballStartingLocation.physicsBody?.categoryBitMask = PhysicsCategory.Ball
        ballStartingLocation.physicsBody?.contactTestBitMask = PhysicsCategory.Border
        ballStartingLocation.physicsBody?.collisionBitMask = PhysicsCategory.Border
        ballStartingLocation.physicsBody?.friction = 0.0
        ballStartingLocation.physicsBody?.restitution = 1.0
        ballStartingLocation.physicsBody?.angularDamping = 0.0
        ballStartingLocation.physicsBody?.linearDamping = 0.1
        ballStartingLocation.physicsBody?.mass = 0.056
    }
    
    func MainGameSceneMenu()
    {
        menuVisible = true
        gameOverVisible = false
        startGame()
    }
    func executeGameOver()
    {
        numBallsTotal = 0
        self.children.forEach({ element in
            if (element.name == "ball" || element.name == "mainball"){
                element.isPaused = true
                element.removeFromParent()
                
            }
        })
        
        menuVisible = false
        gameOverVisible = true
        presentingViewController?.finalScore = totalScore
        presentingViewController?.gameLevel = levelNumber
        presentingViewController?.stopGame()
    }
    
    func createInGameMenuTop() {
        menuRect = SKShapeNode(rectOf: CGSize(width: self.frame.width, height: self.frame.height / 2 - yBrickRowStart))
        menuRect.position = CGPoint(x: 0, y: yBrickRowStart + menuRect.frame.height / 2)
        menuRect.fillColor = SKColor.black
        menuRect.strokeColor = SKColor.black
        menuRect.zPosition = 4
        menuRect.name = "menuRect"
        self.addChild(menuRect)
        
        totalScore = 0
        scoreLabel = SKLabelNode(text: "0")
        scoreLabel.fontSize = self.frame.width / 7
        scoreLabel.fontName = "Damascus"
        scoreLabel.fontColor = #colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1)
        scoreLabel.position = CGPoint(x: 0, y: yBrickRowStart + 0.35 * (scoreLabel.frame.height) + (self.frame.width / 14))
        scoreLabel.zPosition = 5
        scoreLabel.name = "scoreLabel"
        self.addChild(scoreLabel)
        
        // TODO: ADD FUNCTION TO ADD APPROPRIATE (st, nd, rd, th) ENDING
        // TODO: RANK POSITION LABEL HERE
        positionLabel = SKLabelNode(text: "")
        positionLabel.fontSize = self.frame.width / 21
        positionLabel.fontName = "Damascus"
        positionLabel.fontColor = #colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1)
        positionLabel.position = CGPoint(x: 0, y: yBrickRowStart + 0.35 * (scoreLabel.frame.height))
        positionLabel.zPosition = 5
        positionLabel.name = "scoreLabel"
        positionLabel.alpha = 1

        self.updateToBeatLabel()
        self.addChild(positionLabel)
    }
    
    // How many left?
    func createNumberBallsLabel()
    {
        ballsRemainingLabel = SKLabelNode(text: "\(numBallsTotal)")
        ballsRemainingLabel.fontSize = self.frame.width / 20
        ballsRemainingLabel.fontName = "Damascus"
        ballsRemainingLabel.fontColor = SKColor.white

        if ballOriginLocation.x >= 0
        {
            ballsRemainingLabel.position = CGPoint(x: ballOriginLocation.x -  1.2*ballStartingLocation.frame.width, y: ballOriginLocation.y - ballsRemainingLabel.frame.height / 2)
        } else {
            ballsRemainingLabel.position = CGPoint(x: ballOriginLocation.x + 1.2*ballStartingLocation.frame.width, y: ballOriginLocation.y - ballsRemainingLabel.frame.height / 2)
        }
        ballsRemainingLabel.zPosition = 5
        ballsRemainingLabel.name = "ballsLeftLabel"
        self.addChild(ballsRemainingLabel)
    }
    
    
    func deleteGameOverView()
    {
        // gets called when the user chose to watch a video ad to get one more chance
        gameOverVisible = false
        
        for child in self.children
        {
            if let box = child as? Brick
            {
                // Remove last couple rows and let player have one extra life?
                if box.rowsMoved >= 8
                {
                    box.removeFromParent()
                    for child in self.children
                    {
                        if box.contains(child.position)
                        {
                            child.removeFromParent()
                        }
                    }
                }
            }
        }
        darkerBackgroundRect.removeFromParent()
        menuRect.removeFromParent()
        quitButton.removeFromParent()
        endGameLabel.removeFromParent()
    }
    
    // How fast are the balls released?  Should this be variable?
    func startLaunchTimer()
    {
        ballTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(launchBall), userInfo: nil, repeats: true)
    }
    
    func startGame()
    {
        //TODO: Jared
        updateToBeatLabel()
        //TODO: Replace with game state
        menuVisible = false
        gameOverVisible = false
        gameOver = false

        touchIsEnabled = true
        hasFirstBallReturned = true
        xBrickStart = -self.frame.width  / 2 + self.frame.width / 14
        numBallsTotal = 0
        levelNumber = 0

        // Adding the timer like BBTAN had
        timeLeftMin = 29
        timeLeftSec = 59
        
        createInGameMenuTop()
        createBorder()
        createBricks()
        showBall()
        createNumberBallsLabel()
       
        // Check if the ball is in a good position to start
        if ballStartingLocation.position.x >= 0
        {
            ballsRemainingLabel.position = CGPoint(x: ballStartingLocation.position.x -  ballStartingLocation.frame.width, y: ballStartingLocation.position.y - ballsRemainingLabel.frame.height / 2)
        }else
        {
            ballsRemainingLabel.position = CGPoint(x: ballStartingLocation.position.x +  ballStartingLocation.frame.width, y: ballStartingLocation.position.y - ballsRemainingLabel.frame.height / 2)
        }
        updateToBeatLabel()
    }

    
    // Moving to this view - called right before we get started
    override func didMove(to view: SKView)
    {
        gameOver = true
        gameState = .GameOver

        self.view?.scene?.backgroundColor = SKColor.black
        
        // Call me for physics collisions
        physicsWorld.contactDelegate = self
        
        ballSize = self.frame.width / 50        // Default - we will make it so you can pick different balls
        ballColor = SKColor.white               // Color should be part of unlocked balls too

        // Setup starting positions
        xBrickStart = -self.frame.width  / 2 + self.frame.width / 14
        yBrickRowStart = self.frame.height / 2 - self.frame.height / 5 +  self.frame.width / 7
        yBrickStart = self.frame.height / 2 - self.frame.height / 5 + self.frame.width / 14
        
        ballZoneHeight = ceil( self.frame.height / 25.0)
       
        // Range of colors
        colorsPrimary = [
            1 : UIColor(red: 0/255, green: 104/255, blue: 132/255, alpha: 1.0),
            2 : UIColor(red: 0/255, green: 144/255, blue: 158/255, alpha: 1.0),
            3 : UIColor(red: 137/255, green: 219/255, blue: 236/255, alpha: 1.0),
            4 : UIColor(red: 237/255, green: 0/255, blue: 38/255, alpha: 1.0),
            5 : UIColor(red: 250/255, green: 157/255, blue: 0/255, alpha: 1.0),
            6 : UIColor(red: 255/255, green: 208/255, blue: 141/255, alpha: 1.0),
            7 : UIColor(red: 176/255, green: 0/255, blue: 81/255, alpha: 1.0),
            8 : UIColor(red: 246/255, green: 131/255, blue: 112/255, alpha: 1.0),
            9 : UIColor(red: 254/255, green: 171/255, blue: 185/255, alpha: 1.0),
            10 : UIColor(red: 110/255, green: 0/255, blue: 108/255, alpha: 1.0),
            11: UIColor(red: 145/255, green: 39/255, blue: 143/255, alpha: 1.0),
            12: UIColor(red: 207/255, green: 151/255, blue: 215/255, alpha: 1.0),
            13: UIColor(red: 0/255, green: 0/255, blue: 0/255, alpha: 1.0),
            14: UIColor(red: 91/255, green: 91/255, blue: 91/255, alpha: 1.0),
            15: UIColor(red: 212/255, green: 212/255, blue: 212/255, alpha: 1.0),
        ]
        
        // Alternate Color range?
        colorsSecondary = [
            1 : UIColor(red: 200/255, green: 112/255, blue: 126/255, alpha: 1.0),
            2 : UIColor(red: 226/255, green: 143/255, blue: 173/255, alpha: 1.0),
            3 : UIColor(red: 239/255, green: 180/255, blue: 193/255, alpha: 1.0),
            4 : UIColor(red: 228/255, green: 142/255, blue: 88/255, alpha: 1.0),
            5 : UIColor(red: 237/255, green: 170/255, blue: 125/255, alpha: 1.0),
            6 : UIColor(red: 240/255, green: 199/255, blue: 171/255, alpha: 1.0),
            7 : UIColor(red: 90/255, green: 160/255, blue: 141/255, alpha: 1.0),
            8 : UIColor(red: 76/255, green: 146/255, blue: 177/255, alpha: 1.0),
            9 : UIColor(red: 168/255, green: 200/255, blue: 121/255, alpha: 1.0),
            10: UIColor(red: 103/255, green: 143/255, blue: 174/255, alpha: 1.0),
            11: UIColor(red: 172/255, green: 153/255, blue: 193/255, alpha: 1.0),
            12: UIColor(red: 150/255, green: 177/255, blue: 208/255, alpha: 1.0),
            13: UIColor(red: 192/255, green: 136/255, blue: 99/255, alpha: 1.0),
            14: UIColor(red: 173/255, green: 167/255, blue: 89/255, alpha: 1.0),
            15: UIColor(red: 200/255, green: 194/255, blue: 189/255, alpha: 1.0),
        ]
        
        //TODO: Add more color themes https://i.pinimg.com/originals/3e/38/7f/3e387fae0f07d2d28fe6ea6acfb1a69d.png

        
        MainGameSceneMenu()
        
    }

    
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?)
    {

        // Remove old pointer
        deletePointer()
    
        for touch in touches
        {
            let location = touch.location(in: self)
            touchDidMove(location: location)
        }
    }
    
    // This forces us to drag DOWN from the bottom border...
    func touchDidMove(location: CGPoint) {
        if location.y < borderBottom.position.y {
            let pointer_path:CGMutablePath = CGMutablePath()
            pointer_path.move(to: ballStartingLocation.position)
            pointer_path.addLine(to: CGPoint(x: ballStartingLocation.position.x - (location.x), y: ballStartingLocation.position.y - GamePointer.multiplier * ((location.y - ballStartingLocation.position.y)/2) + 50))
            
            let newPointer = GamePointer(newPath: pointer_path)
            
            self.addChild(newPointer)
        }
    }
   
    // Depending on the game state, we have some work to do
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        for touch in touches
        {
            let location = touch.location(in: self)
            prepareToThrow(location: location)
        }
        
        deletePointer()
    }

    func prepareToThrow(location: CGPoint) {
        if menuVisible {
            if playBackGround.contains(location) {
                self.removeAllChildren()
                startGame()
            } else if ballBackGround.contains(location) {
                ballStartingLocation.removeFromParent()
                // Ball gets bigger with each color
                ballSize /= 1.2
                
                // Rotate through ball colors
                // TODO: Replace with color pallete
                if ballColor == SKColor.white {
                    ballColor = SKColor.green
                } else if ballColor == SKColor.green {
                    ballColor = SKColor.red
                } else if ballColor == SKColor.red {
                    ballColor = SKColor.blue
                } else {
                    ballColor = SKColor.white
                    // Reset ball size
                    ballSize = self.frame.width / 40
                }
                
                createMainMenuBallDisplay()
                circleShape.alpha = 1.0
            } else {
                playBackGround.alpha = 1.0
                playButtonShape.alpha = 1.0
                ballBackGround.alpha = 1.0
                circleShape.alpha = 1.0
            }
        } else if gameOverVisible {
            if quitButton.contains(location) {
                self.removeAllChildren()
                gameOverVisible = false
                MainGameSceneMenu()
            } else {
                endGameLabel.alpha = 1.0
                oneMoreLabel.alpha = 1.0
                chanceLabel.alpha = 1.0
            }
        } else if touchIsEnabled // GameState = Playing
        {
            // TODO: Change so you can drag up or down
            // Prepare to launch balls
            if location.y < borderBottom.position.y
            {
                if !ballStartingLocation.contains(location)
                {
                    throwBalls(location: location)
                }
            }
        }
    }
    
    
    func throwBalls(location: CGPoint) {
        ballsReleased = 0
        //ballLaunchPosition.removeFromParent()
        
        //var newLocation = location
        //newLocation.x *= -1
        
        ballTargetLocation = CGPoint(x: ballStartingLocation.position.x - (location.x), y: ballStartingLocation.position.y - GamePointer.multiplier * ((location.y - ballStartingLocation.position.y)/2) + 50)
        
        ballLaunchPosition = SKShapeNode(circleOfRadius: ballStartingLocation.frame.width / 2)
        ballLaunchPosition.fillColor = ballColor
        ballLaunchPosition.strokeColor = ballColor
        ballLaunchPosition.zPosition = 10
        // We have to copy this now because the starting position will change when first ball returns!
        ballLaunchPosition.position = ballStartingLocation.position
        ballLaunchPosition.name = "startingBallLocation"
        
        // Track the origin of this turn (must be done before removing, or you get 0!)
        ballOriginLocation = ballStartingLocation.position
        ballStartingLocation.removeFromParent()
        ballsRemainingLabel.removeFromParent()
        
        self.addChild(ballLaunchPosition)
        
        // Add a label to show the user how many more are remaining
        createNumberBallsLabel()
        // Start the balls launching
        startLaunchTimer()
        
        touchIsEnabled = false
    }
        
    // Called before each frame is rendered
    override func update(_ currentTime: TimeInterval)
    {

    }
    
    class GameBall : SKShapeNode
    {
        // We lump the screen into buckets the size of the bricks.  Ball hitting same zone we give it a little shove
        var previousBand = Int(0)
        var samePositionCount = 0
        //TODO:  Could we add hitpoints here too so that balls die?
    }
    
    // Show the start screen ball, and the one at the bottom of the screen during levels
    func showBall()
    {
        ballStartingLocation = SKShapeNode(circleOfRadius: ballSize)
        ballStartingLocation.fillColor = ballColor
        ballStartingLocation.strokeColor = ballColor
        ballStartingLocation.position = CGPoint(x: 0, y: borderBottom.position.y + ballStartingLocation.frame.height / 2 + 5)
        ballStartingLocation.zPosition = 4
        ballStartingLocation.name = "mainBall"
        ballOriginLocation = ballStartingLocation.position
        self.addChild(ballStartingLocation)
    }
    
    @objc func launchBall()
    {

        // Are there still more balls to release?
        if ballsReleased < numBallsTotal
        {
            if numBallsTotal - ballsReleased > 0
            {
                ballsRemainingLabel.text = "\(numBallsTotal - ballsReleased)"
            }
            else
            {
                ballsRemainingLabel.removeFromParent()
            }

            let ball = GameBall(circleOfRadius: ballSize)
            ball.fillColor = ballColor
            ball.strokeColor = ballColor
            ball.position = ballLaunchPosition.position
            ball.physicsBody = SKPhysicsBody(circleOfRadius: ball.frame.height / 2)
            ball.physicsBody?.categoryBitMask = PhysicsCategory.Ball
            ball.physicsBody?.contactTestBitMask = PhysicsCategory.Brick | PhysicsCategory.Border
            ball.physicsBody?.collisionBitMask = PhysicsCategory.Brick | PhysicsCategory.Border
            ball.physicsBody?.affectedByGravity = false
            ball.physicsBody?.isDynamic = true
            ball.physicsBody?.friction = 0
            ball.physicsBody?.restitution = 1.0
            ball.physicsBody?.angularDamping = 0.0
            ball.physicsBody?.linearDamping = 0.0
            ball.name = "ball"
            ball.zPosition = 3
            ball.physicsBody?.mass = 0.056

            self.addChild(ball)

            let x = ballTargetLocation.x - ballOriginLocation.x
            let y = ballTargetLocation.y - ballOriginLocation.y
            let ratio = x/y
            let newY = CGFloat(getReleaseSpeed(a:ballOriginLocation, b: ballTargetLocation)/(sqrt(Double(1 + (ratio * ratio)))))
            let newX = CGFloat(ratio * newY)
            
            // Add some push
            ball.physicsBody?.applyImpulse(CGVector(dx: newX, dy: newY))
            ballsReleased += 1
            
        }
        else
        {
            // No more balls
            ballTimer.invalidate()
            ballLaunchPosition.removeFromParent()
            //ballStartingLocation.removeFromParent()
            ballsRemainingLabel.removeFromParent()
        }
    }

    // How fast to send ball?
    func getReleaseSpeed(a: CGPoint, b: CGPoint) -> Double
    {
        let xDist = a.x - b.x
        let yDist = a.y - b.y
        let distance = CGFloat(sqrt((xDist * xDist) + (yDist * yDist)))

        // Based on how far it was dragged out
        if distance < self.frame.width / 6
        {
            return 75
        }
        else if distance < self.frame.width / 4
        {
            return 75
        }
        else if distance < self.frame.width / 2
        {
            return 75
        }
        else
        {
            return 75
        }
    }
    
    class Brick : SKSpriteNode
    {
        var hitpoints = 1                               // Hitpoints for this brick
        var rowsMoved = 1                               // How many rows have we moved?
        var hitpointsLabel = SKLabelNode( text: "-")    // The label tp show hitpoints
    }
    


    // We are all just bricks in the wall
    func createBricks()
    {
        var rowMetadata = [Int]()
        
        levelNumber += 1
        numBallsTotal += 1
        xBrickStart = -self.frame.width / 2 + self.frame.width / 14
        
        // Choose a color for the new row from our list of colors
        let randomColor = getRandomColor()


        // Go through each slot and randomly choose if it will have a brick (in the wall)
        for _ in 1..<8
        {
            // We seed the RNG to get the same output per game
            
            guard let gameDelegate else {
                fatalError("No game delegate set")
            }
            
            let randomBool = gameDelegate.nextRandom() >= 0.5

            if randomBool {
                let gameBrick = Brick(color: randomColor, size: CGSize(width: self.frame.width / 7.4, height: self.frame.width / 7.4))
                let brickHitLabel = Brick(color: SKColor.black, size: CGSize(width: self.frame.width / 8.8, height: self.frame.width / 8.8))
                
                gameBrick.position = CGPoint(x: xBrickStart, y: yBrickRowStart - gameBrick.frame.height / 2)
                brickHitLabel.zPosition = 2
                gameBrick.hitpoints = Int(pow(Double(numBallsTotal), 1.2))
                gameBrick.name = "brick"
                brickHitLabel.name = "bricklabel"
                gameBrick.zPosition = 1
                gameBrick.physicsBody = SKPhysicsBody(rectangleOf: gameBrick.size)
                gameBrick.physicsBody?.categoryBitMask = PhysicsCategory.Brick
                gameBrick.physicsBody?.contactTestBitMask = PhysicsCategory.Ball
                gameBrick.physicsBody?.collisionBitMask = PhysicsCategory.Ball
                gameBrick.physicsBody?.affectedByGravity = false
                gameBrick.physicsBody?.isDynamic = false
                gameBrick.physicsBody?.friction = 0
                gameBrick.physicsBody?.restitution = 1.0
                
                gameBrick.hitpointsLabel = SKLabelNode(text: "\(Int(pow(Double(numBallsTotal), 1.2)))")
                gameBrick.hitpointsLabel.color = UIColor.red
                gameBrick.hitpointsLabel.fontSize = 48
                gameBrick.hitpointsLabel.fontName = "Damascus"
                gameBrick.hitpointsLabel.position = CGPoint(x: 0, y: -gameBrick.hitpointsLabel.frame.height / 2)
                gameBrick.hitpointsLabel.zPosition = 5

                // Everything gets parented to the box itself
                gameBrick.addChild(gameBrick.hitpointsLabel)
                gameBrick.addChild(brickHitLabel)

                self.addChild(gameBrick)
                
                rowMetadata.append(Int(pow(Double(numBallsTotal), 1.2)))

            } else {
                rowMetadata.append(0)
            }
            
            // Step to the next position
            xBrickStart += self.frame.width / 7

        }
                
        var levelBrickArrayAfterShotValueLocal = [Int]()
        var levelBrickArrayAfterShotPositionsLocal = [[CGFloat]]()
        
        for node in self.children
        {
            if let box = node as? Brick
            {
                levelBrickArrayAfterShotValueLocal.append(box.hitpoints)
                levelBrickArrayAfterShotPositionsLocal.append([node.position.x, node.position.y])
                box.rowsMoved += 1
                // setting up the action so that the boxes move down and then a function is called to check whether the game is over or not
                let moveDown = SKAction.moveTo(y: node.position.y - self.frame.width / 7, duration: 0.8)
                let checkIfGameOver = SKAction.run(checkIfGameIsOver)
                let moveDownCheck = SKAction.sequence([moveDown, checkIfGameOver])
                box.run(moveDownCheck)
                
            }
        }
    }
    
    func getRandomColor() -> UIColor {
        guard let gameDelegate else {
            fatalError("No game delegate set")
        }
        let colors = [#colorLiteral(red: 0.521568656, green: 0.1098039225, blue: 0.05098039284, alpha: 1),#colorLiteral(red: 1, green: 0.3046892881, blue: 0.1803869009, alpha: 1),#colorLiteral(red: 1, green: 0.2694630623, blue: 0.1145585105, alpha: 1),#colorLiteral(red: 1, green: 0.1713389158, blue: 0.05485698581, alpha: 1),#colorLiteral(red: 0.9494506717, green: 0, blue: 0, alpha: 1),#colorLiteral(red: 0.9907203317, green: 0.1932799816, blue: 0.08157064766, alpha: 1),#colorLiteral(red: 0.8950471282, green: 0, blue: 0.1178193167, alpha: 1),#colorLiteral(red: 0.9951544404, green: 0.3653846681, blue: 0, alpha: 1),#colorLiteral(red: 1, green: 0.4513577819, blue: 0.01917774603, alpha: 1)]
        let index = UInt32(gameDelegate.nextRandom(minimumInclusive: 0, maximumInclusive: Float(colors.count)))
      return colors[Int(index)]
    }
    
    func createBorders()
    {
        borderRight = SKSpriteNode()
        borderRight.size = CGSize(width: 1, height: self.frame.height)
        borderRight.position = CGPoint(x: self.frame.width / 2 , y: 0)
        borderRight.physicsBody = SKPhysicsBody(rectangleOf: borderRight.size)
        borderRight.physicsBody?.affectedByGravity = false
        borderRight.physicsBody?.isDynamic = false
        borderRight.physicsBody?.categoryBitMask = PhysicsCategory.Border
        borderRight.physicsBody?.collisionBitMask = 0
        borderRight.physicsBody?.contactTestBitMask = PhysicsCategory.Ball
        borderRight.physicsBody?.friction = 0.0
        borderRight.color = UIColor.clear
        borderRight.name = "border"
        
        borderLeft = SKSpriteNode()
        borderLeft.size = CGSize(width: 1, height: self.frame.height)
        borderLeft.position = CGPoint(x: -self.frame.width / 2 , y: 0)
        borderLeft.physicsBody = SKPhysicsBody(rectangleOf: borderLeft.size)
        borderLeft.physicsBody?.affectedByGravity = false
        borderLeft.physicsBody?.isDynamic = false
        borderLeft.physicsBody?.categoryBitMask = PhysicsCategory.Border
        borderLeft.physicsBody?.collisionBitMask = 0
        borderLeft.physicsBody?.contactTestBitMask = PhysicsCategory.Ball
        borderLeft.physicsBody?.friction = 0.0
        borderLeft.color = UIColor.clear
        borderLeft.name = "borderLeft"
        
        borderTop = SKSpriteNode()
        borderTop.size = CGSize(width: self.frame.width, height: 1)
        borderTop.position = CGPoint(x: 0, y: yBrickRowStart)
        borderTop.zPosition = 3
        borderTop.physicsBody = SKPhysicsBody(rectangleOf: borderTop.size)
        borderTop.physicsBody?.affectedByGravity = false
        borderTop.physicsBody?.isDynamic = false
        borderTop.physicsBody?.categoryBitMask = PhysicsCategory.Border
        borderTop.physicsBody?.collisionBitMask = 0
        borderTop.physicsBody?.contactTestBitMask = PhysicsCategory.Ball
        borderTop.physicsBody?.friction = 0.0
        borderTop.color = UIColor.clear
        borderTop.name = "border"
        
        borderBottom = SKSpriteNode()
        borderBottom.size = CGSize(width: self.frame.width, height: 3)
        borderBottom.position = CGPoint(x: 0, y: yBrickStart - self.frame.width / 14 - 8 * self.frame.width / 7)
        borderBottom.zPosition = 3
        borderBottom.physicsBody = SKPhysicsBody(rectangleOf: borderBottom.size)
        borderBottom.physicsBody?.affectedByGravity = false
        borderBottom.physicsBody?.isDynamic = false
        borderBottom.physicsBody?.categoryBitMask = PhysicsCategory.Border
        borderBottom.physicsBody?.collisionBitMask = 0
        borderBottom.physicsBody?.contactTestBitMask = PhysicsCategory.Ball
        borderBottom.physicsBody?.friction = 1.0
        borderBottom.color = UIColor.clear
        borderBottom.name = "borderBottom"
        
        self.addChild(borderTop)
        self.addChild(borderLeft)
        self.addChild(borderRight)
        self.addChild(borderBottom)
    }
    
    class GamePointer : SKShapeNode
    {
        static let multiplier = CGFloat(1.7)
        
        init(newPath:CGPath)
        {
            super.init()
            self.path = newPath
            self.lineWidth = CGFloat(4.0)
            self.strokeColor = #colorLiteral(red: 0.501960814, green: 0.501960814, blue: 0.501960814, alpha: 1)
            //self.fillColor = SKColor.blue
            self.zPosition = 3
        }
        
        required init?(coder aDecoder: NSCoder) {
            // NO IDEA why I need this for a class I am only going to be using
            fatalError("init(coder:) has not been implemented")
        }
        
        func hidePointer()
        {
            self.isHidden = true
        }
        
        func showPointer()
        {
            self.isHidden = false
        }
    }

    func deletePointer()
    {
        for node in self.children
        {
            // We only want the game pointer
            if let nodeShape = node as? GamePointer
            {
                nodeShape.removeFromParent()
            }
        }
    }
    
    func playSystemSound(_ id: SystemSoundID) {
        if UserDefaults.standard.bool(forKey: GamePreference.sfx.rawValue) {
            AudioServicesPlaySystemSound(id)
        }
    }
}

class CustomImpactFeedbackGenerator: UIImpactFeedbackGenerator {
    override func impactOccurred(intensity: CGFloat) {
        let preference = UserDefaults.standard.value(forKey: GamePreference.haptics.rawValue) as? Bool ?? true
        if preference {
            super.impactOccurred(intensity: intensity)
        }
    }
    
    override func impactOccurred() {
        let preference = UserDefaults.standard.value(forKey: GamePreference.haptics.rawValue) as? Bool ?? true
        if preference {
            super.impactOccurred()
        }
    }
}
