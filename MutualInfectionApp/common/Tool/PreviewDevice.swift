// PreviewExtensions.swift
#if canImport(SwiftUI) && DEBUG
import SwiftUI

@available(iOS 13.0, *)
public extension UIView {
    private struct Preview: UIViewRepresentable {
        let view: UIView
        
        func makeUIView(context: Context) -> UIView {
            return view
        }
        
        func updateUIView(_ uiView: UIView, context: Context) {
            // 空实现
        }
    }
    
    func preview() -> some View {
        Preview(view: self)
    }
    
    func previewLayout(_ layout: PreviewLayout) -> some View {
        self.preview().previewLayout(layout)
    }
    
    func previewDisplayName(_ name: String) -> some View {
        self.preview().previewDisplayName(name)
    }
}

@available(iOS 13.0, *)
public extension UIViewController {
    private struct Preview: UIViewControllerRepresentable {
        let viewController: UIViewController
        
        func makeUIViewController(context: Context) -> UIViewController {
            return viewController
        }
        
        func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
            // 空实现
        }
    }
    
    func preview() -> some View {
        Preview(viewController: self)
    }
  
    func previewLayout(_ layout: PreviewLayout) -> some View {
        self.preview().previewLayout(layout)
    }
    
    func previewDisplayName(_ name: String) -> some View {
        self.preview().previewDisplayName(name)
    }
}
#endif
