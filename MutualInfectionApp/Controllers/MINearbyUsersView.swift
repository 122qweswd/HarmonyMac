//
//  MINearbyUsersView.swift
//  MutualInfection
//
//  Created by apple on 2025/9/1.
//

import UIKit
import SnapKit

class MINearbyUsersView: UIView, UICollectionViewDelegateFlowLayout {
    private var userInfos: [MIDevice] = []
    // 设备队列管理
//    private var deviceQueue: [MIDevice] = []
    // MARK: - 添加公开的更新方法
    public func updateUserInfos(_ newUserInfos: [MIDevice]) {
        DispatchQueue.main.async {
            self.userInfos = newUserInfos
            self.collectionView.reloadData()
        }
    }
    //,CGRect
    var selectDeviceTapped: ((MIDevice) -> Void)?
    // MARK: - 添加设备状态更新方法
    public func updateDeviceStatus(_ userInfo: MIDevice) {
       
        DispatchQueue.main.async {
            if let index = self.userInfos.firstIndex(where: { $0.uuid == userInfo.uuid }) {
//                self.userInfos[index].deviceStatus = userInfo.deviceStatus
                if let cell = self.collectionView.cellForItem(at: IndexPath(item: index, section: 0)) as? MINearbyUsersCell {
                    cell.userInfo = userInfo
                }
            }
            // 当设备完成或取消时，检查是否有等待中的设备需要处理
            if userInfo.deviceStatus == .completed || userInfo.deviceStatus == .cancelled {
                //            if deviceudidCheck.contains(userInfo.device.uuid){
                //                if let index = deviceudidCheck.firstIndex(of: userInfo.device.uuid) {
                //                    print("✅ 设备 device.deviceStatus \(userInfo.device.uuid) 删除")
                //                        deviceudidCheck.remove(at: index)
                //                }
                //            }
                print("✅ 设备 \(userInfo.name) 完成/取消，检查队列中的等待设备")
                // 延迟一点时间，确保状态更新完成
                //            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                //                self?.processNextDeviceInQueue()
                //            }
            }
        }
    }
    
    // 添加点击回调
   // public var onDeviceTappedGetCellConvertScreenFrame: ((CGRect) -> Void)?
    
    lazy var titleLable: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = SFCompact(weight: .regular,size: 13)
        label.textColor = "#000000".color
        label.text = "附近".localized
        label.alpha = 0.65
        return label
    }()
    
    lazy var collectionView: UICollectionView = {
        
        let homeLayout = UICollectionViewFlowLayout()
        var deviceGap: CGFloat
        if UIDevice.current.userInterfaceIdiom == .pad {
            deviceGap = 35
        } else {
            deviceGap = (ksUIScreenW - 32 - 72*4) / 3.0
        }
        homeLayout.minimumLineSpacing = 0
        homeLayout.minimumInteritemSpacing = 0
        homeLayout.scrollDirection = .vertical
        homeLayout.minimumLineSpacing = 0
        homeLayout.minimumInteritemSpacing = deviceGap
        
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: homeLayout)
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.dataSource = self
        
        
        // 注册XIB文件
        collectionView.register(MINearbyUsersCell.self, forCellWithReuseIdentifier: "MINearbyUsersCell")
        
       // register(MIDeviceItem.self, forCellWithReuseIdentifier: "MIDeviceItem")
        
        return collectionView
    }()
    
     init(frame: CGRect, userInfos: [MIDevice]) {
        super.init(frame: frame)
        self.userInfos = userInfos
        self.backgroundColor = .clear
        self.addSubview(titleLable)
        self.addSubview(collectionView)
        titleLable.snp.makeConstraints() {
            $0.top.equalToSuperview().offset(17)
            $0.height.equalTo(18)
            if UIDevice.current.userInterfaceIdiom == .pad {
                $0.leading.equalTo(38)
            }else{
                $0.leading.equalTo(19)
            }
            
        }
        collectionView.snp.makeConstraints {
            $0.top.equalTo(titleLable.snp.bottom).offset(22)
            if UIDevice.current.userInterfaceIdiom == .pad {
                $0.leading.equalTo(32)
                $0.trailing.equalTo(-32)
            }else{
                $0.leading.equalTo(16)
                $0.trailing.equalTo(-16)
            }
            $0.bottom.equalToSuperview()
        }

    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}




extension MINearbyUsersView: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return userInfos.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let userInfo: MIDevice = userInfos[indexPath.item]
        /// cell复用会导致其他设备异常展示进度条
        let reuseIdentifier = "MINearbyUsersCell-\(userInfo.hwId)"
        collectionView.register(MINearbyUsersCell.self, forCellWithReuseIdentifier: reuseIdentifier)
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! MINearbyUsersCell
        cell.userInfo = userInfo
        //configure(with: userInfos[indexPath.item])
        // 设置设备点击回调
        cell.onDeviceTapped = { [weak self]  userInfo in
//            guard let cell = cell else { return }
//            let cellConverScreenFrame = collectionView.convert(cell.frame, to: self)
//            print("cellConverScreenFrame = \(cellConverScreenFrame)")
            
            self?.selectDeviceTapped?(userInfo)
            //self?.handleDeviceTapped(device)
//            self?.onDeviceTappedGetCellConvertScreenFrame?(cellConverScreenFrame)
        }
        return cell
    }


}

extension MINearbyUsersView: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
//        let itemsPerRow: CGFloat = 4
//        let totalSpacing = (itemsPerRow - 1) * 10 // N个item需要(N-1)个间距
//        let availableWidth = ksUIScreenW - 32 - totalSpacing
//        let itemWidth = availableWidth / itemsPerRow

        return CGSize.init(width:72, height:UIDevice.current.userInterfaceIdiom == .pad ? 135 : 122)
    }
}

