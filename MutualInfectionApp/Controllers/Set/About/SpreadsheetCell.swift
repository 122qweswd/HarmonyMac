//
//  SpreadsheetCell.swift
//  MutualInfectionApp
//
//  Created by apple on 2025/9/9.
//

import UIKit

class SpreadsheetCell: UITableViewCell {
    
//    private var itemView: UIView!
    private var borderViewArray: [BorderViews?] = []
    private var labelArray: [UILabel?] = []
    private var labelContentViewArray: [UIView?] = []
    
    private lazy var mainStackView: UIStackView = {
       let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.alignment = .top
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        return stack
    }()
    
    private var viewModel: SpreadsheetItemViewModel!
    var row : Int = 0
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.selectionStyle = .none
        self.backgroundColor = .clear
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
    public func update(viewModel: SpreadsheetItemViewModel) {
        self.viewModel = viewModel
        if !mainStackView.isDescendant(of: self) {
            setupView()
        }
        
        applyViewModel()
        
        layoutIfNeeded()
    }
    
    func applyViewModel() {
        let lastIndex = viewModel.items.capacity - 1
        for (index, item) in viewModel.items.enumerated() {
            let tempLb = labelArray[index] ?? UILabel()

            let links = extractLinks(from: item)
//            self.row == 0
            if(links.count != 0){
                //let NSMutableAttributedString =
                setupPrivacyText(from: item, from: links, from: tempLb)
                
                //label.attributedText = NSMutableAttributedString;
            }else{
               
                tempLb.text = item
            }
            if(self.row == 0){
                tempLb.font = SFCompact(weight: .regular,size: 18)
                //UIFont.systemFont(ofSize: 18)
            }
//            // 添加点击手势
//            labelTapGesture = UITapGestureRecognizer(target: self, action: #selector(labelTapped(_:)))
//            label.addGestureRecognizer(labelTapGesture)
//            
//            
            
            labelArray[index]?.sizeToFit()
            hideUIViewBorder(withIsLastLine: viewModel.isLastLine,
                             isLastIndex: index == lastIndex,
                             bottomBorder: borderViewArray[index]?.bottomBorder ?? UIView(),
                             rightBorder: borderViewArray[index]?.rightBorder ?? UIView())
        }
    }
    
    func setupView() {
 
        self.contentView.addSubview(mainStackView)
        for item in viewModel.items {
            let label = buildLabel(with: item)
            let view = buildLabelView(with: label)
            let topBorder = view.addBorder(.top, color: .darkGray, thickness: 1)
            let bottomBorder = view.addBorder(.bottom, color: .darkGray, thickness: 1)
            let leftBorder = view.addBorder(.left, color: .darkGray, thickness: 1)
            let rightBorder = view.addBorder(.right, color: .darkGray, thickness: 1)
            mainStackView.addArrangedSubview(view)
            
            borderViewArray.append(BorderViews(topBorder: topBorder, bottomBorder: bottomBorder, leftBorder: leftBorder, rightBorder: rightBorder))
            labelArray.append(label)
            labelContentViewArray.append(view)
            
            NSLayoutConstraint.activate([
                view.topAnchor.constraint(equalTo: mainStackView.topAnchor),
                view.bottomAnchor.constraint(equalTo: mainStackView.bottomAnchor)
            ])
        }
        
        mainStackView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

    }
    
    private func hideUIViewBorder(
        withIsLastLine isLastLine: Bool,
        isLastIndex: Bool,
        bottomBorder: UIView,
        rightBorder: UIView) {
        bottomBorder.isHidden = !isLastLine
        rightBorder.isHidden = !isLastIndex
    }
    
    private func buildLabel(with text: String) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .left
        label.isUserInteractionEnabled = true
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = SFCompact(weight: .regular,size: 16)
        //UIFont.systemFont(ofSize: 16)
        
        
        return label
    }
    
    private func setupPrivacyText(from text: String,from links:[String],from label:UILabel) {
        let attributedString = NSMutableAttributedString(string: text)
        
        attributedString.addAttribute(.foregroundColor, value: UIColor.black, range: NSRange(location: 0, length: text.count))
        attributedString.addAttribute(.font, value: UIFont.systemFont(ofSize: 16), range: NSRange(location: 0, length: text.count))
        
        for link in links {
            if let range = text.range(of: link) {
                let nsRange = NSRange(range, in: text)
                attributedString.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: 16), range: nsRange)
                attributedString.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: nsRange)
                attributedString.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: nsRange)
            }
        }
        label.attributedText = attributedString
        label.isUserInteractionEnabled = true
        
        let labelTapGesture = UITapGestureRecognizer()
//        labelTapGesture.addTarget(self, action: #selector(methodTap))
        labelTapGesture.addTarget(self, action: #selector(methodTap(_:)))
        label.addGestureRecognizer(labelTapGesture)
       
      //  return attributedString
    }
    func extractLinks(from text: String) -> [String] {
        do {
            let detector = try NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
            let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
            
            return matches.compactMap { match in
                guard let url = match.url else { return nil }
                return url.absoluteString
            }
        } catch {
            print("Error creating data detector: \(error)")
            return []
        }
    }
    
    
    private func buildLabelView(with label: UILabel) -> UIView {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            label.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8)
        ])
        
        return view
    }
    @objc private func methodTap(_ gesture: UITapGestureRecognizer) {
          // 通过 gesture.view 获取被点击的 label
      
           guard let tappedLabel = gesture.view as? UILabel else { return }
        print(tappedLabel.text)
        
        let location = gesture.location(in: tappedLabel)
        let textContainer = NSTextContainer(size: tappedLabel.bounds.size)
        let layoutManager = NSLayoutManager()
        let textStorage = NSTextStorage(attributedString: tappedLabel.attributedText ?? NSAttributedString())
        
        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)
        
        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = tappedLabel.numberOfLines
        textContainer.lineBreakMode = tappedLabel.lineBreakMode
        
        let characterIndex = layoutManager.characterIndex(for: location, in: textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
        
        let linkTexts = extractLinks(from: tappedLabel.text ?? "")
        // 遍历所有链接文本
        for linkText in linkTexts {
            if let range = tappedLabel.text?.range(of: linkText) {
                let nsRange = NSRange(range, in: tappedLabel.text!)
                if NSLocationInRange(characterIndex, nsRange) {
                    print("linkText: \(linkText)")
                    let url = URL(string: linkText)
                    if UIApplication.shared.canOpenURL(url!) {
                        UIApplication.shared.open(url!) { success in
                            if success {
                                print("URL opened successfully.")
                            } else {
                                print("Failed to open URL.")
                            }
                        }
                    } else {
                        print("The URL scheme is not supported.")
                    }
                    
                }
            }
        }
        
    }

}
