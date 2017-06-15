//
//  CellReuseQueue.swift
//  InfiniteView
//
//  Created by Kyohei Ito on 2015/11/04.
//  Copyright © 2015年 kyohei_ito. All rights reserved.
//

struct CellReuseQueue {
    fileprivate var queue: [String: [InfiniteViewCell]] = [:]
    
    func dequeue(_ identifier: String) -> InfiniteViewCell? {
        return queue[identifier]?.filter { $0.superview == nil }.first
    }
    
    mutating func append(_ view: InfiniteViewCell, forQueueIdentifier identifier: String) {
        if queue[identifier] == nil {
            queue[identifier] = []
        }
        
        queue[identifier]?.append(view)
    }
    
    mutating func remove(_ identifier: String) {
        queue[identifier] = nil
    }
    
    func count(_ identifier: String) -> Int {
        return queue[identifier]?.count ?? 0
    }
}
