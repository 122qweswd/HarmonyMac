//
//  ImageResource.swift
//  HXPhotoPicker
//
//  Created by Silence on 2024/1/30.
//  Copyright © 2024 Silence. All rights reserved.
//

import UIKit

public extension HX {
    
    static var imageResource: ImageResource { .shared }
    
    class ImageResource {
        public static let shared = ImageResource()
        
        #if HXPICKER_ENABLE_PICKER
        /// 选择器
        public var picker: Picker = .init()
        #endif
    }
}

public extension HX.ImageResource {
    
    enum ImageType {
        case local(String)
        /// iOS 13.0+
        case system(String)
        
        var image: UIImage? {
            switch self {
            case .local(let name):
                return name.image
            case .system(let name):
                if #available(iOS 13.0, *) {
                    return .init(systemName: name)
                } else {
                    return name.image
                }
            }
        }
        
        var name: String {
            switch self {
            case .local(let name):
                return name
            case .system(let name):
                return name
            }
        }
        
        static var imageResource: HX.ImageResource {
            HX.ImageResource.shared
        }
    }
    
    #if HXPICKER_ENABLE_PICKER
    struct Picker {
        /// 相册列表
        public var albumList: AlbumList = .init()
        /// 照片列表
        public var photoList: PhotoList = .init()
        /// 预览界面
        public var preview: Preview = .init()
        /// 未授权界面
        public var notAuthorized: NotAuthorized = .init()
        
        public struct NotAuthorized {
            /// 未授权界面的关闭按钮
            public var close: ImageType = .local("hx_picker_notAuthorized_close")
            /// 未授权界面暗黑模式下的关闭按钮
            public var closeDark: ImageType = .local("hx_picker_notAuthorized_close_dark")
        }
        
        public struct AlbumList {
            /// 相册为空时的封面图片
            var emptyCover: ImageType = .local("hx_picker_album_empty")
            
            var cell: Cell = .init()
            
            struct Cell {
                /// cell箭头
                var arrow: ImageType = {
                    if #available(iOS 13.0, *) {
                        return .system("chevron.right")
                    }
                    return .local("hx_picker_photolist_bottom_prompt_arrow")
                }()
            }
        }
        
        public struct PhotoList {
            /// 取消按钮
            public var cancel: ImageType = .local("hx_picker_photolist_cancel")
            /// 暗黑模式下的取消按钮
            public var cancelDark: ImageType = .local("hx_picker_photolist_cancel")
            
            /// 筛选按钮正常状态
            public var filterNormal: ImageType = .local("hx_picker_photolist_nav_filter_normal")
            /// 筛选按钮选中状态
            public var filterSelected: ImageType = .local("hx_picker_photolist_nav_filter_selected")
            /// 筛选界面
            public var filter: Filter = .init()
            
            public var cell: Cell = .init()
            
            public var bottomView: BottomView = .init()
            
            public struct Cell {
                /// 视频图标
                public var video: ImageType = .local("hx_picker_cell_video_icon")
                /// 实况图标
                public var livePhoto: ImageType = .local("hx_picker_cell_livephoto_icon")
                /// 已编辑照片图标
                public var photoEdited: ImageType = .local("hx_picker_cell_photo_edit_icon")
                /// 已编辑视频图标
                public var videoEdited: ImageType = .local("hx_picker_cell_video_edit_icon")
                /// iCloud图标
                public var iCloud: ImageType = .local("hx_picker_photo_icloud_mark")
                
                /// 相机图标
                public var camera: ImageType = .local("hx_picker_photoList_photograph")
                /// 暗黑模式下的相机图标
                public var cameraDark: ImageType = .local("hx_picker_photoList_photograph_white")
            }
            
            public struct Filter {
                /// 所有项目图标
                public var any: ImageType = .local("hx_photo_list_filter_any")
                /// 已编辑图标
                public var edited: ImageType = .local("hx_photo_list_filter_edited")
                /// 照片图标
                public var photo: ImageType = .local("hx_photo_list_filter_photo")
                /// 动图图标
                public var gif: ImageType = .local("hx_photo_list_filter_gif")
                /// 实况图标
                public var livePhoto: ImageType = .local("hx_photo_list_filter_livePhoto")
                /// 视频图标
                public var video: ImageType = .local("hx_photo_list_filter_video")
            }
            
            public struct BottomView {
                /// 相册权限提示图标
                public var permissionsPrompt: ImageType = .local("hx_picker_photolist_bottom_prompt")
                /// 相册权限跳转箭头图标
                public var permissionsArrow: ImageType = {
                    if #available(iOS 13.0, *) {
                        return .system("chevron.right")
                    }
                    return .local("hx_picker_photolist_bottom_prompt_arrow")
                }()
                
                /// 已选列表删除图标
                public var delete: ImageType = .local("hx_picker_toolbar_select_cell_delete")
            }
        }
        
        public struct Preview {
            /// 返回图标
            public var back: ImageType = .local("hx_picker_photolist_back")
            /// 取消图标
            public var cancel: ImageType = .local("hx_picker_photolist_cancel")
            /// 暗黑模式下的取消按钮
            public var cancelDark: ImageType = .local("hx_picker_photolist_cancel")
            /// 播放视频图标
            public var videoPlay: ImageType = .local("hx_picker_cell_video_play")
            /// 实况图片标签图标
            public var livePhoto: ImageType = .local("hx_picker_livePhoto")
            public var livePhotoDisable: ImageType = .local("hx_picker_livePhoto_disable")
            /// 实况图片静音图标
            public var livePhotoMuted: ImageType = .local("hx_picker_livePhoto_muted")
            public var livePhotoMutedDisable: ImageType = .local("hx_picker_livePhoto_muted_disable")
            /// HDR标签图标
            public var HDR: ImageType = .local("hx_picker_HDR")
            public var HDRDisable: ImageType = .local("hx_picker_HDR_disable")
        }
    }
    #endif
}
