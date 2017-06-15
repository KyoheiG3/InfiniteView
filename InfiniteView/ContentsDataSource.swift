//
//  ContentsDataSource.swift
//  InfiniteView
//
//  Created by Kyohei Ito on 2015/12/11.
//  Copyright © 2015年 kyohei_ito. All rights reserved.
//

import UIKit

class ContentsConstraint {
    struct Group: ConstraintGroup {
        var leftSpaces: Constraints = Constraints()
        var rightSpaces: Constraints = Constraints()
        var betweenSpaces: Constraints = Constraints()
        
        func allConstraints() -> Constraints {
            return betweenSpaces + leftSpaces + rightSpaces
        }
    }
    
    var main: Group = Group()
    var around: Group = Group()
    
    func removeAll() {
        main = Group()
        around = Group()
    }
}

class ContentsDataSource {
    weak var refScrollView: InfiniteScrollView?
    
    var infinite: Bool = true
    
    var sectionCount: Int = 1
    var itemCountInSection: [Int] = []
    var itemIndexPaths: [InfiniteIndexPath] = []
    
    var indexPathsInItem: [InfiniteIndexPath: [InfiniteIndexPath]] = [:]
    var rectForRowsInItem: [InfiniteIndexPath: [CGRect]] = [:]
    
    let constraint = ContentsConstraint()
    var mainContents: [ContentView] = []
    var leftContents: [ContentView] = []
    var rightContents: [ContentView] = []
    
    init(scrollView: InfiniteScrollView) {
        refScrollView = scrollView
    }
    
    func allContents() -> [ContentView] {
        return leftContents + mainContents + rightContents
    }
    
    func removeContents() {
        while let view = mainContents.popLast() ?? leftContents.popLast() ?? rightContents.popLast() {
            view.removeContentScrollView()
            view.removeFromSuperview()
        }
    }
    
    func numberOfSections() -> Int {
        if let infiniteView = refScrollView?.infiniteView, let sections = infiniteView.dataSource?.numberOfSectionsInInfiniteView?(infiniteView) {
            return sections
        }
        return 1
    }
    
    func numberOfItemsInSection(_ section: Int) -> Int {
        if let infiniteView = refScrollView?.infiniteView, let items = infiniteView.dataSource?.infiniteView(infiniteView, numberOfItemsInSection: section) {
            return items
        }
        return 0
    }
}

// MARK: - Reload
extension ContentsDataSource {
    func reloadAllData(_ bounds: CGRect, necessaryAroundCount: @autoclosure () -> Int) {
        reloadSectionData()
        refScrollView?.contentSize.height = reloadContentsHeight(bounds)
        addMainContents()
        
        if infinite == true && mainContents.count > 0 {
            let count = necessaryAroundCount()
            addLeftContents(count)
            addRightContents(count)
            replaceAroundConstraints()
        }
    }
    
    fileprivate func reloadSectionData() {
        sectionCount = numberOfSections()
        itemCountInSection = (0..<sectionCount).map { section in
            numberOfItemsInSection(section)
        }
        
        itemIndexPaths = itemCountInSection.enumerated().reduce([]) {
            enumerateIndexPath($0, mapper: reloadItemsData)
        }
    }
    
    fileprivate func reloadItemsData(_ itemIndexPath: InfiniteIndexPath) -> InfiniteIndexPath {
        let rowCount = numberOfRowsInItem(itemIndexPath)
        
        indexPathsInItem[itemIndexPath] = (0..<rowCount).map { index in
            InfiniteIndexPath(forRow: index, item: itemIndexPath.item, inSection: itemIndexPath.section)
        }
        
        return itemIndexPath
    }
    
    fileprivate func enumerateIndexPath<T>(_ element: (paths: [T], item: (index: Int, element: Int)), mapper: (InfiniteIndexPath) -> T) -> [T] {
        guard element.item.element > 0 else {
            return element.paths
        }
        
        return element.paths + (0..<element.item.element).map {
            mapper(InfiniteIndexPath(forRow: 0, item: $0, inSection: element.item.index))
        }
    }
    
