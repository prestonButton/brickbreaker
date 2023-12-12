//
//  TutorialViewModel.swift
//  TriumphSDK
//
//  Created by Maksim Kalik on 5/9/23.
//

import Foundation

protocol TutorialViewModelDelegate: AnyObject {
    func viewModel(playingVideoDidFinish viewModel: TutorialViewModel)
}

final class TutorialViewModel {
    weak var delegate: TutorialViewModelDelegate?
    
    let mainBundleVideoFileNameUrl: URL? = Bundle(for: TutorialViewModel.self).url(forResource: "tutorial", withExtension: "mp4")
    
    func playingVideoFinished() {
        delegate?.viewModel(playingVideoDidFinish: self)
    }
    
    func skipTap() {
        delegate?.viewModel(playingVideoDidFinish: self)
    }
}
