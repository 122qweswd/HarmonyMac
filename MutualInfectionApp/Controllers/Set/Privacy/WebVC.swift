//
//  WebVC.swift
//  Peso King
//
//  Created by Ios on 2025/4/20.
//

import UIKit
import WebKit

//import StoreKit
//import MessageUI


class WebVC: MIBaseViewController {

    var webView: WKWebView?
    var progressView = UIProgressView()
    
    
    var progressObserver: NSKeyValueObservation?
    // var backItem: UIBarButtonItem?
    var urlStr : String?
    deinit {
        webView?.removeObserver(self, forKeyPath: "title")
        progressObserver?.invalidate()
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        progressView = UIProgressView(progressViewStyle: .default)
        progressView.tintColor =  UIColor.clear//UIColor(hexString:"#8952F9")
        self.contentView.addSubview(progressView)
        
        progressView.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
            make.height.equalTo(2)
        }
        
        
        let theConfiguration = WKWebViewConfiguration.init()
//        theConfiguration.userContentController.add(self, name:"riceIrisE")
//        theConfiguration.userContentController.add(self, name:"bagelGoos")
//        theConfiguration.userContentController.add(self, name:"speltBeec")
//        theConfiguration.userContentController.add(self, name:"soleLampR")
//        theConfiguration.userContentController.add(self, name:"duckMonke")
//        theConfiguration.userContentController.add(self, name:"peacockEg")
        webView = WKWebView(frame: .zero, configuration: theConfiguration)
        webView?.navigationDelegate = self
//        webView?.uiDelegate = self
        webView?.translatesAutoresizingMaskIntoConstraints = true
        webView?.addObserver(self, forKeyPath: "title", options: .new, context: nil)
//        webView?.scrollView.isScrollEnabled = false
        webView?.scrollView.showsVerticalScrollIndicator = false
        webView?.scrollView.showsHorizontalScrollIndicator = false
        self.contentView.addSubview(webView ?? WKWebView())
    
        webView?.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.top.equalTo(progressView.snp.bottom)
          
            $0.bottom.equalToSuperview()
        }
        
        let url = URL(string: urlStr ?? "")!
        let request = URLRequest(url: url)
        webView?.load(request)
        
        progressObserver = webView?.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
            guard let self = self else { return }
            let progress = webView.estimatedProgress // 转换为百分比形式显示，范围0-100%
            //print("加载进度：\(progress)%") // 可以在这里更新UI，如进度条等。
            self.progressView.progress = Float(progress)
        }
        
        if webView?.canGoBack ?? false {
            // 可以返回上一页，执行返回操作
            webView?.goBack()
        } else {
            // 不能返回上一页，可以执行其他操作或显示提示
            print("已经是最开始页面，无法返回")
        }
    
        // Do any additional setup after loading the view.
    }

    @objc func didTapCustombackItem() {
        
        self.navigationController?.popToRootViewController(animated: true)
    }

}
extension WebVC:WKNavigationDelegate{
    
    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey : Any]?,
                               context: UnsafeMutableRawPointer?) {
        if keyPath == "title",
           let newTitle = change?[.newKey] as? String {
            // 更新iOS应用程序中的标题
            self.navigationView?.title =  ""//newTitle
            //self.navigationItem.title = newTitle
            //            print("title 改变了",newTitle)
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // 页面加载完成后，检查是否可以返回上一页并更新UI
       // updateBackButtonState()
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        // 页面开始加载时，也可以更新UI，尽管这不是必须的
        //updateBackButtonState()
    }
  
    
//    private func updateBackButtonState() {
//        // 根据canGoBack属性更新UI，例如启用或禁用返回按钮
//        let backButton = UIBarButtonItem.init(image: UIImage.returnIc.withRenderingMode(.alwaysOriginal), style: .done, target: self, action: #selector(goBack))
//        backButton.isEnabled = webView?.canGoBack ?? false
//        // 假设你把backButton添加到了navigationItem.leftBarButtonItem中
//        navigationItem.leftBarButtonItem = backButton.isEnabled ? backButton : backItem
//    }
    
    @objc private func goBack() {
        if webView?.canGoBack ?? false {
            webView?.goBack()
        } else {
            self.navigationController?.popToRootViewController(animated: true)
        }
    }
}

 
//extension WebVC:  WKScriptMessageHandler,WKUIDelegate {
//    
//    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
//        print(message.body)
//        if message.name == "riceIrisE" {
//            //riceIrisE([adultit,companyit])
//           let aa =  message.body as? [String]
//            report(productId: (aa?.first ?? "") , sapiist: "10", startDate: Date(), endDate: Date())
//        }else if message.name == "bagelGoos"{
//            
//            //bagelGoos(labiwalkness)
//            //跳转原生或者H5--根据参数跳转H5或者本地路由跳转原生页面
//            goToPage(urlStr: (message.body as? String) ?? "")
//            
//        }else if message.name == "speltBeec"{
//            //关闭当前 H5
//            self.navigationController?.popViewController(animated: true)
//            
//        }else if message.name == "soleLampR"{
//            //回到 App 首页
//            let rootVc = kWindow?.rootViewController as? RTContainerNavigationController
//            let tabbarVC = rootVc?.viewControllers.first as?  KingTabBarViewController
//            
//            tabbarVC?.selectedIndex = 0
//            self.navigationController?.popToRootViewController(animated: true)
//            
//        }else if message.name == "duckMonke"{
////            if MFMailComposeViewController.canSendMail() {
////                
////                let mailComposerVC = MFMailComposeViewController()
////                let recipients = [(message.body as? String)?.components(separatedBy: ":").last ?? ""]
////                mailComposerVC.setToRecipients(recipients)
////                mailComposerVC.setSubject((Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String) ?? "")
////                let body = "body"
////                mailComposerVC.setMessageBody(body, isHTML: false)
////                mailComposerVC.mailComposeDelegate = self // 需要遵循
////                present(mailComposerVC, animated: true, completion: nil)
////            }
//            
//            let email = (message.body as? String)?.components(separatedBy: ":").last ?? ""
//            let appName = (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String) ?? ""
//            
//            let body = "?body=APP:" + appName + "\nPhone:" + (UserDefaults.standard.string(forKey: kingUsername) ?? "")
//            //subject=hello&
//            
//            var mailUrl = "mailto:" + email + body
//            mailUrl = mailUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
//            
//            if let url = URL(string: mailUrl) {
//                if UIApplication.shared.canOpenURL(url) {
//                    UIApplication.shared.open(url)
//                } else {
//                    //print("无法打开邮件应用")
//                }
//            } else {
//               // print("URL 格式错误")
//            }
//            
//                                          
////            UIApplication.shared.open(URL(string: "mailto:" + email + body)!, options: [:], completionHandler: nil)
//            
//        }else if message.name == "peacockEg"{
//            
//            //弹出 App 系统评分弹窗
//            if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
//                DispatchQueue.main.async {
//                    if #available(iOS 14.0, *) {
//                        SKStoreReviewController.requestReview(in: scene)
//                    } else {
//                        SKStoreReviewController.requestReview()
//                    }
//                }
//            }
//            
//        }
//
//    }
//}
//extension WebVC: MFMailComposeViewControllerDelegate {
//    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
//        controller.dismiss(animated: true, completion: nil)
//        if let error = error {
//            // 处理错误信息
//        }
//    }
//}