    fileprivate func reloadContentsHeight(_ defaultRect: CGRect) -> CGFloat {
        var maxContentHeight: CGFloat = 0
        var rectForRows: [InfiniteIndexPath:[CGRect]] = [:]
        itemIndexPaths.forEach { itemIndexPath in
            rectForRows[itemIndexPath] = indexPathsInItem[itemIndexPath].map { indexPaths in
                var lastRect = CGRect.zero
                
                let rects = indexPaths.map { indexPath -> CGRect in
                    let height = heightForRowAtItemIndexPath(indexPath) ?? defaultRect.height
                    lastRect = CGRect(x: 0, y: lastRect.origin.y + lastRect.height, width: 0, height: height)
                    
                    return lastRect
                }
                
                maxContentHeight = max(maxContentHeight, lastRect.height + lastRect.origin.y)
                return rects
            }
        }
        rectForRowsInItem = rectForRows
        return maxContentHeight
    }
}

extension ContentsDataSource {
    func replaceAroundConstraints() {
        refScrollView?.removeConstraints(constraint.around)
        
        let leftConstraints = leftContents.betweenSpaceConstraints(rightView: mainContents.first)
        let rightConstraints = rightContents.betweenSpaceConstraints(leftView: mainContents.last)
        constraint.around.betweenSpaces.replace(leftConstraints + rightConstraints)
        constraint.around.leftSpaces.replace(leftContents.first?.leftSpaceConstraints())
        constraint.around.rightSpaces.replace(rightContents.last?.rightSpaceConstraints())
        
        refScrollView?.addConstraints(constraint.around)
    }
    
    func createContents(range: CountableRange<Int>, fullContents: [ContentView]? = nil, lastContentView: ContentView? = nil, viewBounds: CGRect) -> [ContentView] {
        return (range).reduce([]) { views, index -> [ContentView] in
            let lastView = views.last ?? lastContentView
            let origin: CGPoint
            
            if let lastView = lastView {
                origin = CGPoint(x: lastView.frame.origin.x + lastView.bounds.width, y: 0)
            } else {
                origin = viewBounds.origin
            }
            
            let contentView = ContentView(frame: CGRect(origin: origin, size: viewBounds.size))
            // referencing for move
            contentView.referenceContentViewForAround = fullContents?[index]
            contentView.borderColor = refScrollView?.separatorColor
            
            refScrollView?.insertSubview(contentView, aboveSubview: lastView)
            
            return views + [contentView]
        }
    }
    
    fileprivate func beforeBounds(_ count: Int, bounds: CGRect) -> CGRect {
        return CGRect(origin: CGPoint(x: -bounds.width * CGFloat(count), y: 0), size: bounds.size)
    }
    
    func addMainContents() {
        guard let scrollView = refScrollView else { return }
        
        // create all contents
        mainContents = itemIndexPaths.map(scrollView.configureContentViewAtIndexPath)
        let constraints = mainContents.betweenSpaceConstraints()
        constraint.main.betweenSpaces.append(constraints)
        
        if infinite == false || mainContents.count <= 0 {
            constraint.main.leftSpaces.append(mainContents.first?.leftSpaceConstraints())
            constraint.main.rightSpaces.append(mainContents.last?.rightSpaceConstraints())
        }
    }
    
    func addLeftContents(_ necessaryAroundCount: Int, bounds: CGRect = .zero) -> Int {
        let addCount = necessaryAroundCount - leftContents.count
        if addCount > 0 {
            let range = mainContents.count - necessaryAroundCount..<mainContents.count - leftContents.count
            var contents = createContents(range: range, fullContents: mainContents, viewBounds: beforeBounds(addCount, bounds: bounds))
            contents.append(contentsOf: leftContents)
            leftContents = contents
        }
        
        return addCount
    }
    
    func addRightContents(_ necessaryAroundCount: Int, bounds: CGRect = .zero) -> Int {
        let addCount = necessaryAroundCount - rightContents.count
        if addCount > 0 {
            let range = rightContents.count..<necessaryAroundCount
            let contents = createContents(range: range, fullContents: mainContents, lastContentView: rightContents.last, viewBounds: beforeBounds(addCount, bounds: bounds))
            rightContents.append(contentsOf: contents)
        }
        
        return addCount
    }
}

// MARK: - Grid
extension ContentsDataSource {
    func numberOfRowsInItem(_ indexPath: InfiniteIndexPath) -> Int {
        if let infiniteView = refScrollView?.infiniteView,
            let items = infiniteView.dataSource?.infiniteView?(infiniteView, numberOfRowsInItemAtIndexPath: indexPath) {
                return items
        }
        return 1
    }
    
    func heightForRowAtItemIndexPath(_ indexPath: InfiniteIndexPath) -> CGFloat? {
        if let infiniteView = refScrollView?.infiniteView {
            return infiniteView.delegate?.infiniteView?(infiniteView, heightForRowAtIndexPath: indexPath)
        }
        return nil
    }
}
