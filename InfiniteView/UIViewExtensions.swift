//
//  UIViewExtensions.swift
//  InfiniteView
//
//  Created by Kyohei Ito on 2015/11/06.
//  Copyright © 2015年 kyohei_ito. All rights reserved.
//

import UIKit

extension UIView {
    var superKey: String { return "superView" }
    var viewKey: String { return "view" }
    var lastViewKey: String { return "lastView"}
    var spaceKey: String { return "space" }
    
    func constraintsWithFormat(_ format: String, metrics: [String : AnyObject]? = nil, views: [String : AnyObject]) -> [NSLayoutConstraint] {
        return NSLayoutConstraint.constraints(withVisualFormat: format, options: [], metrics: metrics, views: views)
    }
    
    func edgesSpaceConstraints(_ constant: CGFloat = 0) -> [NSLayoutConstraint] {
        return verticalSpaceConstraints(constant) + horizontalSpaceConstraints(constant)
    }
    
    func verticalSpaceConstraints(_ constant: CGFloat = 0) -> [NSLayoutConstraint] {
        return constraintsWithFormat("V:|-\(spaceKey)-[\(viewKey)]-\(spaceKey)-|", metrics: [spaceKey: constant as AnyObject], views: [viewKey: self])
    }
    
    func horizontalSpaceConstraints(_ constant: CGFloat = 0) -> [NSLayoutConstraint] {
        return constraintsWithFormat("|-\(spaceKey)-[\(viewKey)]-\(spaceKey)-|", metrics: [spaceKey: constant as AnyObject], views: [viewKey: self])
    }
    
    func topSpaceConstraints(_ constant: CGFloat = 0) -> [NSLayoutConstraint] {
        return constraintsWithFormat("V:|-\(spaceKey)-[\(viewKey)]", metrics: [spaceKey: constant as AnyObject], views: [viewKey: self])
    }
    
    func bottomSpaceConstraints(_ constant: CGFloat = 0) -> [NSLayoutConstraint] {
        return constraintsWithFormat("V:[\(viewKey)]-\(spaceKey)-|", metrics: [spaceKey: constant as AnyObject], views: [viewKey: self])
    }
    
    func leftSpaceConstraints(_ constant: CGFloat = 0) -> [NSLayoutConstraint] {
        return constraintsWithFormat("|-\(spaceKey)-[\(viewKey)]", metrics: [spaceKey: constant as AnyObject], views: [viewKey: self])
    }
    
    func rightSpaceConstraints(_ constant: CGFloat = 0) -> [NSLayoutConstraint] {
        return constraintsWithFormat("[\(viewKey)]-\(spaceKey)-|", metrics: [spaceKey: constant as AnyObject], views: [viewKey: self])
    }
    
    func betweenSpaceConstraints(_ lastView: UIView, constant: CGFloat = 0) -> [NSLayoutConstraint] {
        return constraintsWithFormat("[\(lastViewKey)]-\(spaceKey)-[\(viewKey)]", metrics: [spaceKey: constant as AnyObject], views: [viewKey: self, lastViewKey: lastView])
    }
    
    func widthConstraints(_ constant: CGFloat = 0, superview: UIView? = nil) -> [NSLayoutConstraint] {
        return [NSLayoutConstraint(item: self, attribute: .width, relatedBy: .equal, toItem: superview, attribute: .width, multiplier: 1, constant: constant)]
    }
    
    func heightConstraints(_ constant: CGFloat = 0) -> [NSLayoutConstraint] {
        guard let superview = superview else {
            fatalError("Since the super view does not exist could not be added to layout constraints.")
        }
        
        return constraintsWithFormat("V:|[\(viewKey)(==\(superKey))]|", views: [viewKey: self, superKey: superview])
    }
    
    func centerXConstraints(_ constant: CGFloat = 0) -> [NSLayoutConstraint] {
        return [NSLayoutConstraint(item: self, attribute: .centerX, relatedBy: .equal, toItem: superview, attribute: .centerX, multiplier: 1, constant: constant)]
    }
}

extension UIView {
    func addConstraints(_ group: ConstraintGroup) {
        addConstraints(group.allConstraints().collection)
    }
    
    func addConstraints(_ constraints: Constraints) {
        addConstraints(constraints.collection)
    }
    
    func removeConstraints(_ group: ConstraintGroup) {
        removeConstraints(group.allConstraints().collection)
    }
    
    func removeConstraints(_ constraints: Constraints) {
        removeConstraints(constraints.collection)
    }
}

extension UIView {
    class func performWithAnimation(_ actionsWithAnimation: () -> Void) {
        if UIView.areAnimationsEnabled == false {
            UIView.setAnimationsEnabled(true)
            actionsWithAnimation()
            UIView.setAnimationsEnabled(false)
        } else {
            actionsWithAnimation()
        }
    }
}

extension UIView {
    func replaceGestureRecognizers(_ gestureRecognizers: [UIGestureRecognizer]?) {
        self.gestureRecognizers?.forEach {
            self.removeGestureRecognizer($0)
        }
        
        gestureRecognizers?.forEach {
            self.addGestureRecognizer($0)
        }
        let a = Array([1])
        a.last
    }
}

extension BidirectionalCollection where Iterator.Element: UIView, Index == Int {
    func betweenSpaceConstraints(leftView lastView: Iterator.Element? = nil, rightView: Iterator.Element? = nil) -> [NSLayoutConstraint] {
        var leftView = lastView
        
        var constraints = reduce([]) { constraints, view -> [NSLayoutConstraint] in
            defer {
                leftView = view
            }
            
            if let leftView = leftView {
                return constraints + view.betweenSpaceConstraints(leftView)
            }
            
            return constraints
        }
        
        if let rightView = rightView {
            constraints.append(contentsOf: [rightView].betweenSpaceConstraints(leftView: last))
        }
        
        return constraints
    }
}
