//
//  LiveActivityLiveActivity.swift
//  LiveActivity
//
//  Created by apple on 2025/9/11.
//


import ActivityKit
import WidgetKit
import SwiftUI

enum StatusLive: String, Codable, CaseIterable {
    case normal
    case waiting
    case connecting
    case send
    case cancelSend
    case cancelReceive
    case receive
    case importFile
}

struct LiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var progress : CGFloat
        var status: StatusLive
        var stateInfo: String
        var statusInfo:String
    }

    // Fixed non-changing properties about your activity go here!
//    var progress : CGFloat = 0
}
@available(iOS 16.2, *)
struct LiveActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveActivityAttributes.self) { context in
            // Lock screen/banner UI goes here
            HStack(spacing: 16) {
                            // 左侧：WiFi图标
                Image("icon")  // 加载本地资源图片
               .resizable()    // 允许调整大小
               .frame(width: 54, height: 54)

                            // 中间：两行文字
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.stateInfo)
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .medium))

                    Text(context.state.statusInfo)
                        .foregroundColor(.gray)
                        .font(.system(size: 12, weight: .regular))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // 右侧：蓝色圆圈中的白色打钩
                CircularProgressBigView(context: context)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .activityBackgroundTint(Color.clear)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
            DynamicIslandExpandedRegion(.leading) {
                // WiFi图标
                Image("icon")  // 加载本地资源图片
               .resizable()    // 允许调整大小
               .frame(width: 54, height: 54)
               .padding(.leading, 4)
            }
            DynamicIslandExpandedRegion(.trailing) {
//                Link(destination: URL(string: "apple://stopAction")!) {
                    CircularProgressBigView(context: context)
//                }
            }
            DynamicIslandExpandedRegion(.center) {
                VStack(spacing: 2) {
                    // 第一行：发送完成
                    Text(context.state.stateInfo)
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .medium))
                        .frame(maxWidth: .infinity,alignment: .leading)
                    // 第二行：文件数量和大小
                    Text(context.state.statusInfo)
                        .foregroundColor(.gray)
                        .font(.system(size: 12, weight: .regular))
                        .frame(maxWidth: .infinity,alignment: .leading)
                }
                .frame(maxWidth: .infinity,alignment: .leading)
            }
            } compactLeading: {
                 Image("icon")  // 加载本地资源图片
                .resizable()    // 允许调整大小
                .frame(width: 22, height: 22)
                .padding(.leading, 2)
            } compactTrailing: {
                CircularProgressView(context: context)
            } minimal: {
                HStack(spacing: 8) {
                    // 右边显示进度条
                    CircularMinimalProgressView(context: context)
                }
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

@available(iOS 16.2, *)
// MARK: - Custom Views
struct CircularMinimalProgressView: View {
    let context: ActivityViewContext<LiveActivityAttributes>

    var body: some View {
        if context.state.status == StatusLive.cancelSend || context.state.status == StatusLive.cancelReceive{
            Image("cancel")  // 加载本地资源图片
                .frame(width: 22, height: 22)
        }else if context.state.status == StatusLive.importFile{
            if context.state.progress>=1.0{
                Image("finishShareSmall")  // 加载本地资源图片
                    .frame(width: 22, height: 22)
            }
            else{
                ZStack {
                    // 背景圆环
                    Circle()
                        .stroke(lineWidth: 3)
                        .foregroundColor(Color.gray.opacity(0.5))
                        .frame(width: 22, height: 22)
                    
                    // 进度圆环
                    Circle()
                        .trim(from: 0, to: context.state.progress)
                        .stroke(style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .foregroundColor(Color.blue)
                        .frame(width: 22, height: 22)
                        .rotationEffect(.degrees(-90)) // 从顶部开始
                    // 蓝色正方形替代文本
                    Text("\(Int(context.state.progress * 100))%")
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                        .minimumScaleFactor(0.5) // 文本缩小时保持可读性
                        .lineLimit(1)
                }
                .frame(width: 24,height: 24)
            }
        }else{
            if context.state.progress>=1.0{
                Image("finishShareSmall")  // 加载本地资源图片
                    .frame(width: 22,height: 22)
            }
            else{
                ZStack {
                    // 背景圆环
                    Circle()
                        .stroke(lineWidth: 3)
                        .foregroundColor(Color.gray.opacity(0.5))
                        .frame(width: 22, height: 22)
                    
                    // 进度圆环
                    Circle()
                        .trim(from: 0, to: context.state.progress)
                        .stroke(style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .foregroundColor(Color.blue)
                        .frame(width: 22, height: 22)
                        .rotationEffect(.degrees(-90)) // 从顶部开始
                    Text("\(Int(context.state.progress * 100))%")
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 22, height: 22)
                        .minimumScaleFactor(0.5) // 文本缩小时保持可读性
                        .lineLimit(1)
                }
                .frame(width: 24,height: 24)
            }
        }
    }
}


@available(iOS 16.2, *)
// MARK: - Custom Views
struct CircularProgressView: View {
    let context: ActivityViewContext<LiveActivityAttributes>

    var body: some View {
        if context.state.status == StatusLive.cancelSend || context.state.status == StatusLive.cancelReceive{
            Text("发送取消")
                .foregroundColor(.white)
                .font(.system(size: 16, weight: .medium))
                .frame(maxWidth: .infinity,alignment: .leading)
        }else if context.state.status == StatusLive.importFile{
            Text(context.state.stateInfo)
                .foregroundColor(.white)
                .font(.system(size: 16, weight: .medium))
                .frame(maxWidth: .infinity,alignment: .leading)
            
        }else{
            if context.state.progress>=1.0{
                Image("finishShareSmall")  // 加载本地资源图片
                    .frame(width: 30,height: 40)
            }
            else{
                ZStack {
                    // 背景圆环
                    Circle()
                        .stroke(lineWidth: 3)
                        .foregroundColor(Color.gray.opacity(0.5))
                        .frame(width: 24, height: 24)
                    
                    // 进度圆环
                    Circle()
                        .trim(from: 0, to: context.state.progress)
                        .stroke(style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .foregroundColor(Color.blue)
                        .frame(width: 24, height: 24)
                        .rotationEffect(.degrees(-90)) // 从顶部开始
                    Text("\(Int(context.state.progress * 100))%")
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 22, height: 22)
                        .minimumScaleFactor(0.5) // 文本缩小时保持可读性
                        .lineLimit(1)
                }
                .frame(width: 30,height: 40)
            }
        }
    }
}
@available(iOS 16.2, *)
struct CircularProgressBigView: View {
    let context: ActivityViewContext<LiveActivityAttributes>

    var body: some View {
        if context.state.status == StatusLive.cancelSend || context.state.status == StatusLive.cancelReceive{
            Image("cancel")  // 加载本地资源图片
                .frame(width: 54, height: 54)
        }else if context.state.status == StatusLive.importFile{
            if context.state.progress>=1.0{
                Image("finishShareBig")  // 加载本地资源图片
                    .frame(width: 54, height: 54)
            }
            else{
                ZStack {
                    // 背景圆环
                    Circle()
                        .stroke(lineWidth: 5)
                        .foregroundColor(Color.gray.opacity(0.5))
                        .frame(width: 55, height: 55)
                    
                    // 进度圆环
                    Circle()
                        .trim(from: 0, to: context.state.progress)
                        .stroke(style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .foregroundColor(Color.blue)
                        .frame(width: 55, height: 55)
                        .rotationEffect(.degrees(-90)) // 从顶部开始
                    // 蓝色正方形替代文本
                    Text("\(Int(context.state.progress * 100))%")
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 30, height: 30)
                        .minimumScaleFactor(0.5) // 文本缩小时保持可读性
                        .lineLimit(1)
                }
                .frame(width: 50,height: 50)
            }
        }
        else{
            if context.state.progress>=1.0{
                Image("finishShareBig")  // 加载本地资源图片
                    .frame(width: 54, height: 54)
            }
            else{
                Link(destination: URL(string: "apple://stopAction")!) {
                    ZStack {
                        // 背景圆环
                        Circle()
                            .stroke(lineWidth: 5)
                            .foregroundColor(Color.gray.opacity(0.5))
                            .frame(width: 55, height: 55)
                        
                        // 进度圆环
                        Circle()
                            .trim(from: 0, to: context.state.progress)
                            .stroke(style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .foregroundColor(Color.blue)
                            .frame(width: 55, height: 55)
                            .rotationEffect(.degrees(-90)) // 从顶部开始
                        // 蓝色正方形替代文本
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: 25, height: 25)
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 50,height: 50)
                }
            }
        }
    }
}


@available(iOS 16.2, *)
extension LiveActivityAttributes.ContentState {
    fileprivate static var preview: LiveActivityAttributes.ContentState {
        LiveActivityAttributes.ContentState(progress: 0,status: StatusLive.send,stateInfo: "", statusInfo: "")
    }
    fileprivate static var smiley: LiveActivityAttributes.ContentState {
        LiveActivityAttributes.ContentState(progress: 0,status: StatusLive.send,stateInfo: "",statusInfo: "")
     }
     
     fileprivate static var starEyes: LiveActivityAttributes.ContentState {
         LiveActivityAttributes.ContentState(progress: 0,status: StatusLive.send,stateInfo: "",statusInfo: "")
     }
}

//#Preview("Notification", as: .content, using: LiveActivityAttributes.preview) {
//   LiveActivityLiveActivity()
//} contentStates: {
//    LiveActivityAttributes.ContentState.smiley
//    LiveActivityAttributes.ContentState.starEyes
//}
