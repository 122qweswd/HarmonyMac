//
//  Device.swift
//  MutualInfection
//
//  Created by Niko on 2025/11/4.
//

import Foundation
#if MAIN_APP
import UIKit
#endif

class NKDevice {
    
    static var isPad: Bool {
#if MAIN_APP
        UIDevice.current.userInterfaceIdiom == .pad
#elseif MAIN_MAC
        false
#endif
    }
    
    static var isPhone: Bool {
#if MAIN_APP
        UIDevice.current.userInterfaceIdiom == .phone
#elseif MAIN_MAC
        false
#endif
    }
    
    static var isMac: Bool {
#if MAIN_APP
        false
#elseif MAIN_MAC
        true
#endif
    }
    
}


