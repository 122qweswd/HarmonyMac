//
//  MainWindowController+test.swift
//  MutualInfectionMac
//
//  Created by apple on 2025/10/16.
//

import Foundation

extension MainWindowController {
  
    func setToData() {
        
        
        var userArr: [MIDevice] = []
        for i in 1...50 {
            let name = "设备名称--\(i)"
            let randomNum = Int(arc4random_uniform(999999999))
            let uuid = "uuid-\(i)"
            let d = MIDevice(name: name, uuid: uuid,hwId: uuid,devicetype: 6)
            d.deviceStatus = .normal
            userArr.append(d)
        }
        
        self.deviceInfos = userArr
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0){
         
            self.showScanView(isShow: false)
            // 调用更新方法
            self.nearbyUsersView.updateUserInfos( self.deviceInfos)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0){
    //            self.showScanView(isShow: true)
    //            self.wavePostFileView?.currentDeviceStatus = .didReject
    //            self.wavePostFileView?.onDeviceStatusChanged?(.didReject)
        }
    }



    //self.userInfos  = userArr
}



