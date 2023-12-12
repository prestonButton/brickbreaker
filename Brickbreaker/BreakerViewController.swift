import GameCore
import GameplayKit
import SpriteKit
import UIKit

// Note: This game is pretty messy, but we don't really care because
// it is just our "example game" for the SDK
public final class BreakerViewController: GameViewController {
    
    public weak var gameDelegate: GameDelegate? {
        didSet {
            pauseSheet.gameDelegate = gameDelegate
        }
    }
    
    internal var delegate: GameDelegate {
        guard let gameDelegate else {
            fatalError("No game delegate set")
        }
        
        return gameDelegate
    }
    
    var tutorialShownFromTriumph: Bool?
    
    lazy var pauseSheet: GamePauseView = {
        let pauseSheet = GamePauseView()
        pauseSheet.delegate = self
        pauseSheet.gameDelegate = gameDelegate
        return pauseSheet
    }()

    // metadata stuff
    var finalScore = 0
    var gameLevel = 0

    // Game view stuff
    var scene: GameScene?
    let gameView = SKView(frame: UIScreen.main.bounds)
    var openingView = UIImageView()
    var practiceButon = UIButton()
    
    // Pause menu stuff
//    var timer: Timer?
    var counter: Int = 5
    var presenting = false
//    let pauseSheet =  UIAlertController(title: "Game Ending in 5", message: nil, preferredStyle: .alert)
    lazy var forfeitController: UIAlertController = {
        let controller = UIAlertController(
            title: "Are you sure you want to forfeit?",
            message: "Your current score will be submitted",
            preferredStyle: .alert
        )
        controller.addAction(
            UIAlertAction(
                title: "Forfeit",
                style: .destructive,
                handler: { [weak self] _ in
                    self?.pauseSheet.removeFromSuperview()
                    self?.stopGame(showGameOverViewController: false)
                    self?.dismiss(animated: true)
//                    controller.dismiss(animated: true)
                }))
        controller.addAction(
            UIAlertAction(
                title: "Cancel",
                style: .cancel,
                handler: { [weak self] _ in
                    self?.dismiss(animated: true)
//                    controller.dismiss(animated: true)
                }
            )
        )
        return controller
    }()
    
    var cashedTime: TimeInterval = 0
    var isAway = false
    var finishedGame = true
    
    let infoButton = UIButton()

    func getGamePrizeMultiple(percentile: Double) -> Double {
        if percentile <= 0.6 {
            return percentile / 0.6
        }
        
        if percentile <= 0.95 {
            return 1 + ((percentile - 0.6) / 0.35)
        }
        
        if percentile < 0.98 {
            return 20 * percentile - 17
        }

        return 20 * percentile - 15
    }
    
    func setScene() {
        scene = .load(GameScene.self, filename: "GameScene", inBundleForClass: Self.self)
        guard let scene else {
            fatalError()
        }
        
        scene.gameDelegate = gameDelegate
        scene.scaleMode = .aspectFit
        scene.presentingViewController = self
    }
    
    private var shouldStartGame = false
    private var shouldStartTutorial = false
    
