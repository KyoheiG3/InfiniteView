//
//  IndexPath.swift
//  InfiniteView
//
//  Created by Kyohei Ito on 2015/12/17.
//  Copyright © 2015年 kyohei_ito. All rights reserved.
//

open class InfiniteIndexPath: NSIndexPath {
    public required init(forRow row: Int, item: Int, inSection section: Int) {
        let indexes = [section, item, row]
        super.init(indexes: indexes, length: indexes.count)
    }
    
    public convenience init(forItem item: Int, inSection section: Int) {
        self.init(forRow: 0, item: item, inSection: section)
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    open override var section: Int {
        return index(atPosition: 0)
    }
    open override var item: Int {
        return index(atPosition: 1)
    }
    open override var row: Int {
        return index(atPosition: 2)
    }
}
