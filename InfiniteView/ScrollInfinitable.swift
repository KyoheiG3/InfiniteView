//
//  ScrollInfinitable.swift
//  InfiniteView
//
//  Created by Kyohei Ito on 2015/12/02.
//  Copyright © 2015年 kyohei_ito. All rights reserved.
//

public protocol ScrollInfinitable {
    var infiniteOffset: CGPoint { get }
    
    func infiniteIfNeeded()
    func contentOffsetOfInfinite(_ offset: CGPoint) -> CGPoint
}

public extension ScrollInfinitable where Self: UIScrollView {
    var infiniteOffset: CGPoint {
        return CGPoint(x: contentSize.width - bounds.width + contentInset.right, y: contentSize.height - bounds.height + contentInset.bottom)
    }
    
    func infiniteIfNeeded() {
        let offset = contentOffsetOfInfinite(contentOffset)
        if contentOffset != offset {
            contentOffset = offset
        }
    }
    
    func contentOffsetOfInfinite(_ offset: CGPoint) -> CGPoint {
        let infiniteOffset = self.infiniteOffset
        
        func xOffset() -> CGFloat {
            if offset.x + contentInset.left < 0 {
                return offset.x + infiniteOffset.x
            } else if infiniteOffset.x <= offset.x {
                return offset.x - infiniteOffset.x
            } else {
                return offset.x
            }
        }
        
        func yOffset() -> CGFloat {
            if offset.y + contentInset.top < 0 {
                return offset.y + infiniteOffset.y
            } else if infiniteOffset.y <= offset.y {
                return offset.y - infiniteOffset.y
            } else {
                return offset.y
            }
        }
        
        return CGPoint(x: xOffset(), y: yOffset())
    }
}

