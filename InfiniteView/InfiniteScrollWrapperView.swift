//
//  InfiniteScrollWrapperView.swift
//  InfiniteView
//
//  Created by Kyohei Ito on 2015/12/16.
//  Copyright © 2015年 kyohei_ito. All rights reserved.
//

import UIKit

class InfiniteScrollWrapperView: UIScrollView, ScrollInfinitable, Publisher {
    fileprivate var infiniteView: InfiniteView? {
        return superview?.superview as? InfiniteView
    }
    
    fileprivate var parentFrame: CGRect {
        return superview?.frame ?? frame
    }
    
    var observerCollection: [String: Observer] = [:]
    var infiniteOffset: CGPoint {
        return CGPoint(x: contentSize.width - bounds.width, y: 0)
    }
    
    var visibleContentOffset: CGPoint {
        if contentSize.width == 0 {
             return contentOffset
        } else {
            let offsetX = contentOffset.x + contentSize.width
            return CGPoint(x: offsetX.truncatingRemainder(dividingBy: contentSize.width), y: contentOffset.y)
        }
    }
    
    func contentOffsetOfInfinite(_ offset: CGPoint) -> CGPoint {
        guard let infiniteView = infiniteView else {
            return CGPoint(x: offset.x, y: offset.y)
        }
        
        func leftOffset() -> CGFloat {
            return offset.x + contentInset.left - parentFrame.origin.x
        }
        func rightOffset() -> CGFloat {
            return infiniteOffset.x + contentInset.right - (infiniteView.bounds.width - (bounds.width + parentFrame.origin.x))
        }
        
        func xOffset() -> CGFloat {
            if leftOffset() < 0 {
                return offset.x + contentSize.width
            } else if rightOffset() <= offset.x {
                return offset.x - contentSize.width
            } else {
                return offset.x
            }
        }
        
        return CGPoint(x: xOffset(), y: offset.y)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        infiniteIfNeeded()
    }
    
    func subscribeContentOffset(_ on: @escaping (CGPoint) -> Void) -> Disposable {
        return Observable(target: self, forKeyPath: "contentOffset") { object in
            if let contentOffset = (object as? NSValue)?.cgPointValue {
                on(contentOffset)
            }
        }
    }
}
