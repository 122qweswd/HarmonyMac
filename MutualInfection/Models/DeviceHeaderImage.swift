//
//  DeviceHeaderImage.swift
//  MutualInfectionApp
//
//  Created by apple on 2025/10/2.
//

#if os(iOS)
// iOS平台上的代码
import UIKit
#elseif os(macOS) // 注意：在Swift 5.1及以后，os(OSX)已被废弃，应使用os(macOS)
// macOS平台上的代码
import Cocoa
#else
// 其他平台上的代码（如果有的话）
#endif

import Foundation
import WCDBSwift


// struct 防止在模型修改时原数据发生改变
//字段约束是 TableEncodable 的一个可选函数
//可根据需求选择实现或不实现。它用于定于针对单个字段的约束，如主键约束、非空约束、唯一约束、默认值等。

// MARK: - 头像存储数据表模型
struct DeviceHeaderImage : Codable, Hashable,WCDBSwift.TableCodable{
    //final class DeviceHeaderImage: WCDBSwift.TableCodable,Equatable {
    
    static func == (lhs: DeviceHeaderImage, rhs: DeviceHeaderImage) -> Bool {
        return false
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(hwId)
    }
    init() {}
   
    var hwId:String = "0"//设备id
    var headerImage : String? = nil//头像
    //var deviceName : String?//设备名称


    ///在类内定义 CodingKeys 的枚举类，并遵循 String 和 CodingTableKey。
    ///枚举列举每一个需要定义的字段。
    ///对于变量名与表的字段名不一样的情况，可以使用别名进行映射，如 case identifier = "id"
    ///对于不需要写入数据库的字段，则不需要在 CodingKeys 内定义，如 debugDescription
    ///对于变量名与 SQLite 的保留关键字冲突的字段，同样可以使用别名进行映射，如 offset 是 SQLite 的关键字。
    // MARK: - WCDB 映射
    enum CodingKeys: String, CodingTableKey {
        typealias Root = DeviceHeaderImage
        static let objectRelationalMapping = TableBinding(CodingKeys.self) {

            BindColumnConstraint(hwId, isPrimary: true)
            
        }
        case hwId // 设备id
        case headerImage // 头像
    }

    var isAutoIncrement: Bool = false // 用于定义是否使用自增的方式插入
    var lastInsertedRowID: Int64 = 0 // 用于获取自增插入后的主键值
}


class MIDeviceHeaderWCDBManager: NSObject {
    
    class func sharedManager() -> MIDeviceHeaderWCDBManager {
        struct Static {
            static let manager = MIDeviceHeaderWCDBManager()
        }
        return Static.manager
    }
    
    var database : Database?
    
    let tableName  = "DeviceHeaderImage"
    override init() {
        
        let documents = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first ?? NSTemporaryDirectory()
        
        let dbPath = (documents as NSString).appendingPathComponent("\(tableName).db")
        
        self.database = Database(at: dbPath)
        
    
        do {
            /// 以下代码等效于 SQL：CREATE TABLE IF NOT EXISTS sampleTable(id INTEGER, description TEXT, db_offset INTEGER)
            try database?.create(table: tableName, of: DeviceHeaderImage.self)
        } catch {
            
        }
    }
    
    deinit {}
}

// MARK: - 头像增/改    查
extension MIDeviceHeaderWCDBManager {
    
    /// 插入 或者 更新
    @discardableResult

    func insertOrReplaceHeader(_ model :DeviceHeaderImage) -> Bool {
        do {
            try database?.insertOrReplace(model, intoTable: tableName)
        } catch {
            return false
        }
        return true
    }
    /// 获取单个模型
    @discardableResult
    func getDeviceHeaders() -> [DeviceHeaderImage?]? {
        do {
            let deviceHeaderImage :  [DeviceHeaderImage?]?  = try  database?.getObjects(fromTable: tableName)
            return deviceHeaderImage
        } catch _ {
            return []
        }
    }


#if os(iOS)
    /// 获取单个模型
    @discardableResult
    func getDeviceHeader(_ hwId: String,_ isShowIcon:Bool = false, deviceTye:Int) -> UIImage {
        if isShowIcon == false {
            if deviceTye == 1 || deviceTye == 0 || deviceTye == 2{
                return UIImage.deviceIphone
            }else if deviceTye == 5{
                return UIImage.devicePad
            }else if deviceTye == 3 || deviceTye == 6{
                return UIImage.deviceMac
            }
        }
        do {
            let deviceHeaderImage : DeviceHeaderImage? = try  database?.getObject(fromTable: tableName,where: DeviceHeaderImage.CodingKeys.hwId == hwId)
            
            if deviceHeaderImage?.headerImage == nil {
                if deviceTye == 1 || deviceTye == 0 || deviceTye == 2{
                    return UIImage.deviceIphone
                }else if deviceTye == 5{
                    return UIImage.devicePad
                }else if deviceTye == 3 || deviceTye == 6{
                    return UIImage.deviceMac
                }
            }else{
                return  base64StringToUIImage(base64String: deviceHeaderImage?.headerImage ?? "",deviceTye:deviceTye)
            }
        } catch _ {
            if deviceTye == 1 || deviceTye == 0 || deviceTye == 2{
                return UIImage.deviceIphone
            }else if deviceTye == 5{
                return UIImage.devicePad
            }else if deviceTye == 3 || deviceTye == 6{
                return UIImage.deviceMac
            }
        }
        return UIImage.deviceIphone
    }
#elseif os(macOS)
    
