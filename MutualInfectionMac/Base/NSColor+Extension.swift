//
//  NSColor+Extension.swift
//  MutualInfectionMac
//
//  Created by delegate on 2025/9/26.
//


import AppKit

/// r g b a color
public func RGBA(_ red: CGFloat = 255.0, _ green: CGFloat = 255.0, _ blue: CGFloat = 255.0, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(red: red/255.0, green: green/255.0, blue: blue/255.0, alpha: alpha)
}
public func RGB(_ red: CGFloat = 255.0, _ green: CGFloat = 255.0, _ blue: CGFloat = 255.0) -> NSColor {
    NSColor(red: red/255.0, green: green/255.0, blue: blue/255.0, alpha: 1.0)
}
public func rgb(_ red: CGFloat = 255.0, _ green: CGFloat = 255.0, _ blue: CGFloat = 255.0) -> NSColor {
    RGB(red, green, blue)
}
public func hexColor(_ string: String, alpha: CGFloat = 1.0) -> NSColor {
    NSColor.mi.hex(string, alpha: alpha)
}

///随机色
public func RandomColor() ->  NSColor{
    let r = Int(arc4random_uniform(255))
    let g = Int(arc4random_uniform(255))
    let b = Int(arc4random_uniform(255))
    return RGBA(CGFloat(r), CGFloat(g), CGFloat(b))
}

extension NSColor : ExtensionCompatible {}

public extension MI where Base: NSColor {
    /// 随机色
    static func random(randomAlpha: Bool = false) -> NSColor {
        let randomRed = arc4random() % 255
        let randomGreen = arc4random() % 255
        let randomBlue = arc4random() % 255
        let alpha = randomAlpha ? arc4random()%255 : 1
        return RGBA(CGFloat(randomRed), CGFloat(randomGreen), CGFloat(randomBlue), CGFloat(alpha))
    }
    
    /// rgba
    static func RGBA(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat) -> NSColor {
        return NSColor(red: r/255, green: g/255, blue: b/255, alpha: a)
    }
    /// rgb
    static func RGB(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor {
        return RGBA(r, g, b, 1.0)
    }
    // hex
    static func hex(_ string: String, alpha: CGFloat = 1.0) -> NSColor {
        NSColor(hex: string, alpha: alpha)
    }
    /// NSColor转化为16进制
    var hex: String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        base.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        var rgb: Int = (Int)(red * 255) << 16 | (Int)(green * 255) << 8
        rgb = rgb | (Int)(blue * 255) << 0
        
        return String(format: "#%06x", rgb)
    }
    
    
    // MARK: - Other
    
    func lighter(by percentage: CGFloat = 10.0) -> NSColor {
        return self.adjust(by: abs(percentage)) ?? .white
    }
    
    func darker(by percentage: CGFloat = 10.0) -> NSColor {
        return self.adjust(by: -1 * abs(percentage)) ?? .black
    }
    
    func adjust(by percentage: CGFloat = 30.0) -> NSColor? {
        var r:CGFloat=0, g:CGFloat=0, b:CGFloat=0, a:CGFloat=0;
        base.getRed(&r, green: &g, blue: &b, alpha: &a)
        return NSColor(red: min(r + percentage/100, 1.0), green: min(g + percentage/100, 1.0), blue: min(b + percentage/100, 1.0), alpha: a)
    }
    
    func isDarker(than color: NSColor) -> Bool {
        return self.luminance < color.mi.luminance
    }
    
    func isLighter(than color: NSColor) -> Bool {
        return !self.isDarker(than: color)
    }
    
    var ciColor: CIColor {
        return CIColor(color: base) ?? CIColor()
    }
    var RGBA: [CGFloat] {
        return [ciColor.red, ciColor.green, ciColor.blue, ciColor.alpha]
    }
    
    var luminance: CGFloat {
        
        let RGBA = self.RGBA
        
        func lumHelper(c: CGFloat) -> CGFloat {
            return (c < 0.03928) ? (c/12.92): pow((c+0.055)/1.055, 2.4)
        }
        
        return 0.2126 * lumHelper(c: RGBA[0]) + 0.7152 * lumHelper(c: RGBA[1]) + 0.0722 * lumHelper(c: RGBA[2])
    }
    
    var isDark: Bool {
        return self.luminance < 0.5
    }
    
    var isLight: Bool {
        return !self.isDark
    }
    