    public override func viewDidDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        scene?.removeFromParent()
        scene = nil
        
//        timer?.invalidate()
//        timer = nil
    }
    
    public override func viewDidLoad() {

        gameScoreType = .higherBetter
        super.viewDidLoad()
        clockLabel.isHidden = true
//        setScene()

        view.addSubview(gameView)
        gameView.alpha = 0
        
        print(isMusicPlayerMuted)
        playBackgroundMusic()
        
        setupTutorialButton()
        setupAudioButton()
        
        if shouldStartGame {
            shouldStartGame = false
            start()
        } else if shouldStartTutorial {
            shouldStartTutorial = false
            showTutorial()
        }
    }
    
    func setupAudioButton() {
        view.addSubview(audioButton)
        audioButton.addTarget(self, action: #selector(toggleMute), for: .touchUpInside)
        audioButton.translatesAutoresizingMaskIntoConstraints = false
        audioButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10).isActive = true
        audioButton.widthAnchor.constraint(equalToConstant: 36).isActive = true
        audioButton.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 20).isActive = true
    }
    
    func setupTutorialButton() {
        view.addSubview(pauseButton)
        pauseButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            pauseButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            pauseButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            pauseButton.widthAnchor.constraint(equalToConstant: 36),
            pauseButton.heightAnchor.constraint(equalToConstant: 36),
        ])
    }
    
    func resumeGame() {
        gameDelegate?.gameResumed()
        // Reset score tracker stuff
        self.isAway = false
        self.finishedGame = true
        self.presenting = false

        // Reset timer variables
//        self.timer?.invalidate()
//        self.timer = nil
        self.counter = 5
    }
    
    override func startGame() {
        
        UIView.animate(withDuration: 1) { [weak self] in
            guard let self else { return }
            self.pauseButton.alpha = 0.3
            self.pauseButton.isHidden = false
            
            self.audioButton.alpha = 0.3
            self.audioButton.isHidden = false
        }
        
        startDisplayLink()
        beginTimestamp = 0
        finalScore = 0
//        self.timer?.invalidate()
//        self.timer = nil

        UIView.animate(withDuration: 1) { [weak self] in
            guard let self else { return }
            
            // TODO: hide brick image
            self.modeLabel.alpha = 0
            self.startLabel.alpha = 0
            self.clockLabel.alpha = 1
            self.levelLabel.alpha = 1
            self.infoButton.alpha = 0
            self.openingView.alpha = 0
        }
        
        gameView.presentScene(scene)
    }
    
    override func addMetadata() {}
    
    @objc func testing() {
        haptics.impactOccurred()
        startFirstGame()
    }
    
    override func addMetadataonExit() {}
    
    fileprivate func resetGame() {
        refresh()
        finalScore = 0
        
//        setScene()
        level = 0
        gameState = .gameOver
        stopDisplayLink()
        modeLabel.text = "" //"Score: \(finalScore.withCommas())"
        
        if elapsedTime != 0 {
            addMetadata()
        }
        
        animatingToStart = true
        UIView.animate(withDuration: 1) { [weak self] in
            guard let self else { return }
            // TODO: show brick image
            self.modeLabel.alpha = 1
            self.startLabel.alpha = 1
            self.clockLabel.alpha = 0
            self.levelLabel.alpha = 0
            self.infoButton.alpha = 1
            self.openingView.alpha = 1
            var entryword = ""
            
            if self.entries == 1 {
                entryword = ""
            }
            
        } completion: { [weak self] _ in
            self?.animatingToStart = false
            self?.gameState = .ready
        }
    }
    
    override func stopGame(showGameOverViewController: Bool = true) {
        pauseSheet.removeFromSuperview()
        forfeitController.dismiss(animated: true)
        gameDelegate?.gameFinished(with: Double(finalScore))
        resetGame()
    }

    override func infoMessage() {}
    
    public override var prefersStatusBarHidden: Bool {
        return true
    }
    
    @objc override func tutorialButtonTap() {
        UIImpactFeedbackGenerator().impactOccurred()
        showPausedMessage()
    }
    
    func startFirstGame() {
//        logoAnimationView.pause()
//        bricksAnimationView.pause()
        
        if gameState == .ready {
            startGameWithType()
            
            // haptics.impactOccurred()
            gameView.isUserInteractionEnabled = false
            gameView.alpha = 1
            gameView.isUserInteractionEnabled = true
        }
    }
    
    func showPausedMessage() {
        guard pauseSheet.superview == nil else { return }
        gameDelegate?.gamePaused()
        pauseSheet.updateView()
        view.addSubview(pauseSheet)
        pauseSheet.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pauseSheet.topAnchor.constraint(equalTo: view.topAnchor),
            pauseSheet.leftAnchor.constraint(equalTo: view.leftAnchor),
            pauseSheet.rightAnchor.constraint(equalTo: view.rightAnchor),
            pauseSheet.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    func showTutorial(fromTriumph: Bool) {
        guard isViewLoaded else {
            shouldStartTutorial = true
            return
        }
        
        tutorialShownFromTriumph = fromTriumph
        
        let viewModel = TutorialViewModel()
        viewModel.delegate = self
        
        let viewController = TutorialViewController(viewModel: viewModel)
        viewController.modalPresentationStyle = .fullScreen
        present(viewController, animated: true)
    }
}

// MARK: - TutorialViewModelDelegate

extension BreakerViewController: TutorialViewModelDelegate {
    func viewModel(playingVideoDidFinish viewModel: TutorialViewModel) {
        dismiss(animated: false)
        
        let tutorialShownFromTriumph = tutorialShownFromTriumph
        self.tutorialShownFromTriumph = nil
        guard tutorialShownFromTriumph == true else { return }
        
        gameDelegate?.tutorialFinished()
    }
}

// MARK: - TriumphSDKDelegate

extension BreakerViewController: SwiftGame {
    public var customFontNames: [String]? { nil }
    
    public func showTutorial() {
        showTutorial(fromTriumph: true)
    }

    public func start() {
        guard isViewLoaded else {
            shouldStartGame = true
            return
        }
        
        setScene()
        startFirstGame()

        guard let testScore = ProcessInfo.processInfo.environment["PLAY_TEST_GAME_MODE_SCORE"],
              let score = Int(testScore) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self = self else { return }
            self.finalScore = (0...score).randomElement() ?? 0
            self.stopGame()
        }
    }
}

// MARK: - PauseSheet delegate
extension BreakerViewController: GamePauseDelegate {
    public func isMusicPreferred() -> Bool {
        !UserDefaults.standard.bool(forKey: GamePreference.music.rawValue)
    }
    
    public func isSFXPreferred() -> Bool {
        UserDefaults.standard.bool(forKey: GamePreference.sfx.rawValue)
    }
    
    public func areHapticsPreferred() -> Bool? {
        return UserDefaults.standard.value(forKey: GamePreference.haptics.rawValue) as? Bool
    }
    
    public func musicStatusChanged(isOn: Bool) {
        isMusicPlayerMuted = !isOn
    }
    
    public func sfxStatusChanged(isOn: Bool) {
        UserDefaults.standard.set(isOn, forKey: GamePreference.sfx.rawValue)
        UserDefaults.standard.synchronize()
    }
    
    public func hapticsStatusChanged(isOn: Bool) {
        UserDefaults.standard.set(isOn, forKey: GamePreference.haptics.rawValue)
        UserDefaults.standard.synchronize()
    }
    
    public func rulesTapped() {
        showTutorial(fromTriumph: false)
    }
    
    public func continueTapped() {
        pauseSheet.removeFromSuperview()
        resumeGame()
    }
    
    public func forfeitTapped() {
        presentConfirmationOfForfeit()
    }
    
    public func presentConfirmationOfForfeit() {
        present(forfeitController, animated: true)
    }
}

enum GamePreference: String {
    case music = "isMuted"
    case sfx
    case haptics
}
