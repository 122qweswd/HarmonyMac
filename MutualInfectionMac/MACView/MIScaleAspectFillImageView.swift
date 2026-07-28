import AppKit

class ScaleAspectFillImageView: NSImageView {
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        self.wantsLayer = true
        self.layer?.masksToBounds = true
    }
    
    override var image: NSImage? {
        didSet {
            updateImageLayer()
        }
    }
    
    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        updateImageLayer()
    }
    
    private func updateImageLayer() {
        guard let image = self.image else { return }
        
        // 创建图片图层
        let imageLayer = CALayer()
        imageLayer.contents = image
        imageLayer.contentsGravity = .resizeAspectFill
        imageLayer.frame = self.bounds
        imageLayer.cornerRadius = 5
        self.layer = imageLayer
    }
}
