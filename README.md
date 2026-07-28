#  内容描述

项目暂时使用单项目多`Target`的形式进行创建（后续可更改），第三方工具使用 [`CocoaPods`](https://guides.cocoapods.org/using/using-cocoapods.html)进行管理。

暂定项目前缀为 `MI` 如果为全局属性和方法，应添加 `MI` 前缀，用于和文件内部属性进行区分方便阅读。

**多语言**：多语言配置文件已添加，提供两种设置多语言的方式，多语言使用示例：

``` swift
"选择照片和视频".localized

MILocalized("选择文件")
```
具体代码在：`HuaweiShareViewController` 的 `showActionAlertSheet` 方法内。

**Swift** 调用 **OC**: 需要先在 `MutualInfection-Bridging-Header.h` 文件内导入需要调用的 **OC** 类名，导入后即可像调用 **Swift** 方法一样

# 第三方工具
#### [WCDB.swift](https://github.com/Tencent/wcdb/wiki/Swift-%e5%ae%89%e8%a3%85%e4%b8%8e%e5%85%bc%e5%ae%b9%e6%80%a7) 
WCDB 是一个易用、高效、完整的移动数据库框架，它基于 SQLite 和 SQLCipher 开发，在微信中应用广泛，且支持在 C++、Java、Kotlin、Swift、Objc 五种语言环境中使用。

#### [SnapKit](https://github.com/SnapKit/SnapKit)
UI页面布局工具

#### [LookinServer](https://lookin.work)
iOS UI 调试软件（PS：MacOS无法使用），需下载配套软件进行使用,[查看详情](https://lookin.work)。

#### [HXPhotoPicker/Picker](https://github.com/SilenceLove/HXPhotoPicker)
一款图片/视频选择器-支持LivePhoto、GIF选择、iCloud/网络资源在线下载、图片/视频编辑


## MutualInfectionApp
移动端区域

## MutualInfectionMac
MacOS区域

## MutualInfection
公共区域
