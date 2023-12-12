//
//  TutorialViewController.swift
//  TriumphSDK
//
//  Created by Maksim Kalik on 5/9/23.
//

import AVKit
import UIKit

final class TutorialViewController: UIViewController {
    private let viewModel: TutorialViewModel
    private let playerController = AVPlayerViewController()
    private var playerLayer: AVPlayerLayer?

    private lazy var skipButton: UIButton = {
        let button = UIButton()
        button.setTitle("Skip", for: .normal)
        button.addTarget(self, action: #selector(skipButtonTap), for: .touchUpInside)
        button.setTitleColor(.white, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.layer.cornerRadius = 8
        button.layer.backgroundColor = UIColor.white.withAlphaComponent(0.1).cgColor
        return button
    }()
    
    init(viewModel: TutorialViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupVideo()
        view.backgroundColor = #colorLiteral(red: 0.09019607843, green: 0.09019607843, blue: 0.09019607843, alpha: 1)
        
        setupSkipButton()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        playerLayer?.frame = self.view.frame
    }

    private func setupSkipButton() {
        view.addSubview(skipButton)
 
        let bottomConstant = UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0
        NSLayoutConstraint.activate([
            skipButton.heightAnchor.constraint(equalToConstant: 40),
            skipButton.widthAnchor.constraint(equalToConstant: 120),
            skipButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -bottomConstant),
            skipButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
        ])
    }
    
    @objc func playerDidFinishPlaying() {
        playingVideoFinished()
    }
    
    @objc func skipButtonTap() {
        viewModel.skipTap()
    }
    
    private func playingVideoFinished() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.viewModel.playingVideoFinished()
        }
    }
    
    func setupVideo() {
        guard let url = viewModel.mainBundleVideoFileNameUrl else { return }
        
        let player = AVPlayer(url: url)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem
        )
        
        playerController.player = player
        playerController.showsPlaybackControls = false
        
        addChild(playerController)
        view.addSubview(playerController.view)
        player.isMuted = true
        player.play()
    }
}
