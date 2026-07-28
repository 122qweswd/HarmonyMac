//
//  ViewController.swift
//  MutualInfection
//
//  Created by Niko on 2025/8/30.
//

import UIKit
import CoreLocation
import IBAnimatable
import Photos

class ViewController: MIBaseViewController {
    
    private lazy var menu = MIWelcomeView()
    private lazy var menuPad = MIWelcomePadView()
    var locationManager : CLLocationManager?
    
    var bgImgView = UIImageView()
    
    var onAcceptTappedToShareExtensionCallBack: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        bgImgView.image = UIImage.start
        bgImgView.contentMode = .scaleAspectFill
        self.view.addSubview(bgImgView)
        
        
        let iconStack = UIStackView()
        iconStack.spacing = 24
        iconStack.axis = .vertical
        iconStack.alignment = .center
        iconStack.distribution = .fill
        
        let iconImageView = UIImageView()
        iconImageView.image = UIImage.launchIconR
        
        let title = UILabel()
        title.text = appName
        title.font = UIFont(name: "PingFangSC-Medium", size: 24)
        
        
        iconStack.addArrangedSubview(iconImageView)
        iconStack.addArrangedSubview(title)
        
        
        self.view.addSubview(iconStack)
        
        iconStack.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(MISafeAreaTop + 80)
        }
     
        bgImgView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        self.locationManager = CLLocationManager()
        //设置定位服务管理器代理
//        self.locationManager?.delegate = self
        //设置定位模式
        self.locationManager?.desiredAccuracy = kCLLocationAccuracyBest
        //更新距离
        //        manager?.distanceFilter = 100
        //发送授权申请
        self.locationManager?.requestAlwaysAuthorization()
        
        
        menu.onAcceptTapped = { [weak self] in
            guard let self = self else { return }
            onAcceptTappedToShareExtensionCallBack?()
            
            let currentStatusPhoto = PHPhotoLibrary.authorizationStatus()
            if currentStatusPhoto == .notDetermined {
                // 权限未确定，直接请求权限（会弹出系统弹窗）
                PHPhotoLibrary.requestAuthorization { [weak self] status in
                    
                }
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if UIDevice.current.userInterfaceIdiom == .pad {
            self.view?.addSubview(menuPad)
            menuPad.snp.makeConstraints {
               $0.edges.equalToSuperview()
            }
        }else{
            self.view?.addSubview(menu)
            menu.snp.makeConstraints {
                $0.edges.equalToSuperview()
            }
        }
    }
    

    
    /// 等待用户授权
    func waitForAuthorization(callBack: (() -> Void)?) {
        onAcceptTappedToShareExtensionCallBack = callBack
    }
}




//extension ViewController:CLLocationManagerDelegate{
//    
//   
//    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
//       
//        if status == .authorizedWhenInUse || status == .authorizedAlways {
//           
////            DispatchQueue.main.asyncAfter(deadline: .now() + 8.0){
////
////            }
//        }else if status == .restricted || status == .denied{
//            
//            DispatchQueue.main.async {
//                
//            }
//            
//        }else if status == .notDetermined{
//            
//        }else{
//            DispatchQueue.main.async {
//             
//            }
//        }
//   
//    }
////    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
////        guard locations.last != nil else { return }
////        
////        //获取最新的坐标
////     
////
////        locationManager?.stopUpdatingLocation()
////        
////        
////        self.LonLatToCity()
////          //print("当前位置: \(location.coordinate.latitude), \(location.coordinate.longitude)")
////      }
////    
////    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
////          print("获取位置失败: \(error)")
////        locationManager?.stopUpdatingLocation()
////      }
//    
//
//
//}
