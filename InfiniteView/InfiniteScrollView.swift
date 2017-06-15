//
//  InfiniteScrollView.swift
//  InfiniteView
//
//  Created by Kyohei Ito on 2015/11/05.
//  Copyright © 2015年 kyohei_ito. All rights reserved.
//

import UIKit

class InfiniteScrollView: UIScrollView {
    fileprivate(set) lazy var dataSource: ContentsDataSource = ContentsDataSource(scrollView: self)
    fileprivate var animatedBounds: CGRect?
    fileprivate var parentFrame: CGRect {
        return superview?.frame ?? frame
    }
    
    var needsReload: Bool = true
    var needsLayout: Bool = false
    var reusable: Bool = true
    var separatorColor: UIColor?
    var disposable: Disposable?
    
    var infiniteView: InfiniteView? {
        return superview?.superview as? InfiniteView
    }
    
    var visibleRect: CGRect? {
        guard let infiniteView = infiniteView else {
            return nil
        }
        
        let origin = CGPoint(x: contentOffset.x - parentFrame.origin.x, y: contentOffset.y - parentFrame.origin.y)
        return CGRect(origin: origin, size: infiniteView.bounds.size)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        #if (iOS)
            scrollsToTop = false
        #endif
        clipsToBounds = false
        showsHorizontalScrollIndicator = false
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        #if (iOS)
            scrollsToTop = false
        #endif
        clipsToBounds = false
        showsHorizontalScrollIndicator = false
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if let rect = visibleRect {
            return rect.contains(point)
        }
        return super.point(inside: point, with: event)
    }
    
    override func insertSubview(_ view: UIView, aboveSubview siblingSubview: UIView?) {
        view.translatesAutoresizingMaskIntoConstraints = false
        if let lastView = siblingSubview {
            super.insertSubview(view, aboveSubview: lastView)
        } else {
            insertSubview(view, at: 0)
        }
    }
    
    func startObserveContentOffset() {
        disposable = infiniteView?.wrapperView.subscribeContentOffset { [unowned self] contentOffset in
            let offset = CGPoint(x: contentOffset.x + self.leftAroundWidth, y: 0)
            self.setContentOffset(offset, animated: false)
            if self.needsReload == false {
                self.layoutIfNeeded()
            }
        }
    }
}

// MARK: - Contents
extension InfiniteScrollView {
    func contentViewAtIndexPath(_ indexPath: InfiniteIndexPath, absolute: Bool) -> ContentView? {
        if absolute {
            return dataSource.allContents().filter { $0.scrollView?.indexPath == indexPath }.first
        } else {
            let views = dataSource.allContents().filter {
                $0.indexPath == indexPath || $0.referenceContentViewForAround?.indexPath == indexPath
            }
            
            return views.nearContentViewOfContentOffset(contentOffset, lastViewOffsetX: contentSize.width - bounds.width)
        }
    }
}

// MARK: - Aroundable
extension InfiniteScrollView {
    fileprivate var visibleContentSize: CGSize {
        return CGSize(width: contentSize.width - combinedAroundWidth, height: contentSize.height)
    }
    
    var leftAroundWidth: CGFloat {
        return bounds.width * CGFloat(dataSource.leftContents.count)
    }
    
    var rightAroundWidth: CGFloat {
        return bounds.width * CGFloat(dataSource.rightContents.count)
    }
    
    var combinedAroundWidth: CGFloat {
        return leftAroundWidth + rightAroundWidth
    }
    
    func necessaryCountOfAround() -> Int {
        guard let infiniteView = infiniteView else {
            return 0
        }
        
        var ratio = (infiniteView.bounds.width - bounds.width) / bounds.width
        if ratio.truncatingRemainder(dividingBy: 1) == 0 { ratio += 1 }
        return Int(ceil(ratio))
    }
}

