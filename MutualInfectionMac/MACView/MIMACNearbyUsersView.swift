//
//  MIMACNearbyUsersView.swift
//  MutualInfection
//
//  Created by apple on 2025/10/15.
//

import AppKit
import SnapKit

class MIMACNearbyUsersView: NSView, NSCollectionViewDelegateFlowLayout {
    
    lazy var scrollView: NSScrollView = {
        let sv = NSScrollView()
        sv.drawsBackground = false
        sv.wantsLayer = true
        sv.backgroundColor = .clear
        sv.contentView.wantsLayer = true
        sv.contentView.backgroundColor = .clear
        sv.autohidesScrollers = true
        
        // 替换默认滚动条为自定义滚动条
        sv.verticalScroller = customVerticalScroller
        
        return sv
    }()
    
    lazy var customVerticalScroller: MICustomScroller = {
        let customScroller = MICustomScroller()
        customScroller.knobColor = NSColor(hex: "#000000", alpha: 0.1) // 滑块颜色
        return customScroller
    }()
  
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
    var dragFileToDevice: ((MIDevice,[URL]) -> Void)?
    // MARK: - 添加设备状态更新方法
    public func updateDeviceStatus(_ userInfo: MIDevice) {
       
        DispatchQueue.main.async {
            if let index = self.userInfos.firstIndex(where: { $0.uuid == userInfo.uuid }) {
//                self.userInfos[index].deviceStatus = userInfo.deviceStatus
                if let cell = self.collectionView.item(at: IndexPath(item: index, section: 0)) as? MIMACNearbyUsersCell {
                    cell.userInfo = userInfo
                }
            }
            // 当设备完成或取消时，检查是否有等待中的设备需要处理
            if userInfo.deviceStatus == .completed || userInfo.deviceStatus == .cancelled {
                print("✅ 设备 \(userInfo.name) 完成/取消，检查队列中的等待设备")
            }
        }
    }
    
    lazy var titleLable: NSTextField = {
        let label = NSTextField()
        label.isBordered = false
        label.translatesAutoresizingMaskIntoConstraints = false
        label.backgroundColor = .clear
        label.alignment = .center
        label.font = .mi.pingFangSCRegular(size: 13)
        label.textColor = .mi.hex("#3c3c43", alpha: 0.6)
        label.stringValue = "附近".localized
        label.isEditable = false
        label.isSelectable = false
        label.isHidden = true
        return label
    }()
    
    lazy var collectionView: NSCollectionView = {
        
        let homeLayout = NSCollectionViewFlowLayout()
        homeLayout.scrollDirection = .vertical
        homeLayout.minimumLineSpacing = 0
        homeLayout.minimumInteritemSpacing = 8
        // 设置每个节的内边距
        homeLayout.sectionInset = NSEdgeInsets(top: 0, left: 0, bottom: 20, right: 0)

        let collectionView = NSCollectionView(frame: .zero)
        collectionView.collectionViewLayout = homeLayout
        collectionView.wantsLayer = true
        collectionView.layer?.backgroundColor = .clear
        collectionView.backgroundColors? = [.clear]
        collectionView.delegate = self
        collectionView.dataSource = self
        
        
        // 注册XIB文件
        collectionView.register(MIMACNearbyUsersCell.self, forItemWithIdentifier: NSUserInterfaceItemIdentifier("MIMACNearbyUsersCell"))
        collectionView.register(NSCollectionViewItem.self, forItemWithIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Cell"))
        return collectionView
    }()
    
    init(frame: CGRect, userInfos: [MIDevice]) {
        super.init(frame: frame)
        self.wantsLayer = true
        self.layer?.backgroundColor = .clear
        self.translatesAutoresizingMaskIntoConstraints = false
         
        self.userInfos = userInfos
        self.addSubview(titleLable)
        self.addSubview(scrollView)
        titleLable.snp.makeConstraints() {
            $0.top.equalToSuperview().offset(20)
//            $0.height.equalTo(18)
            $0.leading.equalTo(12)
        }
        
        scrollView.snp.makeConstraints {
            $0.top.equalTo(titleLable.snp.bottom).offset(18)
            $0.leading.equalTo(0)
            $0.trailing.equalTo(0)
            $0.bottom.equalTo(-8)
        }
        scrollView.documentView = collectionView
        
//        self.addSubview(collectionView)
//        collectionView.snp.makeConstraints {
//            $0.top.equalTo(titleLable.snp.bottom).offset(22)
//            $0.leading.equalTo(16)
//            $0.trailing.equalTo(-16)
//            $0.bottom.equalTo(-50)
//        }

    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}




extension MIMACNearbyUsersView: NSCollectionViewDataSource {
    
    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        return 1
    }
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return userInfos.count
    }
    
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let cell = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier("MIMACNearbyUsersCell"), for: indexPath) as? MIMACNearbyUsersCell
        
        cell?.userInfo = userInfos[indexPath.item]

        // 设置设备点击回调
        cell?.onDeviceTapped = { [weak self]  userInfo in
            self?.selectDeviceTapped?(userInfo)
        }
        cell?.onDragFileToDevice = {[weak self] userInfo,urls in
            self?.dragFileToDevice?(userInfo,urls)
            
        }
        return cell ?? MIMACNearbyUsersCell()
    }

    func test_changeProgress(cell: MIMACNearbyUsersCell) {
        let randomNum = arc4random_uniform(80) + 1
        let progress = CGFloat(randomNum) / 100.0
        cell.userInfo?.progress += progress
        cell.updateProgress(progress: cell.userInfo?.progress ?? 0)
//        self.collectionView.reloadData()
    }
}

extension MIMACNearbyUsersView: NSCollectionViewDelegate {
    
    func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize.init(width:88, height:131+5)
    }
}
