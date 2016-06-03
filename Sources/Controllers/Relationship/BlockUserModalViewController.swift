//
//  BlockUserModalViewController.swift
//  Ello
//
//  Created by Ryan Boyajian on 2/18/15.
//  Copyright (c) 2015 Ello. All rights reserved.
//

import Foundation


public class BlockUserModalViewController: BaseElloViewController {
    weak public var relationshipDelegate: RelationshipDelegate?

    public var backgroundButton = UIButton()
    public var modalView = UIView()
    public var closeButton = UIButton()

    public var titleLabel = UILabel()

    public var muteButton = WhiteElloButton()
    public var muteLabel = UILabel()

    public var blockButton = WhiteElloButton()
    public var blockLabel = UILabel()

    public var flagButton = WhiteElloButton()
    public var flagLabel = UILabel()

    public var relationshipPriority: RelationshipPriority {
        didSet { selectButton(relationshipPriority) }
    }

    let userId: String
    let userAtName: String

    let changeClosure: RelationshipChangeClosure

    public var titleText: String {
        switch relationshipPriority {
        case .Mute: return String(format: InterfaceString.Relationship.UnmuteAlertTemplate, userAtName)
        case .Block: return String(format: InterfaceString.Relationship.BlockAlertTemplate, userAtName)
        default: return String(format: InterfaceString.Relationship.MuteAlertTemplate, userAtName)
        }
    }

    public var muteText: String {
        return String(format: InterfaceString.Relationship.MuteWarningTemplate, userAtName, userAtName)
    }

    public var blockText: String {
        return String(format: InterfaceString.Relationship.BlockWarningTemplate, userAtName)
    }

    required public init(userId: String, userAtName: String, relationshipPriority: RelationshipPriority, changeClosure: RelationshipChangeClosure) {
        self.userId = userId
        self.userAtName = userAtName
        self.relationshipPriority = relationshipPriority
        self.changeClosure = changeClosure
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .Custom
        self.modalTransitionStyle = .CrossDissolve
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        styleView()
        setText()
        selectButton(relationshipPriority)
    }

    override public func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        if let superView = self.view.superview {
            self.view.center = superView.center
        }
    }

    func blockTapped(sender: UIButton) {
        Tracker.sharedTracker.userBlocked(userId)
        handleTapped(sender, newRelationship: RelationshipPriority.Block)
    }

    func muteTapped(sender: UIButton) {
        Tracker.sharedTracker.userMuted(userId)
        handleTapped(sender, newRelationship: RelationshipPriority.Mute)
    }

    func closeModal(sender: UIButton?) {
        Tracker.sharedTracker.userBlockCanceled(userId)
        self.dismissViewControllerAnimated(true, completion: nil)
    }

// MARK: Internal

    private func styleView() {
        backgroundButton.backgroundColor = UIColor.modalBackground()
        modalView.backgroundColor = UIColor.redColor()
        for label in [titleLabel, muteLabel, blockLabel] {
            styleLabel(label)
        }
        closeButton.setImages(.X, white: true)
    }

    private func styleLabel(label: UILabel) {
        label.font = .defaultFont()
        label.textColor = .whiteColor()
        label.lineBreakMode = .ByWordWrapping
        label.numberOfLines = 0
    }

    private func setText() {
        muteButton.setTitle(InterfaceString.Relationship.MuteButton, forState: UIControlState.Normal)
        blockButton.setTitle(InterfaceString.Relationship.BlockButton, forState: UIControlState.Normal)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 6
        var attrString: NSMutableAttributedString
        for (text, label) in [titleText: titleLabel, muteText: muteLabel, blockText: blockLabel] {
            attrString = NSMutableAttributedString(string: text)
            attrString.addAttribute(NSParagraphStyleAttributeName, value:paragraphStyle, range:NSMakeRange(0, attrString.length))
            label.attributedText = attrString
        }
    }

    private func handleTapped(sender: UIButton, newRelationship: RelationshipPriority) {
        guard let currentUserId = currentUser?.id else {
            closeModal(nil)
            return
        }

        let prevRelationship = relationshipPriority
        if sender.selected == true {
            relationshipPriority = .Inactive
        } else {
            relationshipPriority = newRelationship
        }

        relationshipDelegate?.updateRelationship(currentUserId, userId: userId, prev: prevRelationship, relationshipPriority: relationshipPriority) {
            (status, relationship, isFinalValue) in
            switch status {
            case .Success:
                self.changeClosure(relationshipPriority: self.relationshipPriority)
                self.closeModal(nil)
            case .Failure:
                self.relationshipPriority = prevRelationship
                self.changeClosure(relationshipPriority: prevRelationship)
            }
        }
    }

    private func resetButtons() {
        muteButton.selected = false
        blockButton.selected = false
    }

    private func selectButton(relationship: RelationshipPriority) {
        resetButtons()
        switch relationship {
        case .Mute:
            muteButton.selected = true
        case .Block:
            blockButton.selected = true
        default: resetButtons()
        }
    }

}
