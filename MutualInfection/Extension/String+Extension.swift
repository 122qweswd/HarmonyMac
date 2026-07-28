//
//  String+Extension.swift
//  MutualInfection
//
//  Created by Niko on 2025/8/31.
//

import Foundation

extension String {
    /// 多语言
    var localized: String {
       return  NSLocalizedString(self, comment: self)
    }
    
    /// 多语言
    static func localized(value: String) -> String {
        return  value.localized
    }
}