// MARK: - Layout
extension InfiniteScrollView {
    override func layoutSubviews() {
        if needsReload {
            dataSource.reloadAllData(bounds, necessaryAroundCount: necessaryCountOfAround())
            addConstraints(dataSource.constraint.main)
            infiniteView?.wrapperView.contentSize.height = contentSize.height
        }
        
        defer {
            needsLayout = false
            needsReload = false
        }
        
        guard let infiniteView = infiniteView , dataSource.mainContents.count > 0 else {
            return super.layoutSubviews()
        }
        
        var leftAddCount = 0
        var rightAddCount = 0
        if let layer = layer.presentation(), dataSource.infinite && bounds.size != layer.bounds.size {
            let necessaryCount = necessaryCountOfAround()
            // add around contents if needed
            leftAddCount = dataSource.addLeftContents(necessaryCount, bounds: layer.bounds)
            rightAddCount = dataSource.addRightContents(necessaryCount, bounds: layer.bounds)
            
            if leftAddCount > 0 || rightAddCount > 0 {
                dataSource.replaceAroundConstraints()
            }
        }
        
        let beforeContentSize = contentSize
        let beforeContentOffset = contentOffset
        super.layoutSubviews()
        
        // content size has changed
        contentSize.height = beforeContentSize.height
        if beforeContentSize.width != contentSize.width {
            infiniteView.wrapperView.contentSize.width = visibleContentSize.width
            infiniteView.wrapperView.contentInset.left = leftAroundWidth
            infiniteView.wrapperView.contentInset.right = rightAroundWidth
            
            var offset = CGPoint.zero
            if needsReload == false && beforeContentSize.width > 0, let presentationLayer = layer.presentation() {
                // centering
                let ratio = (contentSize.width - bounds.width * CGFloat(max(leftAddCount + rightAddCount, 0))) / (beforeContentSize.width)
                offset = CGPoint(x: (beforeContentOffset.x + presentationLayer.bounds.width * CGFloat(max(leftAddCount, 0))) * ratio - leftAroundWidth, y: infiniteView.wrapperView.contentOffset.y)
            }
            
            infiniteView.wrapperView.setContentOffset(offset, animated: false)
            contentOffset.x = offset.x + leftAroundWidth
        }
        
        if dataSource.infinite {
            infiniteIfNeeded(contentsForceMove: animatedBounds != nil)
        }
        
        if let rect = visibleRect {
            moveDisplayCell(dataSource.leftContents, rect: rect)
            moveDisplayCell(dataSource.rightContents, rect: rect)
            changeDisplayStatusForCell(rect)
        }
    }
    
    func configureView(_ contentView: ContentView, all: Bool = true) {
        guard let infiniteView = infiniteView, let indexPath = contentView.indexPath ?? contentView.referenceContentViewForAround?.indexPath else {
            return
        }
        
        if let rowIndexPaths = dataSource.indexPathsInItem[indexPath], let cellRects = dataSource.rectForRowsInItem[indexPath] {
            contentView.removeContentScrollView()
            contentView.addContentScrollView(layer.presentation()?.bounds.size)
            
            contentView.scrollView?.refInfiniteView = infiniteView
            contentView.scrollView?.cellRects = cellRects
            contentView.scrollView?.cellIndexPaths = rowIndexPaths
            contentView.scrollView?.startObserveContentOffset()
            
            UIView.performWithoutAnimation {
                contentView.scrollView?.contentSize.height = self.contentSize.height
                contentView.scrollView?.contentOffset.y = infiniteView.wrapperView.contentOffset.y
                contentView.scrollView?.configureCells(all)
            }
        }
    }
    
    func configureContentViewAtIndexPath(_ indexPath: InfiniteIndexPath) -> ContentView {
        let contentView = ContentView(frame: bounds)
        contentView.indexPath = indexPath
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.borderColor = separatorColor
        addSubview(contentView)
        
        if reusable == false {
            // all configuration for cell
            configureView(contentView)
        }
        
        return contentView
    }
    
    func forceMoveContents(_ contents: [ContentView], reverse: Bool = false) {
        contents.forEach { view in
            moveContentIfNeeded(view, reverse: reverse)
        }
    }
    
    func moveContentIfNeeded(_ view: ContentView, reverse: Bool = false) {
        if reverse {
            if view.referenceContentViewForAround?.scrollView == nil {
                view.referenceContentViewForAround?.contentMoveFrom(view)
            }
        } else if view.scrollView == nil {
            view.contentMoveFrom(view.referenceContentViewForAround)
        }
    }
    
