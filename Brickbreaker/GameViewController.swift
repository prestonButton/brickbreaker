import AVFoundation
import GameCore
import Lottie
import UIKit

enum GameScoreType: Int {
    case higherBetter = 0
    case lowerBetter = 1
}

enum GameState {
    case ready
    case playing
    case gameOver
}

/*
 * Superclass that all of our Triumph games inherit from.
 * Includes things like timers and useful things
 */
public class GameViewController: UIViewController {
//    lazy var logoAnimationView = LottieAnimationView(name: "bb-logo")
//    lazy var bricksAnimationView = LottieAnimationView(name: "bb-cover-noBg")
    
    lazy var pauseButton: UIButton = {
        let button = UIButton()
        button.imageView?.contentMode = .scaleAspectFit
        button.contentVerticalAlignment = .fill
        button.contentHorizontalAlignment = .fill
        button.tintColor = .white
        button.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        button.alpha = 0
        button.isHidden = true
        button.addTarget(self, action: #selector(tutorialButtonTap), for: .touchUpInside)
        return button
    }()
    
    lazy var buttonImageView: UIImageView = {
        let view = UIImageView()
        view.image = musicOnImage
        view.translatesAutoresizingMaskIntoConstraints = false
        view.tintColor = .white
        return view
    }()
    
    lazy var audioButton: UIButton = {
        let button = UIButton()
        button.tintColor = .white
        button.isHidden = true
        button.addSubview(buttonImageView)
        buttonImageView.topAnchor.constraint(equalTo: button.topAnchor).isActive = true
        buttonImageView.leftAnchor.constraint(equalTo: button.leftAnchor).isActive = true
        return button
    }()

    //MARK: - Lifecycle Methods
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupAnimation()
        addVideoObservers()
        
        self.view.backgroundColor = .black
        levelLabel.isUserInteractionEnabled = false
        modeLabel.text = gameTitle

        constraints()
    }
  
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
//        logoAnimationView.play()
//        bricksAnimationView.play()
    }
    
    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
