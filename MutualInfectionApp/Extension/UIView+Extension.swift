//
//  UIView+Extension.swift
//  MutualInfection
//
//  Created by Niko on 2025/8/31.
//

import Foundation
import UIKit


// MARK: - 设置View frame
public extension UIView {
    var Kwidth: CGFloat {
        get{
            return self.frame.width
        }
        set{
            var frame = self.frame
            frame.size.width = newValue
            self.frame = frame
        }
    }
    
    var Kheight: CGFloat {
        get{
            return self.frame.height
        }
        set{
            var frame = self.frame
            frame.size.height = newValue
            self.frame = frame
        }
    }
    
    var Kx: CGFloat {
        get{
            return self.frame.origin.x
        }
        set{
            var frame = self.frame
            frame.origin.x = newValue
            self.frame = frame
        }
    }
    
    var Ky: CGFloat {
        get{
            return self.frame.origin.y
        }
        set{
            var frame = self.frame
            frame.origin.y = newValue
            self.frame = frame
        }
    }
    
    var KcenterX: CGFloat {
        get{
            return self.center.x
        }
        set{
            var center = self.center
            center.x = newValue
            self.center = center
        }
    }
    
    var KcenterY: CGFloat {
        get{
            return self.center.y
        }
        set{
            var center = self.center
            center.y = newValue
            self.center = center
        }
    }
    
    var Ksize: CGSize {
        
        get{
            return self.frame.size
        }
        set{
            var frame = self.frame
            frame.size = newValue
            self.frame = frame
        }
    }
}
