//
//  Constraints.swift
//  InfiniteView
//
//  Created by Kyohei Ito on 2015/11/05.
//  Copyright © 2015年 kyohei_ito. All rights reserved.
//

import UIKit

func + (lhs: Constraints, rhs: Constraints) -> Constraints {
    var constraints = Constraints()
    constraints.append(lhs)
    constraints.append(rhs)
    return constraints
}

protocol ConstraintGroup {
    func allConstraints() -> Constraints
}

struct Constraints {
    fileprivate(set) var collection: [NSLayoutConstraint] = []
    
    mutating func append(_ constraints: Constraints?) {
        if let constraints = constraints {
            collection.append(contentsOf: constraints.collection)
        }
    }
    
    mutating func append(_ constraints: [NSLayoutConstraint]?) {
        if let constraints = constraints {
            collection.append(contentsOf: constraints)
        }
    }
    
    mutating func replace(_ constraints: [NSLayoutConstraint]?) {
        if let constraints = constraints {
            collection = constraints
        }
    }
    
    mutating func removeAll() {
        collection.removeAll()
    }
    
    var constant: CGFloat {
        get {
            return collection.reduce(0) { $0.0 + $0.1.constant } / CGFloat(collection.count)
        }
        set(constant) {
            for constraint in collection {
                constraint.constant = constant
            }
        }
    }
}
