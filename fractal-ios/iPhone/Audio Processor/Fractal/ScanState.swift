//
//  ScanViewModel.swift
//  Audio Processor
//
//  Created by Paige Plander on 8/9/18.
//  Copyright © 2018 Matthew Jeng. All rights reserved.
//

import Foundation
import UIKit


enum ScanLocation: String {
    case Contralateral
    case Suspected
}

enum ScanProgress {
    case scanInProgress
    case scanCancelled
    case notYetScanned
    case finishedScanning
}

class ScanViewModel {
    var filename: String
    let location: ScanLocation
    var progress: ScanProgress = .notYetScanned
    var isSelected: Bool
    
    var canStartQuickScan: Bool {
        return isSelected && (progress == .notYetScanned) || (progress == .scanCancelled)
    }

    // UI stuff
    let progressLabel: UILabel
    let selectButton: UIButton
    let deleteButton: UIButton
    let playbackButton: UIButton
    let bgView: UIView
    
    func setScanProgress(to newProgress: ScanProgress) {
        self.progress = newProgress
    }
    
    init(filename: String, location: ScanLocation, progressLabel: UILabel, playbackButton: UIButton, bgView: UIView, deleteButton: UIButton, selectButton: UIButton) {
        self.filename = filename
        self.location = location
        // make contralateral selected first
        self.isSelected = location == .Contralateral
        
        // UI elements
        self.progressLabel = progressLabel
        self.selectButton = selectButton
        self.deleteButton = deleteButton
        self.playbackButton = playbackButton
        self.bgView = bgView
    }
    
    convenience init() {
        self.init(filename: "test", location: .Contralateral, progressLabel: UILabel(), playbackButton: UIButton(), bgView: UIView(), deleteButton: UIButton(), selectButton: UIButton())
    }
    
}