    var isBlackOrWhite: Bool {
        let RGBA = self.RGBA
        let isBlack = RGBA[0] < 0.09 && RGBA[1] < 0.09 && RGBA[2] < 0.09
        let isWhite = RGBA[0] > 0.91 && RGBA[1] > 0.91 && RGBA[2] > 0.91
        
        return isBlack || isWhite
    }

    func darkModeColor() -> NSColor {
        return isBlackOrWhite ? inverted() : (isLight ? darker() : lighter())
    }

    func inverted() -> NSColor {
        return NSColor(red: 1 - RGBA[0], green: 1 - RGBA[1], blue: 1 - RGBA[2], alpha: RGBA[3])
    }

    func add(hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat) -> NSColor {
        var (oldHue, oldSat, oldBright, oldAlpha) : (CGFloat, CGFloat, CGFloat, CGFloat) = (0,0,0,0)
        base.getHue(&oldHue, saturation: &oldSat, brightness: &oldBright, alpha: &oldAlpha)

        // make sure new values doesn't overflow
        var newHue = oldHue + hue
        while newHue < 0.0 { newHue += 1.0 }
        while newHue > 1.0 { newHue -= 1.0 }

        let newBright: CGFloat = max(min(oldBright + brightness, 1.0), 0)
        let newSat: CGFloat = max(min(oldSat + saturation, 1.0), 0)
        let newAlpha: CGFloat = max(min(oldAlpha + alpha, 1.0), 0)

        return NSColor(hue: newHue, saturation: newSat, brightness: newBright, alpha: newAlpha)
    }

    func add(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) -> NSColor {
        var (oldRed, oldGreen, oldBlue, oldAlpha) : (CGFloat, CGFloat, CGFloat, CGFloat) = (0,0,0,0)
        base.getRed(&oldRed, green: &oldGreen, blue: &oldBlue, alpha: &oldAlpha)
        // make sure new values doesn't overflow
        let newRed: CGFloat = max(min(oldRed + red, 1.0), 0)
        let newGreen: CGFloat = max(min(oldGreen + green, 1.0), 0)
        let newBlue: CGFloat = max(min(oldBlue + blue, 1.0), 0)
        let newAlpha: CGFloat = max(min(oldAlpha + alpha, 1.0), 0)
        return NSColor(red: newRed, green: newGreen, blue: newBlue, alpha: newAlpha)
    }
    var toImage: NSImage? {
        let rect = NSRect(x: 0, y: 0, width: 10, height: 10)
        let image = NSImage(size: rect.size)
        image.lockFocus()
        base.setFill()
        rect.fill()
        image.unlockFocus()
        return image
    }
    static func random() -> NSColor {
        let r = CGFloat(Int.random(in: 0...255)) / 255
        let g = CGFloat(Int.random(in: 0...255)) / 255
        let b = CGFloat(Int.random(in: 0...255)) / 255
        return NSColor(red: r, green: g, blue: b, alpha: 1)
    }
}


// MARK: - 初始化
public extension NSColor {
    ///16进制转rgb
    convenience init(hex: String, alpha: CGFloat = 1.0) {
        let hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        let scanner = Scanner(string: hexString as String)

        if hexString.hasPrefix("#") {
            scanner.scanLocation = 1
        }
        var color: UInt32 = 0
        scanner.scanHexInt32(&color)

        let mask = 0x000000FF
        let r = Int(color >> 16) & mask
        let g = Int(color >> 8) & mask
        let b = Int(color) & mask

        let red = CGFloat(r) / 255.0
        let green = CGFloat(g) / 255.0
        let blue = CGFloat(b) / 255.0
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
    
    /// Initializes a NSColor for its corresponding rgba UInt
    ///
    /// - Parameter rgba: UInt
    convenience init(rgba: UInt) {
        let sRgba = min(rgba, 0xFFFFFFFF)
        let red: CGFloat = CGFloat((sRgba & 0xFF000000) >> 24) / 255.0
        let green: CGFloat = CGFloat((sRgba & 0x00FF0000) >> 16) / 255.0
        let blue: CGFloat = CGFloat((sRgba & 0x0000FF00) >> 8) / 255.0
        let alpha: CGFloat = CGFloat(sRgba & 0x000000FF) / 255.0
        
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
    
    convenience init(r: CGFloat, g: CGFloat, b: CGFloat) {
        self.init(red: r/255, green: g/255, blue: b/255, alpha: 1)
    }
}



