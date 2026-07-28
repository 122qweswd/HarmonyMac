//
//  LocalizationManager.swift
//  MutualInfection
//
//  Created by Niko on 2025/11/8.
//

import Foundation

enum AppLanguage {
    /// 英文
    case english
    /// 中文简体
    case simplifiedChinese
//    /// 中文繁体
//    case traditionalChinese
    /// 日文
    case japanese
    /// 韩文
    case korean
    /// 泰语
    case thai
    /// 印尼语
    case indonesia
    /// 越南语
    case vietnamese
    /// 俄语
    case russian
    /// 德语
    case german
    /// 法语
    case french
    /// 阿拉伯
    case arabic
    /// 西班牙
    case spanish
    /// 葡萄牙
    case portuguese
    /// 繁体中文（中国台湾）
    case traditionalChineseTaiwan
    /// 繁体中文（中国香港）
    case traditionalChineseHongkong
    /// 土耳其语
    case turkish
    /// 意大利语
    case italian
    /// 缅甸语
    case burmese
    /// 波兰语
    case polish
    /// 马来语
    case malay
    /// 藏语
    case tibetan
    /// 维吾尔族语
    case uyghur
    /// 老挝语
    case lao
    
    static var current: AppLanguage {
        let preferredLanguage = Locale.preferredLanguages.first ?? "en"
        
        if preferredLanguage.hasPrefix("en") {
            return .english
        } else if preferredLanguage.hasPrefix("zh-Hant-TW") {
            return .traditionalChineseTaiwan
        } else if preferredLanguage.hasPrefix("zh-Hant-HK") {
            return .traditionalChineseHongkong
        } else if preferredLanguage.hasPrefix("zh") {
            return .simplifiedChinese
        } else if preferredLanguage.hasPrefix("tr") {
            return .turkish
        } else if preferredLanguage.hasPrefix("it") {
            return .italian
        } else if preferredLanguage.hasPrefix("my") {
            return .burmese
        } else if preferredLanguage.hasPrefix("pl") {
            return .polish
        } else if preferredLanguage.hasPrefix("ms") {
            return .malay
        } else if preferredLanguage.hasPrefix("ja") {
            return .japanese
        } else if preferredLanguage.hasPrefix("ko") {
            return .korean
        } else if preferredLanguage.hasPrefix("th") {
            return .thai
        } else if preferredLanguage.hasPrefix("id") {
            return .indonesia
        } else if preferredLanguage.hasPrefix("vi") {
            return .vietnamese
        } else if preferredLanguage.hasPrefix("ru") {
            return .russian
        } else if preferredLanguage.hasPrefix("de") {
            return .german
        } else if preferredLanguage.hasPrefix("fr") {
            return .french
        } else if preferredLanguage.hasPrefix("ar") {
            return .arabic
        } else if preferredLanguage.hasPrefix("es") {
            return .spanish
        } else if preferredLanguage.hasPrefix("pt") {
            return .portuguese
        } else if preferredLanguage.hasPrefix("bo") {
            return .tibetan
        } else if preferredLanguage.hasPrefix("ug") {
            return .uyghur
        } else if preferredLanguage.hasPrefix("lo") {
            return .lao
        } else {
            return .english
        }
    }
    
    /// 是否阿语RTL布局
    public static var isRTL: Bool {
        let languageType = AppLanguage.current
        return languageType == .arabic || languageType == .uyghur
    }
    
//    static var currentDetailed: AppLanguage {
//        guard let languageCode = Locale.current.languageCode else {
//            return .english // 默认英文
//        }
//        
//        if languageCode.hasPrefix("zh") {
//            return .chinese
//        } else {
//            return .english
//        }
//    }
}

@propertyWrapper
struct Localized {
    let key: String
    
    var wrappedValue: String {
        return key.localized
    }
    
    init(_ key: String) {
        self.key = key
    }
}

struct LocalizedStrings {
    
    /// 互传记录
    @Localized("transfer_records") static var transferRecords: String
    /// 搜索
    @Localized("search") static var search: String
    /// 接收自
    @Localized("received_from") static var receivedFrom: String
    /// 我接收的
    @Localized("i_received") static var iReceived: String
    /// 我发送的
    @Localized("i_sent") static var iSent: String
    /// 编辑
    @Localized("edit") static var edit: String
    /// 重试
    @Localized("retry") static var retry: String
    /// 查看
    @Localized("view") static var view: String
    /// 打开方式
    @Localized("open_with") static var openWith: String
    /// 忽略
    @Localized("ignore") static var ignore: String
    /// 删除
    @Localized("delete") static var delete: String
    /// 按时间排序
    @Localized("sort_by_time") static var sortByTime: String
    /// 按类型排序
    @Localized("sort_by_type") static var sortByType: String
    /// 降序
    @Localized("descending_order") static var descendingOrder: String
    /// 升序
    @Localized("ascending_order") static var ascendingOrder: String
    /// 导入失败
    @Localized("import_failed") static var importFailed: String
    /// 部分导入失败
    @Localized("partial_import_failed") static var partialImportFailed: String
    ///导入未完成
    @Localized("import_no_complete") static var importNotCompleted: String
    /// 暂无数据
    @Localized("no_data_available") static var noDataAvailable: String
    /// 搜索不到该文件
    @Localized("can_not_find") static var canNotFind: String
    /// 源文件已损坏，无法导入
    @Localized("source_file_corrupted") static var sourceFileCorrupted: String
    /// 该文件已被移动或删除
    @Localized("file_moved_or_deleted") static var fileMovedOrDeleted: String
    /// 请确认是否删除记录
    @Localized("confirm_delete_record") static var confirmDeleteRecord: String
    /// 该文件已被移动或删除, 请确认是否删除记录
    @Localized("file_moved_or_deleted_confirm_delete_record") static var fileMovedOrDeletedConfirmDeleteRecord: String
    /// 是否删除该项纪录？
    @Localized("delete_record_confirmation") static var deleteRecordConfirmation: String
    /// 取消
    @Localized("cancel") static var cancel: String
    /// 确定
    @Localized("confirm") static var confirm: String
    /// 我知道了
    @Localized("i_know") static var iKnow: String
    /// 全选
    @Localized("select_all") static var selectAll: String
    /// 取消全选
    @Localized("deselect_all") static var deselectAll: String
    /// 删除记录及文件
    @Localized("delete_record_and_file") static var deleteRecordAndFile: String
    /// 删除记录
    @Localized("delete_record") static var deleteRecord: String
    /// 图片已导入系统相册\n请在手机【照片】>【相簿】>【鸿蒙星河互联】中查看
    @Localized("image_imported_to_album") static var imageImportedToAlbum: String
    /// 导入系统相册
    @Localized("imported_to_system_album") static var importedToSystemAlbum: String
    /// 正在导入
    @Localized("importing") static var importing: String
}

