//
//  LiveActivityManager.swift
//  LiveActivityPushDemo
//
//  Created by guoxingxu on 2024/1/30.
//

import Foundation
import ActivityKit
import os.log
import UIKit


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

@available(iOS 16.2, *)
class LiveActivityManager: NSObject, ObservableObject {
    public static let shared: LiveActivityManager = LiveActivityManager()
    
//    private var currentActivity: Activity<LiveActivityAttributes>? = nil
        
    override init() {
        super.init()
    }
       
    
    func getPushToStartToken() {
//        if #available(iOS 17.2, *) {
//            Task {
//                for await data in Activity<LiveActivityAttributes>.pushToStartTokenUpdates {
//                    let token = data.map {String(format: "%02x", $0)}.joined()
//                        print("Activity PushToStart Token: \(token)")
////                        Logger.liveactivity.info("Activity PushToStart Token: \(token, privacy: .public)")
//                        //send this token to your notification server
//                    }
//            }
//
//        }
    }
//
    func startLiveActivityWithToken() {
//        ShareAPI.shared().log(1, "灵动岛   startLiveActivityWithToken in")
//        startActivityWith(pushType: .token)
    }
//
//    func startLiveActivityWithChannel(channelId: String) {
//        if #available(iOS 18.0, *){
//            startActivityWith(pushType: .channel(channelId))
//        }
//    }
//
//
//    func startActivityWith(pushType: PushType) {
//        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
//            print("You can't start live activity.")
//            return
//        }
//
//        do {
//            let atttribute = LiveActivityAttributes()
//            //LiveActivityAttributes(progress: 0.1)
//            let initialState = LiveActivityAttributes.ContentState(progress: 0.0,status: StatusLive.send,stateInfo: "",statusInfo: "")
//            let staleDate = Date(timeIntervalSinceNow: 10)
//            let activity = try Activity<LiveActivityAttributes>.request(
//                attributes: atttribute,
//                content: .init(state:initialState , staleDate: staleDate),
//                pushType: pushType
//            )
//            self.currentActivity = activity
//
////            let pushToken = activity.pushToken // Returns nil.
//
//            Task {
//
//                for await pushToken in activity.pushTokenUpdates {
//                    let pushTokenString = pushToken.reduce("") {
//                        $0 + String(format: "%02x", $1)
//                    }
//                    print("Activity:\(activity.id) push token: \(pushTokenString)")
//                    Logger.liveactivity.info("Activity:\(activity.id,privacy: .public) push token: \(pushTokenString,privacy: .public)")
//                    //send this token to your notification server
//                }
//            }
//        } catch {
//            print("start Activity From App:\(error)")
//            Logger.liveactivity.info("start Activity From App:\(error,privacy: .public)")
//        }
//    }
//
    func updateActivity(delay:Double, alert:Bool,progressValue:CGFloat,status:StatusLive,stateInfo: String,statusInfo: String) {
//        // register background task
//        var backgroundTask: UIBackgroundTaskIdentifier = UIBackgroundTaskIdentifier.invalid
//        backgroundTask = UIApplication.shared.beginBackgroundTask {
//            UIApplication.shared.endBackgroundTask(backgroundTask)
//            backgroundTask = UIBackgroundTaskIdentifier.invalid
//        }
//
//        DispatchQueue.main.asyncAfter(deadline: .now()+delay) { [weak self] in
//            UIApplication.shared.endBackgroundTask(backgroundTask)
//            self?.updateActivity(alert: alert,progressValue: progressValue,status: status,stateInfo: stateInfo,statusInfo:statusInfo)
//
        }
//
//    }
//
//
//
//    func updateActivity(alert:Bool,progressValue:CGFloat,status: StatusLive,stateInfo:String, statusInfo: String) {
//        Task {
//            guard let activity = currentActivity else {
//                return
//            }
//
//            var alertConfig: AlertConfiguration? = nil
//            let contentState: LiveActivityAttributes.ContentState = LiveActivityAttributes.ContentState(progress: progressValue,status:status,stateInfo: stateInfo,statusInfo: statusInfo)
//
//            if alert {
//                alertConfig = AlertConfiguration(title: "Emoji Changed", body: "Open the app to check", sound: .default)
//            }
//
//            await activity.update(ActivityContent(state: contentState, staleDate: Date.now + 15, relevanceScore: alert ? 100 : 50), alertConfiguration: alertConfig)
//        }
//    }
//
    func endActivity(dismissTimeInterval: Double?) {
//        Task {
//            guard let activity = currentActivity else {
//                return
//            }
//            ShareAPI.shared().log(1, "灵动岛   endActivity in")
//            let finalState = LiveActivityAttributes.ContentState(progress: 0,status: StatusLive.normal,stateInfo: "",statusInfo: "")
//            let dismissalPolicy: ActivityUIDismissalPolicy
//            if let dismissTimeInterval = dismissTimeInterval {
//                if dismissTimeInterval <= 0 {
//                    dismissalPolicy = .immediate
//                } else {
//                    dismissalPolicy = .after(.now + dismissTimeInterval)
//                }
//            } else {
//                dismissalPolicy = .default
//            }
//
//            await activity.end(ActivityContent(state: finalState, staleDate: nil), dismissalPolicy: dismissalPolicy)
//        }
    }
//    func endActivity(dismissTimeInterval: Double?,keepNotification: Bool) {
//        Task {
//            guard let activity = currentActivity else { return }
//            let finalState = LiveActivityAttributes.ContentState(
//                progress: 0,
//                status: StatusLive.normal,
//                stateInfo: "",
//                statusInfo: ""
//            )
//
//            let dismissalPolicy: ActivityUIDismissalPolicy = keepNotification ?
//                .immediate :
//                .default
//
//            await activity.end(
//                ActivityContent(state: finalState, staleDate: nil),
//                dismissalPolicy: dismissalPolicy
//            )
//        }
//    }
//
//
//    static func endActivity(activity:Activity<LiveActivityAttributes>, dismissTimeInterval: Double?) {
//        Task {
//            let finalState = LiveActivityAttributes.ContentState(progress: 0,status: StatusLive.normal, stateInfo: "",statusInfo: "")
//            let dismissalPolicy: ActivityUIDismissalPolicy
//            if let dismissTimeInterval = dismissTimeInterval {
//                if dismissTimeInterval <= 0 {
//                    dismissalPolicy = .immediate
//                } else {
//                    dismissalPolicy = .after(.now + dismissTimeInterval)
//                }
//            } else {
//                dismissalPolicy = .default
//            }
//
//            await activity.end(ActivityContent(state: finalState, staleDate: nil), dismissalPolicy: dismissalPolicy)
//        }
//    }

}
