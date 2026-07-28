//
//  SpreadsheetItemViewModel.swift
//  MutualInfectionApp
//
//  Created by apple on 2025/9/9.
//

import Foundation
import UIKit

struct SpreadsheetItemViewModel {
    let items: [String]
    let isFirstLine: Bool
    let isLastLine: Bool
}

struct BorderViews {
    let topBorder: UIView
    let bottomBorder: UIView
    let leftBorder: UIView
    let rightBorder: UIView
}
