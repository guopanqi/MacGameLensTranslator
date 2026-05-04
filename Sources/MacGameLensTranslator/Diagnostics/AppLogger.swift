import os
import Foundation

enum AppLogger {
    static let capture = Logger(subsystem: "com.macgamelens.translator", category: "capture")
    static let ocr = Logger(subsystem: "com.macgamelens.translator", category: "ocr")
    static let textProcessing = Logger(subsystem: "com.macgamelens.translator", category: "textProcessing")
    static let translation = Logger(subsystem: "com.macgamelens.translator", category: "translation")
    static let overlay = Logger(subsystem: "com.macgamelens.translator", category: "overlay")
    static let coordinate = Logger(subsystem: "com.macgamelens.translator", category: "coordinate")
    static let permission = Logger(subsystem: "com.macgamelens.translator", category: "permission")
    static let settings = Logger(subsystem: "com.macgamelens.translator", category: "settings")
    static let app = Logger(subsystem: "com.macgamelens.translator", category: "app")
    static let coordinator = Logger(subsystem: "com.macgamelens.translator", category: "coordinator")
}
