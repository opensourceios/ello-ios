//
//  BlockUserModalViewController.swift
//  Ello
//
//  Created by Ryan Boyajian on 2/18/15.
//  Copyright (c) 2015 Ello. All rights reserved.
//

import Foundation
import SnapKit


public class BlockUserModalViewController: BaseElloViewController, BlockUserModalDelegate {
    weak public var relationshipDelegate: RelationshipDelegate?

    let relationshipPriority: RelationshipPriority
    let userId: String
    let userAtName: String

    let changeClosure: RelationshipChangeClosure
    var screen: BlockUserModalScreen!

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

    override public func loadView() {
        let screen = BlockUserModalScreen()
        self.screen = screen
        self.view = screen

        screen.setDetails(
            userAtName: userAtName,
            relationshipPriority: relationshipPriority
            )
    }

    override public func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        if let superView = self.view.superview {
            self.view.center = superView.center
        }
    }

    public func updateRelationship(newRelationship: RelationshipPriority) {
        guard let currentUserId = currentUser?.id else {
            closeModal()
            return
        }

        switch newRelationship {
            case .Block: Tracker.sharedTracker.userBlocked(userId)
            case .Mute: Tracker.sharedTracker.userMuted(userId)
            case .Inactive:
                if relationshipPriority == .Block {
                    Tracker.sharedTracker.userUnblocked(userId)
                }
                else if relationshipPriority == .Mute {
                    Tracker.sharedTracker.userUnmuted(userId)
                }
            default: break
        }

        relationshipDelegate?.updateRelationship(currentUserId, userId: userId, prev: relationshipPriority, relationshipPriority: newRelationship) {
            (status, relationship, isFinalValue) in
            switch status {
            case .Success:
                self.changeClosure(relationshipPriority: newRelationship)
                self.closeModal()
            case .Failure:
                self.changeClosure(relationshipPriority: self.relationshipPriority)
            }
        }
    }

    public func flagTapped() {
        if let presentingViewController = presentingViewController {
            let flagger = ContentFlagger(
                presentingController: presentingViewController,
                flaggableId: userId,
                contentType: .User
            )

            closeModal() {
                flagger.displayFlaggingSheet()
            }
        }
    }

    public func closeModal() {
        closeModal {}
    }

    public func closeModal(completion: BasicBlock) {
        Tracker.sharedTracker.userBlockCanceled(userId)
        self.dismissViewControllerAnimated(true, completion: completion)
    }

}
