#if canImport(SwiftUI) && DEBUG
import SwiftUI

// UIView 预览
struct MyView_Preview: PreviewProvider {
    static var previews: some View {
        UIViewPreview {
            let view = MINaviUserInfoView()
            // 配置视图
            return view
        }
        .previewLayout(.sizeThatFits)
        .padding(10)
    }
}

// UIViewController 预览
struct MyViewController_Preview: PreviewProvider {
    static var previews: some View {
        UIViewControllerPreview {
            let vc = MIHuaweiShareViewController()
            return vc
        }
    }
}

// 预览辅助工具
struct UIViewPreview<View: UIView>: UIViewRepresentable {
    let view: View
    
    init(_ builder: @escaping () -> View) {
        view = builder()
    }
    
    func makeUIView(context: Context) -> View {
        return view
    }
    
    func updateUIView(_ uiView: View, context: Context) {
        uiView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        uiView.setContentHuggingPriority(.defaultHigh, for: .vertical)
    }
}

struct UIViewControllerPreview<ViewController: UIViewController>: UIViewControllerRepresentable {
    let viewController: ViewController
    
    init(_ builder: @escaping () -> ViewController) {
        viewController = builder()
    }
    
    func makeUIViewController(context: Context) -> ViewController {
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: ViewController, context: Context) {
        // 空实现
    }
}
#endif
