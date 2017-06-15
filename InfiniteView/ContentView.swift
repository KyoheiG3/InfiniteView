//
//  ContentView.swift
//  InfiniteView
//
//  Created by Kyohei Ito on 2015/11/06.
//  Copyright © 2015年 kyohei_ito. All rights reserved.
//

import UIKit

class ContentView: UIView {
    var indexPath: InfiniteIndexPath?
    var borderColor: UIColor? {
        get {
            return borderView?.backgroundColor
        }
        set {
            if borderView == nil {
                let view = createBorderView()
                super.addSubview(view)
                borderView = view
            }
            borderView?.backgroundColor = newValue
        }
    }
    
    weak var borderView: UIView?
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        
        if superview != nil {
            superview?.addConstraints(widthConstraints(superview: superview))
            superview?.addConstraints(heightConstraints())
        }
    }
    
    weak var referenceContentViewForAround: ContentView?
    
    override func addSubview(_ view: UIView) {
        insertSubview(view, at: 0)
    }
    
    var scrollView: ContentScrollView? {
        return subviews.first as? ContentScrollView
    }
    
    func createBorderView() -> UIView {
        let width = 1 / UIScreen.main.scale
        let view = UIView(frame: CGRect(origin: .zero, size: CGSize(width: width, height: bounds.height)))
        view.autoresizingMask = [.flexibleHeight, .flexibleRightMargin]
        return view
    }
    
    func visible(_ rect: CGRect) -> Bool {
        return rect.intersects(frame)
    }
    
    func addContentScrollView(_ size: CGSize?) {
        let scrollView = ContentScrollView(frame: CGRect(origin: .zero, size: bounds.size))
        scrollView.contentSize.width = size?.width ?? bounds.width
        scrollView.isScrollEnabled = false
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        if let indexPath = indexPath ?? referenceContentViewForAround?.indexPath {
            scrollView.indexPath = indexPath
        }
        addSubview(scrollView)
    }
    
    func contentMoveFrom(_ contentView: ContentView?) {
        if let scrollView = contentView?.scrollView {
            removeContentScrollView()
            addSubview(scrollView)
        }
    }
    
    func removeContentScrollView() {
        while let view = subviews.last as? ContentScrollView {
            view.removeFromSuperview()
        }
    }
}

extension BidirectionalCollection where Iterator.Element: ContentView, Index == Int {
    func nearContentViewOfContentOffset(_ contentOffset: CGPoint, lastViewOffsetX offsetX: @autoclosure () -> CGFloat) -> ContentView? {
        guard let lastView = last else {
            return nil
        }
        
        var lastOriginX = lastView.frame.origin.x - offsetX()
        var targetView = lastView {
            didSet { lastOriginX = targetView.frame.origin.x }
        }
        
        for view in self {
            if contentOffset.x <= view.frame.origin.x {
                if contentOffset.x >= (lastOriginX + view.frame.origin.x) / 2 {
                    return view
                } else {
                    return targetView
                }
            } else {
                targetView = view
            }
        }
        
        return targetView
    }
}
