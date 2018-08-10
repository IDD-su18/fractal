//
//  Constants.swift
//  Audio Processor
//
//  Created by Paige Plander on 8/9/18.
//  Copyright © 2018 Matthew Jeng. All rights reserved.
//

import Foundation
import UIKit

struct Strings {
    // spaces are for margins bc i am lazy
    static let SCANNING = "   Scan in progress"
    static let CANCELLED = "   Scan cancelled. Tap to retry."
    static let READY_TO_SCAN = "   Ready to scan"
    static let NOT_YET_SCANNED = "   Not yet scanned"
    static let SCAN_COMPLETE = "   Scan complete"
}

struct Colors {
    static let SELECTED_BTN = UIColor(red: 0.0, green: 0.569, blue: 0.575, alpha: 1.0)
    static let CANCEL_BTN = UIColor(red: 1.00, green: 0.149, blue: 0.0, alpha: 1.0)
    static let DESELECTED_BTN = UIColor(red: 0.67, green: 0.67, blue: 0.67, alpha: 1.0)
}
