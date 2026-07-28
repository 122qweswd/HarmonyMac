// MIBaseViewController.swift
import UIKit
import SnapKit

/// Base view controller, 使用自定义view, 替代系统navigation bar显示
class MIBaseViewController: UIViewController {
    
    // MARK: - Properties
    
    /// 导航栏标题
    override var title: String? {
        didSet {
            navigationView?.title = title
        }
    }
    
    deinit {
        print("deinit:释放============\(self)")
    }
    /// 导航栏view 看UI图给出来的效果，导航高度好像会比系统导航栏要高，为了后续好调整，就直接使用自定义View的形式添加，新的controller需要继承BaseViewController，每个页面可实现单独管理，避免后续会有导航栏高度问题
    private(set) var navigationView: MINavigationView?
    
    /// content view,
    /// 根据mi_preferredNavigationBarHidden与mi_bottomSafeAreaInset的值控制frame;
    /// subview添加在contentView上可以不需要再适配导航栏高度等因素;
    /// 以下场景不会创建content view, 而是返回self.view:
    /// mi_preferredNavigationBarHidden=YES && mi_bottomSafeAreaInset=0
    private(set) var contentView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()
    
    private var hasSetupContentView = false
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.view.backgroundColor = UIColor.white
        setupNavigationView()
        setupContentView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if let parent = self.parent, parent is UINavigationController {
            self.navigationController?.navigationBar.isHidden = true
        }
        
        if let navigationView = self.navigationView {
            navigationView.setupButtonEventsOnViewWillAppearForViewContoller(self)
            self.view.bringSubviewToFront(navigationView)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if let parent = self.parent, parent is UINavigationController {
            self.navigationController?.interactivePopGestureRecognizer?.isEnabled = self.mi_popGestureEnabeld()
        }
    }
    
    // MARK: - Navigation Configuration
    
    /// 是否隐藏导航栏view, 子类重写get方法进行设置
    func mi_preferredNavigationBarHidden() -> Bool {
        return false
    }
    
    /// 底部safeAreaInset, 默认0
    func mi_bottomSafeAreaInset() -> CGFloat {
        return 0.0
    }
    
    /// 是否允许滑动返回, 默认YES
    func mi_popGestureEnabeld() -> Bool {
        return true
    }
    
    /// 自定义navigation view样式
    func mi_configNavigationViewStyle(_ style: MINavigationStyleConfiguration) {
        // 子类可以重写此方法来自定义导航栏样式
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        .darkContent
    }
    
    // MARK: - Setup Methods
    
    private func setupNavigationView() {
        if !mi_preferredNavigationBarHidden() {
            let style = MINavigationStyleConfiguration.default.copy() as! MINavigationStyleConfiguration
            mi_configNavigationViewStyle(style)
            
            let navigationView = MINavigationView.navigationViewForViewController(self, styleConfiguration: style)
            self.view.addSubview(navigationView)
            self.navigationView = navigationView
            
            // 使用SnapKit布局导航视图
            navigationView.snp.makeConstraints { make in
                make.top.equalToSuperview().offset(MISafeAreaTop)
                make.leading.trailing.equalToSuperview()
                make.height.equalTo(MINavigationView.contentHeight())
            }
        }
    }
    
    private func setupContentView() {
        // 无navigation view且无safe area inset, 不另外创建content view
        if mi_preferredNavigationBarHidden() && mi_bottomSafeAreaInset() <= 0 {
            // 在这种情况下，contentView 就是 self.view
            // 我们不需要做任何额外的设置w
            return
        }
        
        // 添加 contentView 到视图层级
        self.view.addSubview(contentView)
        
        // 使用SnapKit布局内容视图
        contentView.snp.makeConstraints { make in
            if let navigationView = navigationView {
                make.top.equalTo(navigationView.snp.bottom)
            } else {
                make.top.equalToSuperview()
            }
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().offset(-mi_bottomSafeAreaInset())
        }
        
        hasSetupContentView = true
    }
}
