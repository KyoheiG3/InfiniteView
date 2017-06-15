//
//  InfiniteViewCell.swift
//  InfiniteView
//
//  Created by Kyohei Ito on 2015/11/04.
//  Copyright © 2015年 kyohei_ito. All rights reserved.
//

import UIKit

open class InfiniteViewCell: UIView {
    open internal(set) var indexPath = InfiniteIndexPath(forRow: 0, item: 0, inSection: 0)
    open internal(set) var reuseIdentifier: String?
    open var selected: Bool = false
    
    var displayed = false
    
    open func prepareForReuse() {
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    public required override init(frame: CGRect) {
        super.init(frame: frame)
    }
}
