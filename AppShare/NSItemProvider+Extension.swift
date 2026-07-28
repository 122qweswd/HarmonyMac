//
//  NSItemProvider+Extension.swift
//  MutualInfection
//
//  Created by Niko on 2025/10/15.
//

import Foundation
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif
#if os(iOS)
import MobileCoreServices
#endif


extension NSItemProvider {
    // MARK: - App现在支持的类型
    var isImageType: Bool {
        if #available(iOS 14, *) {
            if #available(macOS 11.0, *) {
                return hasItemConformingToTypeIdentifier(UTType.image.identifier)
            } else {
                return false
                // Fallback on earlier versions
            }
        } else {
            return hasItemConformingToTypeIdentifier(kUTTypeImage as String)
        }
    }
    
    var isLivePhoto: Bool {
        if #available(iOS 14, *) {
            if #available(macOS 11.0, *) {
                return hasItemConformingToTypeIdentifier(UTType.livePhoto.identifier)
            } else {
                return false
                // Fallback on earlier versions
            }
        } else {
            return hasItemConformingToTypeIdentifier(kUTTypeLivePhoto as String)
        }
    }
    
    var isMovie: Bool {
        if #available(iOS 14, *) {
            if #available(macOS 11.0, *) {
                return hasItemConformingToTypeIdentifier(UTType.movie.identifier)
            } else {
                return false
                // Fallback on earlier versions
            }
        } else {
            return hasItemConformingToTypeIdentifier(kUTTypeMovie as String)
        }
    }
    
    var isVCardType: Bool {
        if #available(iOS 14, *) {
            if #available(macOS 11.0, *) {
                return hasItemConformingToTypeIdentifier(UTType.vCard.identifier)
            } else {
                return false
                // Fallback on earlier versions
            }
        } else {
            return hasItemConformingToTypeIdentifier(kUTTypeVCard as String)
        }
    }
    
    var isFileType: Bool {
        if hasItemConformingToTypeIdentifier("dyn.age8u") {
            return false
        } else {
            if #available(iOS 14, *) {
                if #available(macOS 11.0, *) {
                    return hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
                } else {
                    return false
                    // Fallback on earlier versions
                }
            } else {
                return hasItemConformingToTypeIdentifier(kUTTypeFileURL as String)
            }
        }
    }
    
//    /// 没啥卵用，之前哥们写的
//    var isPlainText: Bool {
//        if #available(iOS 14, *) {
//            if #available(macOS 11.0, *) {
//                return hasItemConformingToTypeIdentifier(UTType.plainText.identifier)
//            } else {
//                return false
//                // Fallback on earlier versions
//            }
//        } else {
//            return hasItemConformingToTypeIdentifier(kUTTypePlainText as String)
//        }
//        
//    }
    
    var isJSONType: Bool {
        if #available(iOS 14, *) {
            if #available(macOS 11.0, *) {
                return hasItemConformingToTypeIdentifier(UTType.json.identifier)
            } else {
                return false
                // Fallback on earlier versions
            }
        } else {
            return hasItemConformingToTypeIdentifier(kUTTypeJSON as String)
        }
    }
    
    /// 应用是否支持类型
    func canHandle() -> Bool {
        return isImageType || isLivePhoto || isMovie || isVCardType || isFileType
    }
    
    func getIdentifier() -> String? {
        if canHandle() {
            if registeredTypeIdentifiers.contains(where: { $0 == "public.file-url" }) {
                return "public.file-url"
            } else {            
                return self.registeredTypeIdentifiers.first ?? ""
            }
        } else {
            return nil
        }
    }
}