//        logoAnimationView.pause()
//        bricksAnimationView.play()
        musicPlayer?.stop()
        musicPlayer = nil
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
//        bricksAnimationView.frame = self.view.frame
//        logoAnimationView.frame = CGRect(x: view.frame.origin.x, y: view.frame.origin.y + 150, width: view.frame.width, height: view.frame.height)
    }

    // MARK: - Audio Properties
    var musicPlayer: AVAudioPlayer?
    var isMusicPlayerMuted: Bool = UserDefaults.standard.bool(forKey: "isMuted"){
        didSet {
            if isMusicPlayerMuted {
                muteBackgroundMusic()
                buttonImageView.image = musicOffImage
                UserDefaults.standard.set(true, forKey: "isMuted")
                UserDefaults.standard.synchronize()
            } else {
                unmuteBackgroundMusic()
                buttonImageView.image = musicOnImage
                UserDefaults.standard.set(false, forKey: "isMuted")
                UserDefaults.standard.synchronize()
            }
        }
    }

    @objc func tutorialButtonTap() {
    }
    
    @objc func refresh() {
//        logoAnimationView.play()
//        bricksAnimationView.play()
        
        UIView.animate(withDuration: 1) { [weak self] in
            guard let self else { return }
            self.pauseButton.alpha = 0.3
            self.pauseButton.isHidden = true
            
            self.audioButton.alpha = 0.3
            self.audioButton.isHidden = true
        }
    }

    @objc func shutItDown() {

    }

    func pause() {
        print("Pause")
    }

    func setupAnimation() {
//        view.addSubview(logoAnimationView)
//        view.addSubview(bricksAnimationView)
//        logoAnimationView.play()
//        logoAnimationView.loopMode = .loop
//        logoAnimationView.contentMode = .scaleAspectFill
//        
//        bricksAnimationView.play()
//        bricksAnimationView.loopMode = .loop
//        bricksAnimationView.contentMode = .scaleAspectFill
    }

    let gameTitle = ""
    
    // Sound
    var menuSoundtrack = ""
    
    var gameSoundtrack = ""

    var isPractice: Bool = true
    
    var gameId = -1 // game id to be overwritten
    
    var animatingToStart = false
    
    var gameState = GameState.ready
    
    var gameScoreType = GameScoreType.higherBetter {
        didSet {
            levelLabel.isHidden = (gameScoreType == .higherBetter)
        }
    }
    
    var entries = 0
    
    var haptics = UIImpactFeedbackGenerator()
    let modeLabel = UILabel()
    let startLabel = UILabel()
    let FAQButton = UIButton()
    let clockLabel = UILabel()
    let levelLabel = UILabel()
    
    private let musicOnImage = UIImage(systemName: "speaker.wave.3.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 28))
    private let musicOffImage = UIImage(systemName: "speaker.slash.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 28))
    
    var displayLink: CADisplayLink?
    
    var beginTimestamp: TimeInterval = 0
    var elapsedTime: TimeInterval = 0
    
    
    var numberOfRounds = 3
    
    var level = 0 {
        didSet {
            levelLabel.text = "Round \(level)/\(numberOfRounds-1)"
            if level == numberOfRounds {
                gameOver()
            }
        }
    }
    
    
    
    func gameOver() {
        stopGame()
    }

    // Overwrite this for each game
    func addMetadata() {}
    
    func addMetadataonExit() {}
    
    // Add score and metadata to the game. Should be overwritten
    func stopGame(showGameOverViewController: Bool = true) {
        refresh()
        level = 0
        gameState = .gameOver
        
        //Music.shared.startMp3(track: self.menuSoundtrack)
        stopDisplayLink()
        modeLabel.text = "Score: \(fullFormat(timeInterval: elapsedTime))"

        if elapsedTime != 0 {
            addMetadata()
        }
        
        
        animatingToStart = true
        UIView.animate(withDuration: 1) { [weak self] in
            guard let self else { return }
            self.modeLabel.alpha = 1
            self.startLabel.alpha = 1
            self.clockLabel.alpha = 0
            self.levelLabel.alpha = 0
        } completion: { [weak self] _ in
            self?.animatingToStart = false
        }
    }
    
    func startGame() {
        startDisplayLink()
        beginTimestamp = 0
        UIView.animate(withDuration: 1) { [weak self] in
            guard let self else { return }
            self.modeLabel.alpha = 0
            self.startLabel.alpha = 0
            self.clockLabel.alpha = 1
            self.levelLabel.alpha = 1
        }
        
    }
    
    func startGameWithType() {
        shutItDown()
        gameState = .playing
        startGame()
    }
    
    func startDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(tick(sender:)))
        displayLink?.add(to: RunLoop.main, forMode: RunLoop.Mode.default)
    }
    
    func stopDisplayLink() {
        displayLink?.isPaused = true
        displayLink?.remove(from: RunLoop.main, forMode: RunLoop.Mode.default)
        displayLink = nil
    }
    
    @objc func tick(sender: CADisplayLink) {
        updateCountUpTimer(timestamp: sender.timestamp)
        onTick()
    }
    
    func updateCountUpTimer(timestamp: TimeInterval) {
        
        if beginTimestamp == 0 {
            beginTimestamp = timestamp
        }
        
        elapsedTime = timestamp - beginTimestamp
        clockLabel.text = format(timeInterval: elapsedTime)
    }
    
    func format(timeInterval: TimeInterval) -> String {
        let interval = Int(timeInterval)
        var seconds = interval % 60
        let minutes = (interval / 60) % 60
        seconds += (minutes * 60)
        return String(seconds)
    }
    
    func fullFormat(timeInterval: TimeInterval) -> String {
        let interval = Int(timeInterval)
        let seconds = interval % 60
        let minutes = (interval / 60) % 60
        let milliseconds = Int(timeInterval * 1000) % 1000
        var myString = String(format: "%02d:%02d.%03d", minutes, seconds, milliseconds)
        myString.removeLast()
        return myString
    }
    
    func onSetGameType() {}
    
    func onTick() {}
    
    @objc func message() {
        infoMessage()
    }
    
    func infoMessage() {
        // OVERRIDE
    }

    func constraints() {
        view.addSubview(modeLabel)
        modeLabel.translatesAutoresizingMaskIntoConstraints = false
        modeLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40).isActive = true
        modeLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        modeLabel.textAlignment = .center
        modeLabel.font = UIFont.systemFont(ofSize: 36, weight: .medium)
        modeLabel.textColor = .white
        
        view.addSubview(startLabel)
        startLabel.textColor = #colorLiteral(red: 0.8039215803, green: 0.8039215803, blue: 0.8039215803, alpha: 1)
        startLabel.textAlignment = .center
        startLabel.numberOfLines = 0
        startLabel.font = UIFont.systemFont(ofSize: 18, weight: .regular)
        startLabel.translatesAutoresizingMaskIntoConstraints = false
        startLabel.topAnchor.constraint(equalTo: modeLabel.bottomAnchor, constant: 10).isActive = true
        startLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: 0).isActive = true
        
        // Clock label constraints
        view.addSubview(clockLabel)
        clockLabel.translatesAutoresizingMaskIntoConstraints = false
        clockLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10).isActive = true
        clockLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        clockLabel.textAlignment = .center
        clockLabel.font = UIFont.systemFont(ofSize: 48, weight: .medium)
        clockLabel.textColor = #colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1)
        clockLabel.alpha = 0
        
        view.addSubview(levelLabel)
        levelLabel.translatesAutoresizingMaskIntoConstraints = false
        levelLabel.topAnchor.constraint(equalTo: clockLabel.bottomAnchor, constant: 0).isActive = true
        levelLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        levelLabel.textAlignment = .center
        levelLabel.font = UIFont.systemFont(ofSize: 21, weight: .medium)
        levelLabel.textColor = #colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1)
        levelLabel.alpha = 0
        levelLabel.text = ""
        
        
    }
    
    @objc func appWillTerminate() {

    }

    @objc func appMovedToBackground() {
        moveBackground()
    }

    @objc func appMovedToForeground() {
        moveForeground()
    }

    func moveForeground() {}

    func moveBackground() {
        addMetadataonExit()
    }
    
    // gray out the home bar while the game is being played!
    public override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
        return [.bottom]
    }
    
}

