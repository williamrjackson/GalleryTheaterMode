//
//  Preferences.swift
//  ActBlackTheaterMode
//
//  Created by Billy Jackson on 2/7/26.
//

import Foundation
import AppKit

enum PrefKey {
    static let targetWidth = "theater.targetWidth"
    static let offsetY = "theater.offsetY"
    
    static let bgColorR = "theater.bgColor.r"
    static let bgColorG = "theater.bgColor.g"
    static let bgColorB = "theater.bgColor.b"
    static let bgColorA = "theater.bgColor.a"
    
    static let rectColorR = "theater.rectColor.r"
    static let rectColorG = "theater.rectColor.g"
    static let rectColorB = "theater.rectColor.b"
    static let rectColorA = "theater.rectColor.a"
}

struct TheaterPrefs {
    static func loadInt(_ key: String, default def: Int) -> Int {
        let v = UserDefaults.standard.object(forKey: key) as? Int
        return v ?? def
    }
    static func loadInt(_ key: String) -> Int {
        UserDefaults.standard.integer(forKey: key)
    }
    static func loadString(_ key: String, default def: String = "") -> String {
        UserDefaults.standard.string(forKey: key) ?? def
    }
    static func loadBool(_ key: String, default def: Bool) -> Bool {
        let v = UserDefaults.standard.object(forKey: key) as? Bool
        return v ?? def
    }
    static func loadDouble(_ key: String, default def: Double) -> Double {
        let v = UserDefaults.standard.object(forKey: key) as? Double
        return v ?? def
    }
    static func loadColor(r: String, g: String, b: String, a: String) -> NSColor {
        let dr = TheaterPrefs.loadDouble(r, default: 0)
        let dg = TheaterPrefs.loadDouble(g, default: 0)
        let db = TheaterPrefs.loadDouble(b, default: 0)
        let da = TheaterPrefs.loadDouble(a, default: 0)
        return NSColor(deviceRed: dr, green: dg, blue: db, alpha: da)
    }
    static func saveInt(_ key: String, _ value: Int) {
        UserDefaults.standard.set(value, forKey: key)
    }
    static func saveString(_ key: String, _ value: String) {
        UserDefaults.standard.set(value, forKey: key)
    }
    static func saveBool(_ key: String, _ value: Bool) {
        UserDefaults.standard.set(value, forKey: key)
    }
    static func saveDouble(_ key: String, _ value: Double) {
        UserDefaults.standard.set(value, forKey: key)
    }
    static func saveColor(_ color: NSColor, r: String, g: String, b: String, a: String) {
        let c = color.usingColorSpace(.deviceRGB) ?? color
        TheaterPrefs.saveDouble(r, Double(c.redComponent))
        TheaterPrefs.saveDouble(g, Double(c.greenComponent))
        TheaterPrefs.saveDouble(b, Double(c.blueComponent))
        TheaterPrefs.saveDouble(a, Double(c.alphaComponent))
    }
}
extension Notification.Name {
    static let theaterOffsetYDidChange = Notification.Name("theater.offsetYDidChange")
}

extension Notification.Name {
    static let theaterTargetWidthDidChange = Notification.Name("theater.targetWidthDidChange")
}


func registerDefaultPreferences() {
    UserDefaults.standard.register(defaults: [
        PrefKey.targetWidth: 1200,
        PrefKey.offsetY: 0,

        // Background default
        PrefKey.bgColorR: 0.541,
        PrefKey.bgColorG: 0.145,
        PrefKey.bgColorB: 0.200,
        PrefKey.bgColorA: 1.0,

        // Placeholder rectangle default
        PrefKey.rectColorR: 0.941,
        PrefKey.rectColorG: 0.824,
        PrefKey.rectColorB: 0.886,
        PrefKey.rectColorA: 1.0,
    ])
}

