//
//  PostbarController.swift
//  Ello
//
//  Created by Sean on 1/23/15.
//  Copyright (c) 2015 Ello. All rights reserved.
//

import Foundation

public protocol PostbarDelegate: NSObjectProtocol {
    func viewsButtonTapped(indexPath: NSIndexPath)
    func commentsButtonTapped(cell: StreamFooterCell, imageLabelControl: ImageLabelControl)
    func deleteCommentButtonTapped(indexPath: NSIndexPath)
    func editCommentButtonTapped(indexPath: NSIndexPath)
    func lovesButtonTapped(cell: StreamFooterCell?, indexPath: NSIndexPath)
    func repostButtonTapped(indexPath: NSIndexPath)
    func shareButtonTapped(indexPath: NSIndexPath, sourceView: UIView)
    func flagCommentButtonTapped(indexPath: NSIndexPath)
    func replyToCommentButtonTapped(indexPath: NSIndexPath)
    func replyToAllButtonTapped(indexPath: NSIndexPath)
}

public class PostbarController: NSObject, PostbarDelegate {

    weak var presentingController: StreamViewController?
    public var collectionView: UICollectionView
    public let dataSource: StreamDataSource
    public var currentUser: User?

    // on the post detail screen, the comments don't show/hide
    var toggleableComments: Bool = true

    public init(collectionView: UICollectionView, dataSource: StreamDataSource, presentingController: StreamViewController) {
        self.collectionView = collectionView
        self.dataSource = dataSource
        self.collectionView.dataSource = dataSource
        self.presentingController = presentingController
    }

    // MARK:

    public func viewsButtonTapped(indexPath: NSIndexPath) {
        if let post = postForIndexPath(indexPath) {
            Tracker.sharedTracker.viewsButtonTapped(post: post)
            // This is a bit dirty, we should not call a method on a compositionally held
            // controller's postTappedDelegate. Need to chat about this with the crew.
            presentingController?.postTappedDelegate?.postTapped(post)
        }
    }

    public func commentsButtonTapped(cell: StreamFooterCell, imageLabelControl: ImageLabelControl) {
        guard !dataSource.streamKind.isGridView else {
            cell.cancelCommentLoading()
            if let indexPath = collectionView.indexPathForCell(cell) {
                self.viewsButtonTapped(indexPath)
            }
            return
        }

        guard !dataSource.streamKind.isDetail else {
            return
        }

        guard toggleableComments else {
            cell.cancelCommentLoading()
            return
        }

        if  let indexPath = collectionView.indexPathForCell(cell),
            let item = dataSource.visibleStreamCellItem(at: indexPath),
            let post = item.jsonable as? Post
        {
            imageLabelControl.selected = cell.commentsOpened
            cell.commentsControl.enabled = false

            if !cell.commentsOpened {
                let indexPaths = self.dataSource.removeCommentsForPost(post)
                self.collectionView.deleteItemsAtIndexPaths(indexPaths)
                item.state = .Collapsed
                imageLabelControl.enabled = true
                imageLabelControl.finishAnimation()
                imageLabelControl.highlighted = false
            }
            else {
                item.state = .Loading
                imageLabelControl.highlighted = true
                imageLabelControl.animate()
                let streamService = StreamService()
                streamService.loadMoreCommentsForPost(
                    post.id,
                    streamKind: dataSource.streamKind,
                    success: { (comments, responseConfig) in
                        if let updatedIndexPath = self.dataSource.indexPathForItem(item) {
                            item.state = .Expanded
                            imageLabelControl.finishAnimation()
                            let nextIndexPath = NSIndexPath(forItem: updatedIndexPath.row + 1, inSection: updatedIndexPath.section)
                            self.commentLoadSuccess(post, comments: comments, indexPath: nextIndexPath, cell: cell)
                        }
                    },
                    failure: { _ in
                        item.state = .Collapsed
                        imageLabelControl.finishAnimation()
                        cell.cancelCommentLoading()
                        print("comment load failure")
                    },
                    noContent: {
                        item.state = .Expanded
                        imageLabelControl.finishAnimation()
                        if let updatedIndexPath = self.dataSource.indexPathForItem(item) {
                            let nextIndexPath = NSIndexPath(forItem: updatedIndexPath.row + 1, inSection: updatedIndexPath.section)
                            self.commentLoadSuccess(post, comments: [], indexPath: nextIndexPath, cell: cell)
                        }
                    })
            }
        }
        else {
            cell.cancelCommentLoading()
        }
    }

    public func deleteCommentButtonTapped(indexPath: NSIndexPath) {
        let message = InterfaceString.Post.DeleteCommentConfirm
        let alertController = AlertViewController(message: message)

        let yesAction = AlertAction(title: InterfaceString.Yes, style: .Dark) {
            action in
            if let comment = self.commentForIndexPath(indexPath) {
                // comment deleted
                postNotification(CommentChangedNotification, value: (comment, .Delete))
                // post comment count updated
                ContentChange.updateCommentCount(comment, delta: -1)
                PostService().deleteComment(comment.postId, commentId: comment.id,
                    success: nil,
                    failure: { (error, statusCode)  in
                        // TODO: add error handling
                        print("failed to delete comment, error: \(error.elloErrorMessage ?? error.localizedDescription)")
                    })
            }
        }
        let noAction = AlertAction(title: InterfaceString.No, style: .Light, handler: .None)

        alertController.addAction(yesAction)
        alertController.addAction(noAction)

        logPresentingAlert(presentingController?.readableClassName() ?? "PostbarController")
        presentingController?.presentViewController(alertController, animated: true, completion: .None)
    }