extension GameViewController {

    func addVideoObservers() {
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(didEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(willEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        
        // prevent misc other freezes
        notificationCenter.addObserver(self, selector: #selector(didEnterBackground), name: UIApplication.willResignActiveNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(willEnterForeground), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    // Responding methods
    @objc func didEnterBackground() {
//        logoAnimationView.pause()
//        bricksAnimationView.pause()
    }
    
    @objc func willEnterForeground() {
        guard presentedViewController == nil else { return }
//        logoAnimationView.play()
//        bricksAnimationView.play()
    }
    
}

// MARK: - Music

extension GameViewController {
    func playBackgroundMusic() {
        if let url = Bundle(for: Self.self).url(forResource: "background", withExtension: "mp3") {
            do {
                try AVAudioSession.sharedInstance().setCategory(.ambient)
                try AVAudioSession.sharedInstance().setActive(true)
                musicPlayer = try? AVAudioPlayer(contentsOf: url)
                if AVAudioSession.sharedInstance().isOtherAudioPlaying {
                    // If music is playing, default game music to mute
                    isMusicPlayerMuted = true
                } else if isMusicPlayerMuted {
                    muteBackgroundMusic()
                    buttonImageView.image = musicOffImage
                } else {
                    musicPlayer?.numberOfLoops = -1
                    musicPlayer?.volume = 0.6
                    musicPlayer?.prepareToPlay()
                    musicPlayer?.play()
                }
            } catch {
                print(error)
            }
        }
    }
    
    func muteBackgroundMusic() {
        musicPlayer?.pause()
    }
    
    func unmuteBackgroundMusic() {
        musicPlayer?.play()
    }
    
    @objc func toggleMute() {
        print(UserDefaults.standard.bool(forKey: "isMuted"))
        haptics.prepare()
        haptics.impactOccurred(intensity: 0.3)
        isMusicPlayerMuted.toggle()
    }
}
