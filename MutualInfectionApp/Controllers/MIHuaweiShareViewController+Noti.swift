//
//  MIHuaweiShareViewController+Noti.swift
//  MutualInfectionApp
//
//  Created by apple on 2025/10/10.
//

import Foundation
import UIKit

extension MIHuaweiShareViewController{
    
    func  notificationAction() {
        // 退出到后台
        NotificationCenter.default.addObserver(self, selector:#selector(willResionActive), name: UIApplication.willResignActiveNotification,object: nil);
        //重回app 监听
        NotificationCenter.default.addObserver(self, selector:#selector(didBecome), name: UIApplication.didBecomeActiveNotification, object: nil);
    }
   
    
    @objc func willResionActive() {
       
        self.scanView?.waveView.pause()
        self.isShowed = false
    }
    
    //重新回到app 监听
    @objc func didBecome() {
       
        if self.scanView?.isHidden == false {
            self.scanView?.waveView.play()
        }
        if AppleLoginHandlerValue{
            AppleLoginHandlerValue = false
            return
        }
        getPermissionState()
    }
}