    public func editCommentButtonTapped(indexPath: NSIndexPath) {
        // This is a bit dirty, we should not call a method on a compositionally held
        // controller's createPostDelegate. Can this use the responder chain when we have
        // parameters to pass?
        if let comment = self.commentForIndexPath(indexPath),
            let presentingController = presentingController
        {
            presentingController.createPostDelegate?.editComment(comment, fromController: presentingController)
        }
    }

    public func lovesButtonTapped(cell: StreamFooterCell?, indexPath: NSIndexPath) {
        if let post = self.postForIndexPath(indexPath) {
            Tracker.sharedTracker.postLoved(post)
            cell?.lovesControl.userInteractionEnabled = false
            if post.loved { unlovePost(post, cell: cell) }
            else { lovePost(post, cell: cell) }
        }
    }

    private func unlovePost(post: Post, cell: StreamFooterCell?) {
        Tracker.sharedTracker.postUnloved(post)
        if let count = post.lovesCount {
            post.lovesCount = count - 1
            post.loved = false
            postNotification(PostChangedNotification, value: (post, .Loved))
        }
        if let user = currentUser, let userLoveCount = user.lovesCount {
            user.lovesCount = userLoveCount - 1
            postNotification(CurrentUserChangedNotification, value: user)
        }
        let service = LovesService()
        service.unlovePost(
            postId: post.id,
            success: {
                cell?.lovesControl.userInteractionEnabled = true
            },
            failure: { error, statusCode in
                cell?.lovesControl.userInteractionEnabled = true
                print("failed to unlove post \(post.id), error: \(error.elloErrorMessage ?? error.localizedDescription)")
            })
    }

    private func lovePost(post: Post, cell: StreamFooterCell?) {
        Tracker.sharedTracker.postLoved(post)
        if let count = post.lovesCount {
            post.lovesCount = count + 1
            post.loved = true
            postNotification(PostChangedNotification, value: (post, .Loved))
        }
        if let user = currentUser, let userLoveCount = user.lovesCount {
            user.lovesCount = userLoveCount + 1
            postNotification(CurrentUserChangedNotification, value: user)
        }
        LovesService().lovePost(
            postId: post.id,
            success: { (love, responseConfig) in
                postNotification(LoveChangedNotification, value: (love, .Create))
                cell?.lovesControl.userInteractionEnabled = true
            },
            failure: { error, statusCode in
                cell?.lovesControl.userInteractionEnabled = true
                print("failed to love post \(post.id), error: \(error.elloErrorMessage ?? error.localizedDescription)")
            })
    }

    public func repostButtonTapped(indexPath: NSIndexPath) {
        if let post = self.postForIndexPath(indexPath) {
            Tracker.sharedTracker.postReposted(post)
            let message = InterfaceString.Post.RepostConfirm
            let alertController = AlertViewController(message: message)
            alertController.autoDismiss = false

            let yesAction = AlertAction(title: InterfaceString.Yes, style: .Dark) { action in
                self.createRepost(post, alertController: alertController)
            }
            let noAction = AlertAction(title: InterfaceString.No, style: .Light) { action in
                alertController.dismiss()
            }

            alertController.addAction(yesAction)
            alertController.addAction(noAction)

            logPresentingAlert(presentingController?.readableClassName() ?? "PostbarController")
            presentingController?.presentViewController(alertController, animated: true, completion: .None)
        }
    }

    private func createRepost(post: Post, alertController: AlertViewController)
    {
        alertController.resetActions()
        alertController.dismissable = false

        let spinnerContainer = UIView(frame: CGRect(x: 0, y: 0, width: alertController.view.frame.size.width, height: 200))
        let spinner = ElloLogoView(frame: CGRect(origin: CGPointZero, size: ElloLogoView.Size.Natural))
        spinner.center = spinnerContainer.bounds.center
        spinnerContainer.addSubview(spinner)
        alertController.contentView = spinnerContainer
        spinner.animateLogo()
        if let user = currentUser, let userPostsCount = user.postsCount {
            user.postsCount = userPostsCount + 1
            postNotification(CurrentUserChangedNotification, value: user)
        }
        RePostService().repost(post: post,
            success: { repost in
                postNotification(PostChangedNotification, value: (repost, .Create))
                alertController.contentView = nil
                alertController.message = InterfaceString.Post.RepostSuccess
                delay(1) {
                    alertController.dismiss()
                }
            }, failure: { (error, statusCode)  in
                alertController.contentView = nil
                alertController.message = InterfaceString.Post.RepostError
                alertController.autoDismiss = true
                alertController.dismissable = true
                let okAction = AlertAction(title: InterfaceString.OK, style: .Light, handler: .None)
                alertController.addAction(okAction)
            })
    }

