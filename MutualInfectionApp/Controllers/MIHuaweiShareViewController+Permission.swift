//
//  MIHuaweiShareViewController+Extension.swift
//  MutualInfectionApp
//
//  Created by apple on 2025/9/24.
//

import Foundation
import UIKit

extension MIHuaweiShareViewController{
    
    func getPermissionState(){
        if  isShowed{
            return
        }
        isShowed = true

     
        
        self.isShowWifiAlter = false
        self.isShowLocalAlter = false
        self.isShowBluetoothAlter = false
        self.isShowPhotoAlter = false
        self.isShowAlbumAlter = false
        getLocalStatus()
//        if isShowLocalAlter == false{
//            getLocalStatus()
//        }else if isShowWifiAlter == false{
//            getWiFiStatus()
//        }else{
//            getBlueToothSttus()
//        }
    }
    
    func getLocalStatus() {
     
        if isShowLocalAlter == false {
            isShowLocalAlter = true
            MILocationManager.shared.getLocationStatus {
                //下一个 权限判断
                self.getWiFiStatus()
                
                
            } fail: {
                self.isShowed = false
                self.isShowLocalAlter = false
            }
        }
    }
    
    func getWiFiStatus() {
        
        if isShowWifiAlter == false {
            isShowWifiAlter = true
            MIWiFiManager.shared.getWiFiDataPermission {
                self.getBlueToothStatus()
            } fail: {
                self.isShowed = false
                self.isShowWifiAlter = false
            }
        }
    }
    

    

    func getBlueToothStatus() {
       
        if isShowBluetoothAlter == false {
            isShowBluetoothAlter = true
            MIBluetoothManager.shared.getBluetoothStatus {
//                self.getPhotoStatus(isReceive: false)
            } fail: {
                self.isShowed = false
                self.isShowBluetoothAlter = false
            }
        }
    }
    
    func getPhotoStatus(isReceive:Bool) {
        if isReceive{
            MIPhotoPermissionManager.shared.getPhotoPermissionStatus(isReceive: isReceive) {
                   
            } fail: {
             
            }
        }else{
            if isShowPhotoAlter == false {
                isShowPhotoAlter = true
                MIPhotoPermissionManager.shared.getPhotoPermissionStatus(isReceive: isReceive) {
                    self.getContactStatus(isReceive: false)
                } fail: {
                    self.isShowed = false
                    self.isShowPhotoAlter = false
                }
            }
        }
    }
    
    
    func getContactStatus(isReceive:Bool) {
        if isReceive{
            MIContactPermissionManager.shared.getContactPermissionStatus(isReceive:isReceive){
                   
            } fail: {
             
            }
        }else{
            if isShowAlbumAlter == false {
                isShowAlbumAlter = true
                MIContactPermissionManager.shared.getContactPermissionStatus(isReceive:isReceive) {
                    
                } fail: {
                    self.isShowed = false
                    self.isShowAlbumAlter = false
                }
            }
        }
    }
}