    func moveDisplayCell(_ contents: [ContentView], rect: CGRect) {
        contents.forEach { view in
            if view.visible(rect) {
                moveContentIfNeeded(view)
            }
            
            if view.referenceContentViewForAround?.visible(rect) == true {
                moveContentIfNeeded(view, reverse: true)
            }
        }
    }
    
    func changeDisplayStatusForCell(_ rect: CGRect) {
        func endDisplayIfNeeded(_ view: ContentView, visible: Bool) {
            if view.scrollView?.displayed == true && visible == false {
                didEndDisplayingView(view)
                
                if reusable {
                    view.removeContentScrollView()
                }
            }
        }
        
        func willDisplayIfNeeded(_ view: ContentView, visible: Bool) {
            if (view.scrollView == nil || view.scrollView?.displayed == false) && visible == true {
                if reusable && view.scrollView == nil {
                    configureView(view, all: false)
                }
                
                willDisplayView(view)
            }
        }
        
        subviews.forEach { subview in
            if let view = subview as? ContentView {
                endDisplayIfNeeded(view, visible: view.visible(rect))
            }
        }
        
        subviews.forEach { subview in
            if let view = subview as? ContentView {
                willDisplayIfNeeded(view, visible: view.visible(rect))
            }
        }
    }
    
    func willDisplayView(_ contentView: ContentView) {
        contentView.scrollView?.willDisplayCells()
        contentView.scrollView?.displayed = true
    }
    
    func didEndDisplayingView(_ contentView: ContentView) {
        contentView.scrollView?.displayed = false
        contentView.scrollView?.didEndDisplayingCells()
    }
}

// MARK: - Layer action
extension InfiniteScrollView {
    override func action(for layer: CALayer, forKey event: String) -> CAAction? {
        let action = super.action(for: layer, forKey: event)
        
        if event == "bounds" && needsReload == false && needsLayout == false {
            if action is NSNull {
                animatedBounds = nil
            } else {
                animatedBounds = layer.presentation()?.bounds
            }
        }
        
        return action
    }
}

// MARK: - ScrollInfinitable
extension InfiniteScrollView: ScrollInfinitable {
    func infiniteIfNeeded(contentsForceMove forceMove: Bool = false) {
        let offset = contentOffsetOfInfinite(contentOffset)
        if contentOffset != offset {
            if forceMove {
                if contentOffset.x < offset.x {
                    forceMoveContents(dataSource.rightContents)
                    forceMoveContents(dataSource.leftContents, reverse: true)
                } else {
                    forceMoveContents(dataSource.leftContents)
                    forceMoveContents(dataSource.rightContents, reverse: true)
                }
            }
        }
    }
    
    func contentOffsetOfInfinite(_ offset: CGPoint) -> CGPoint {
        guard let infiniteView = infiniteView else {
            return CGPoint(x: offset.x, y: offset.y)
        }
        
        var rightOffsetMargin: CGFloat {
            return combinedAroundWidth - infiniteView.bounds.width + parentFrame.origin.x
        }
        
        func xOffset() -> CGFloat {
            let infiniteOffset = CGPoint(x: visibleContentSize.width, y: 0)
            if offset.x - parentFrame.origin.x < 0 {
                return offset.x + infiniteOffset.x
            } else if infiniteOffset.x + rightOffsetMargin <= offset.x {
                return offset.x - infiniteOffset.x
            } else {
                return offset.x
            }
        }
        
        return CGPoint(x: xOffset(), y: offset.y)
    }
}

// MARK: - Visibility
extension InfiniteScrollView {
    func visibleContents() -> [UIView] {
        guard let rect = visibleRect else {
            return []
        }
        
        return dataSource.allContents().filter {
            rect.intersects($0.frame)
        }
    }
    
    func visibleContents<T>() -> [T] {
        return visibleContents().filter { $0 is T }.map { $0 as! T }
    }
    
    func visibleCenterContent() -> ContentView? {
        let point = CGPoint(x: contentOffset.x + center.x, y: center.y)
        return dataSource.allContents().filter {
            $0.frame.contains(point)
        }.first
    }
    
    func visibleCenterContent<T>() -> T? {
        return visibleCenterContent() as? T
    }
}
