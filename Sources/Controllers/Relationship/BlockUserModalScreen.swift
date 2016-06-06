//
//  BlockUserModalScreen.swift
//  Ello
//
//  Created by Colin Gray on 6/6/2016.
//  Copyright (c) 2016 Ello. All rights reserved.
//

public protocol BlockUserModalDelegate {
    func updateRelationship(newRelationship: RelationshipPriority)
    func flagTapped()
    func closeModal()
}

public class BlockUserModalScreen: UIView {
    private let backgroundButton = UIButton()
    private let modalView = UIView()
    private let closeButton = UIButton()
    private let titleLabel = UILabel()
    private let muteButton = WhiteElloButton()
    private let muteLabel = UILabel()
    private let blockButton = WhiteElloButton()
    private let blockLabel = UILabel()
    private let flagButton = WhiteElloButton()
    private let flagLabel = UILabel()

    private var delegate: BlockUserModalDelegate? {
        get { return nextResponder() as? BlockUserModalDelegate }
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)

        self.addSubview(backgroundButton)
        self.addSubview(modalView)

        let modalViews: [UIView] = [closeButton, titleLabel, muteButton, muteLabel, blockButton, blockLabel, flagButton, flagLabel]
        for view in modalViews {
            modalView.addSubview(view)
        }

        styleView()
        setText()
        arrangeViews()
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func setDetails(userAtName userAtName: String, relationshipPriority: RelationshipPriority) {
        let titleText: String
        switch relationshipPriority {
        case .Mute: titleText = String(format: InterfaceString.Relationship.UnmuteAlertTemplate, userAtName)
        case .Block: titleText = String(format: InterfaceString.Relationship.BlockAlertTemplate, userAtName)
        default: titleText = String(format: InterfaceString.Relationship.MuteAlertTemplate, userAtName)
        }

        let muteText = String(format: InterfaceString.Relationship.MuteWarningTemplate, userAtName, userAtName)
        let blockText = String(format: InterfaceString.Relationship.BlockWarningTemplate, userAtName)
        let flagText = String(format: InterfaceString.Relationship.BlockWarningTemplate, userAtName)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 6
        let labels: [(UILabel, String)] = [(titleLabel, titleText), (muteLabel, muteText), (blockLabel, blockText), (flagLabel, flagText)]
        for (label, text) in labels {
            label.attributedText = NSAttributedString(string: text, attributes: [
                NSParagraphStyleAttributeName: paragraphStyle
            ])
        }

        resetButtons()
        switch relationshipPriority {
        case .Mute:
            muteButton.selected = true
        case .Block:
            blockButton.selected = true
        default:
            break
        }
    }

    private func resetButtons() {
        muteButton.selected = false
        blockButton.selected = false
    }

// MARK: STYLING

    private func styleView() {
        backgroundButton.backgroundColor = UIColor.modalBackground()
        backgroundButton.addTarget(self, action: #selector(closeModal), forControlEvents: .TouchUpInside)
        blockButton.addTarget(self, action: #selector(blockTapped(_:)), forControlEvents: .TouchUpInside)
        muteButton.addTarget(self, action: #selector(muteTapped(_:)), forControlEvents: .TouchUpInside)
        flagButton.addTarget(self, action: #selector(flagTapped), forControlEvents: .TouchUpInside)
        closeButton.addTarget(self, action: #selector(closeModal), forControlEvents: .TouchUpInside)
        modalView.backgroundColor = UIColor.redColor()
        for label in [titleLabel, muteLabel, blockLabel, flagLabel] {
            styleLabel(label)
        }
        for button in [muteButton, blockButton, flagButton] {
            styleButton(button)
        }
        closeButton.setImages(.X, white: true)
    }

    private func styleLabel(label: UILabel) {
        label.font = .defaultFont()
        label.textColor = .whiteColor()
        label.lineBreakMode = .ByWordWrapping
        label.numberOfLines = 0
    }

    private func styleButton(button: UIButton) {
        button.backgroundColor = .whiteColor()
        button.titleLabel?.font = .defaultFont()
        button.titleLabel?.textColor = .whiteColor()
    }

    private func setText() {
        muteButton.setTitle(InterfaceString.Relationship.MuteButton, forState: UIControlState.Normal)
        blockButton.setTitle(InterfaceString.Relationship.BlockButton, forState: UIControlState.Normal)
        flagButton.setTitle(InterfaceString.Relationship.FlagButton, forState: UIControlState.Normal)
    }

    private func arrangeViews() {
        backgroundButton.snp_makeConstraints { make in
            make.edges.equalTo(self)
        }

        modalView.snp_makeConstraints { make in
            make.left.equalTo(self).offset(10)
            make.right.equalTo(self).offset(-10)
            make.top.equalTo(self).offset(50)
            make.bottom.equalTo(flagLabel.snp_bottom).offset(20).priorityMedium()
            make.bottom.lessThanOrEqualTo(self.snp_bottom).priorityHigh()
        }

        closeButton.snp_makeConstraints { make in
            make.size.equalTo(CGSize(width: 30, height: 30))
            make.top.equalTo(modalView).offset(10)
            make.right.equalTo(modalView).offset(-10)
        }

        titleLabel.snp_makeConstraints { make in
            make.top.equalTo(modalView).offset(20)
            make.left.equalTo(modalView).offset(20)
            make.right.equalTo(closeButton.snp_left).offset(-10)
        }

        muteButton.snp_makeConstraints { make in
            make.top.equalTo(titleLabel.snp_bottom).offset(40)
            make.left.equalTo(modalView).offset(20)
            make.right.equalTo(modalView).offset(-20)
            make.height.equalTo(50)
        }

        muteLabel.snp_makeConstraints { make in
            make.top.equalTo(muteButton.snp_bottom).offset(20)
            make.left.equalTo(modalView).offset(20)
            make.right.equalTo(modalView).offset(-20)
        }

        blockButton.snp_makeConstraints { make in
            make.top.equalTo(muteLabel.snp_bottom).offset(40)
            make.left.equalTo(modalView).offset(20)
            make.right.equalTo(modalView).offset(-20)
            make.height.equalTo(50)
        }

        blockLabel.snp_makeConstraints { make in
            make.top.equalTo(blockButton.snp_bottom).offset(20)
            make.left.equalTo(modalView).offset(20)
            make.right.equalTo(modalView).offset(-20)
        }

        flagButton.snp_makeConstraints { make in
            make.top.equalTo(blockLabel.snp_bottom).offset(40)
            make.left.equalTo(modalView).offset(20)
            make.right.equalTo(modalView).offset(-20)
            make.height.equalTo(50)
        }

        flagLabel.snp_makeConstraints { make in
            make.top.equalTo(flagButton.snp_bottom).offset(20)
            make.left.equalTo(modalView).offset(20)
            make.right.equalTo(modalView).offset(-20)
        }
    }

// MARK: ACTIONS

    func blockTapped(sender: UIButton) {
        let relationshipPriority: RelationshipPriority
        if sender.selected == true {
            relationshipPriority = .Inactive
        } else {
            relationshipPriority = .Block
        }
        delegate?.updateRelationship(relationshipPriority)
    }

    func muteTapped(sender: UIButton) {
        let relationshipPriority: RelationshipPriority
        if sender.selected == true {
            relationshipPriority = .Inactive
        } else {
            relationshipPriority = .Mute
        }
        delegate?.updateRelationship(relationshipPriority)
    }

    func flagTapped() {
        delegate?.flagTapped()
    }

    func closeModal() {
        delegate?.closeModal()
    }

}