    public func shareButtonTapped(indexPath: NSIndexPath, sourceView: UIView) {
        if  let post = dataSource.postForIndexPath(indexPath),
            let shareLink = post.shareLink,
            let shareURL = NSURL(string: shareLink)
        {
            Tracker.sharedTracker.postShared(post)
            let activityVC = UIActivityViewController(activityItems: [shareURL], applicationActivities: [SafariActivity()])
            if UI_USER_INTERFACE_IDIOM() == .Phone {
                activityVC.modalPresentationStyle = .FullScreen
                logPresentingAlert(presentingController?.readableClassName() ?? "PostbarController")
                presentingController?.presentViewController(activityVC, animated: true) { }
            }
            else {
                activityVC.modalPresentationStyle = .Popover
                activityVC.popoverPresentationController?.sourceView = sourceView
                logPresentingAlert(presentingController?.readableClassName() ?? "PostbarController")
                presentingController?.presentViewController(activityVC, animated: true) { }
            }
        }
    }

    public func flagCommentButtonTapped(indexPath: NSIndexPath) {
        if let comment = commentForIndexPath(indexPath), presentingController = presentingController {
            let flagger = ContentFlagger(
                presentingController: presentingController,
                flaggableId: comment.id,
                contentType: .Comment,
                commentPostId: comment.postId
            )

            flagger.displayFlaggingSheet()
        }
    }

    public func replyToCommentButtonTapped(indexPath: NSIndexPath) {
        if let comment = commentForIndexPath(indexPath) {
            // This is a bit dirty, we should not call a method on a compositionally held
            // controller's createPostDelegate. Can this use the responder chain when we have
            // parameters to pass?
            if let presentingController = presentingController,
                let post = comment.loadedFromPost,
                let atName = comment.author?.atName
            {
                presentingController.createPostDelegate?.createComment(post, text: "\(atName) ", fromController: presentingController)
            }
        }
    }

    public func replyToAllButtonTapped(indexPath: NSIndexPath) {
        // This is a bit dirty, we should not call a method on a compositionally held
        // controller's createPostDelegate. Can this use the responder chain when we have
        // parameters to pass?
        if let comment = commentForIndexPath(indexPath),
            presentingController = presentingController,
            post = comment.loadedFromPost
        {
            PostService().loadReplyAll(post.id, success: { usernames in
                let usernamesText = usernames.reduce("") { memo, username in
                    return memo + "@\(username) "
                }
                presentingController.createPostDelegate?.createComment(post, text: usernamesText, fromController: presentingController)
            }, failure: {
                presentingController.createCommentTapped(post)
            })
        }
    }

// MARK: - Private

    private func postForIndexPath(indexPath: NSIndexPath) -> Post? {
        return dataSource.postForIndexPath(indexPath)
    }

    private func commentForIndexPath(indexPath: NSIndexPath) -> ElloComment? {
        return dataSource.commentForIndexPath(indexPath)
    }

    private func commentLoadSuccess(post: Post, comments jsonables: [JSONAble], indexPath: NSIndexPath, cell: StreamFooterCell) {
        self.appendCreateCommentItem(post, at: indexPath)
        let commentsStartingIndexPath = NSIndexPath(forRow: indexPath.row + 1, inSection: indexPath.section)

        var items = StreamCellItemParser().parse(jsonables, streamKind: StreamKind.Following, currentUser: currentUser)

        if let currentUser = currentUser {
            let newComment = ElloComment.newCommentForPost(post, currentUser: currentUser)
            if post.commentsCount > ElloAPI.PostComments(postId: "").parameters!["per_page"] as? Int {
                items.append(StreamCellItem(jsonable: jsonables.last ?? newComment, type: .SeeMoreComments))
            }
            else {
                items.append(StreamCellItem(jsonable: newComment, type: .Spacer(height: 10.0)))
            }
        }

        self.dataSource.insertUnsizedCellItems(items,
            withWidth: self.collectionView.frame.width,
            startingIndexPath: commentsStartingIndexPath) { (indexPaths) in
                self.collectionView.insertItemsAtIndexPaths(indexPaths)
                cell.commentsControl.enabled = true

                if indexPaths.count == 1 && jsonables.count == 0 {
                    self.presentingController?.createCommentTapped(post)
                }
            }
    }

    private func appendCreateCommentItem(post: Post, at indexPath: NSIndexPath) {
        if let currentUser = currentUser {
            let comment = ElloComment.newCommentForPost(post, currentUser: currentUser)
            let createCommentItem = StreamCellItem(jsonable: comment, type: .CreateComment)

            let items = [createCommentItem]
            self.dataSource.insertStreamCellItems(items, startingIndexPath: indexPath)
            self.collectionView.insertItemsAtIndexPaths([indexPath])
        }
    }

    private func commentLoadFailure(error: NSError, statusCode: Int?) {
    }

}
