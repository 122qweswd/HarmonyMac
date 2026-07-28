//
//  MIWebBrowserViewController.swift
//  MutualInfectionMac
//
//  Created by delegate on 2025/9/30.
//

import AppKit
import WebKit

class MIWebBrowserViewController: NSViewController {

    // MARK: - Properties
    private lazy var webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptEnabled = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.autoresizingMask = [.width, .height]
        // 添加进度监听
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
        return webView
    }()
    // 进度指示器
    private lazy  var progressIndicator: NSProgressIndicator = {
        let progressIndicator = NSProgressIndicator()
        progressIndicator.style = .bar
        progressIndicator.isIndeterminate = false
        progressIndicator.minValue = 0
        progressIndicator.maxValue = 1
        progressIndicator.controlSize = .small
        progressIndicator.isHidden = true
        return progressIndicator
    }()
    
    override func loadView() {
         view = NSView()
     }
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        // 监听窗口标题变化
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.title), options: .new, context: nil)
    }
    
    override func viewWillDisappear() {
        super.viewWillDisappear()
        // 移除标题观察者（与添加位置对应）
        webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.title))
    }
    
    deinit {
        // 移除所有观察者
        webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.title))
        webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.white.cgColor
        
        [webView, progressIndicator].forEach {
            view.addSubview($0)
        }
        webView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        progressIndicator.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(2)
        }
    }
    
    func loadURLPage(urlStr: String) {
//        guard let url = URL(string: urlStr) else { return }
//        let request = URLRequest(url: url)
//        webView.load(request)
        loadURL(from: urlStr)
    }
    
    private func loadURL(from text: String) {
        // 处理用户输入的URL
        var urlString = text
        if !urlString.lowercased().hasPrefix("http://") &&
           !urlString.lowercased().hasPrefix("https://") {
            urlString = "https://" + urlString
        }
        
        guard let url = URL(string: urlString) else {
            showError(message: "无效的URL")
            return
        }
        
        let request = URLRequest(url: url)
        webView.load(request)
    }
    
    private func showError(message: String) {
        let alert = NSAlert()
        alert.messageText = "错误"
        alert.informativeText = message
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }
    
    // MARK: - KVO
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(WKWebView.estimatedProgress) {
            guard let progress = change?[.newKey] as? Double else { return }
                        progressIndicator.doubleValue = progress
                        
                        // 更精确的进度条显示控制
                        if progress >= 1.0 {
                            // 延迟隐藏，确保进度条完成动画
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                self.progressIndicator.isHidden = true
                            }
                        } else {
                            progressIndicator.isHidden = false
                        }
        } else if keyPath == #keyPath(WKWebView.title) {

            print("标题 ； \(webView.title)")
            
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    /*
    // MARK: - Actions
    @objc private func goBack(_ sender: Any) {
        if webView.canGoBack {
            webView.goBack()
        }
    }
    
    @objc private func goForward(_ sender: Any) {
        if webView.canGoForward {
            webView.goForward()
        }
    }
    @objc private func reloadPage(_ sender: Any) {
        webView.reload()
    }
    */
}
extension MIWebBrowserViewController: WKNavigationDelegate, WKUIDelegate {
    
    // MARK: - WKNavigationDelegate
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        progressIndicator.isHidden = false
        progressIndicator.doubleValue = 0
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("加载完成")
        progressIndicator.isHidden = true
        progressIndicator.doubleValue = 1.0
        // 延迟隐藏，让进度条完成到100%的动画
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.progressIndicator.isHidden = true
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("加载失败: \(error.localizedDescription)")
        if let currentWindow = self.view.window {
            showSheetAlert(messageText: "", message: "加载失败".localized, window: currentWindow) {
                
            }
        }
        progressIndicator.isHidden = true
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("连接失败: \(error.localizedDescription)")
        if let currentWindow = self.view.window {
            showSheetAlert(messageText: "", message: "连接失败".localized, window: currentWindow) {
                
            }
        }
        progressIndicator.isHidden = true
    }
    // 处理HTTPS证书问题（仅用于测试环境）
        func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
                if let serverTrust = challenge.protectionSpace.serverTrust {
                    let credential = URLCredential(trust: serverTrust)
                    completionHandler(.useCredential, credential)
                    return
                }
            }
            completionHandler(.performDefaultHandling, nil)
        }
    // MARK: - WKUIDelegate
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        // 在当前窗口打开新链接
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }
    // 阻止页面自动刷新
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        print("JavaScript Alert: \(message)")
        completionHandler()
    }
}