    /// 获取单个模型
    @discardableResult
    func getDeviceHeader(_ hwId: String,_ isShowIcon:Bool = false,deviceTye:Int) -> NSImage {
        if isShowIcon == false {
            if deviceTye == 1 || deviceTye == 0 || deviceTye == 2{
                return NSImage.deviceIphoneMac
            }else if deviceTye == 5{
                return NSImage.devicePadMac
            }else if deviceTye == 3 || deviceTye == 6{
                return NSImage.deviceMacMac
            }
        }
        do {
            let deviceHeaderImage : DeviceHeaderImage? = try  database?.getObject(fromTable: tableName,where: DeviceHeaderImage.CodingKeys.hwId == hwId)
            
            if deviceHeaderImage?.headerImage == nil {
                if deviceTye == 1 || deviceTye == 0 || deviceTye == 2{
                    return NSImage.deviceIphoneMac
                }else if deviceTye == 5{
                    return NSImage.devicePadMac
                }else if deviceTye == 3 || deviceTye == 6{
                    return NSImage.deviceMacMac
                }
            }else{
                return  base64ToImage(base64String: deviceHeaderImage?.headerImage ?? "",deviceTye:deviceTye)
            }
        } catch _ {
            if deviceTye == 1 || deviceTye == 0 || deviceTye == 2{
                return NSImage.deviceIphoneMac
            }else if deviceTye == 5{
                return NSImage.devicePadMac
            }else if deviceTye == 3 || deviceTye == 6{
                return NSImage.deviceMacMac
            }
        }
        return NSImage.deviceIphoneMac
    }
    

#endif
}

#if os(iOS)
func base64StringToUIImage(base64String: String,deviceTye:Int) -> UIImage {
    guard let base64Data = base64String.components(separatedBy: ",").last else {
        if deviceTye == 1 || deviceTye == 0 || deviceTye == 2{
            return UIImage.deviceIphone
        }else if deviceTye == 5{
            return UIImage.devicePad
        }else if deviceTye == 3 || deviceTye == 6{
            return UIImage.deviceMac
        }
        return UIImage.deviceIphone
    }
    // 将 Base64 编码的字符串转换为 Data 对象
    guard let data = Data(base64Encoded: base64Data) else {
        if deviceTye == 1 || deviceTye == 0 || deviceTye == 2{
            return UIImage.deviceIphone
        }else if deviceTye == 5{
            return UIImage.devicePad
        }else if deviceTye == 3 || deviceTye == 6{
            return UIImage.deviceMac
        }
        return UIImage.deviceIphone
    }
    var UIImageIcon = UIImage.deviceIphone
    
    if deviceTye == 1 || deviceTye == 0 || deviceTye == 2{
        UIImageIcon = UIImage.deviceIphone
    }else if deviceTye == 5{
        UIImageIcon = UIImage.devicePad
    }else if deviceTye == 3 || deviceTye == 6{
        UIImageIcon = UIImage.deviceMac
    }
    // 使用 Data 对象初始化 UIImage
    return UIImage(data: data) ?? UIImageIcon
}
#elseif os(macOS)

func base64ToImage(base64String: String,deviceTye:Int) -> NSImage {
    guard let data = Data(base64Encoded: base64String.replacingOccurrences(of: "data:image/jpeg;base64,", with: "")) else {
        if deviceTye == 1 || deviceTye == 0 || deviceTye == 2{
            return NSImage.deviceIphoneMac
        }else if deviceTye == 5{
            return NSImage.devicePadMac
        }else if deviceTye == 3 || deviceTye == 6{
            return NSImage.deviceMacMac
        }
        return NSImage.deviceIphoneMac
    }
    var UIImageIcon = NSImage.deviceIphoneMac
    if deviceTye == 1 || deviceTye == 0 || deviceTye == 2{
        UIImageIcon = NSImage.deviceIphoneMac
    }else if deviceTye == 5{
        UIImageIcon = NSImage.devicePadMac
    }else if deviceTye == 3 || deviceTye == 6{
        UIImageIcon = NSImage.deviceMacMac
    }
    return NSImage(data: data)  ?? UIImageIcon
}
#endif

