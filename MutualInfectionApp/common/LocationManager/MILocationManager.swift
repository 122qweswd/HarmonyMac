//
//  MILocationManager.swift
//  MutualInfectionApp
//
//  Created by ww on 2025/9/22.
//

import UIKit
import Foundation
import CoreLocation

class MILocationManager: NSObject,CLLocationManagerDelegate {
    var manger : ShareAPI?
    private var currentAlert: UIViewController?
    var showLocation = false
    var sucess:  (() -> ())?
    var fail: (() -> ())?
    static let shared = MILocationManager()
    var locationManager = CLLocationManager()
    func getLocationStatus(sucess: @escaping  (() -> ()),fail:@escaping (() -> ())){
        manger = ShareAPI.shared()
        self.manger?.log(1, "getLocationStatus In")
        self.sucess = sucess
        self.fail = fail
        self.requestnUseAuthorization()
    }
    
    func requestnUseAuthorization() {

        DispatchQueue.main.async {
            self.manger?.log(1, "requestnUseAuthorization In")
            self.locationManager = CLLocationManager()
            //设置定位服务管理器代理
            self.locationManager.delegate = self
            //设置定位模式
            self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
            //更新距离
            //        manager?.distanceFilter = 100
            //发送授权申请
            self.locationManager.requestAlwaysAuthorization()
           
        }
    }


    
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
//        print("位置权限 status:\(status)")
        self.manger?.log(1, "位置权限 status:\(status)")
        if status == .notDetermined {
            
        }
        else if status == .authorizedWhenInUse || status == .authorizedAlways {
            self.manger?.log(1, "位置权限 :authorizedWhenInUse  authorizedAlways ")
            self.currentAlert?.dismiss(animated: true, completion: nil)
            self.sucess?()
        } else {
            locationManager.stopUpdatingLocation()
            if !showLocation{
                self.manger?.log(1, "showLoactionAlertManager start")
                currentAlert  = AlertManager.showAlert(
                    title: "位置权限未打开",
                    message: "没有获得位置权限，请在设置中打开位置权限".localized,
                    autoDismiss: true,
                    cancelTitle: nil,
                    confirmTitle: "去设置".localized,
                    confirmAction: {
                    
                    if let url = URL(string: UIApplication.openSettingsURLString + "App-Prefs:root=APP") {
                        UIApplication.shared.open(url)
                    }
                    self.fail?()
                    self.showLocation = false
                    })
                showLocation = true
            }
        }
        
    }
}
