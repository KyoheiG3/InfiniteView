//
//  ContentScrollView.swift
//  InfiniteView
//
//  Created by Kyohei Ito on 2015/12/14.
//  Copyright © 2015年 kyohei_ito. All rights reserved.
//

import UIKit

class Weak<T: AnyObject> {
    weak var object: T?
    
    init(_ object: T) {
        self.object = object
    }
}

class ContentScrollView: UIScrollView {
    weak var refInfiniteView: InfiniteView?
    var cellRects: [CGRect] = []
    var cellIndexPaths: [InfiniteIndexPath] = []
    var cellReferences: [InfiniteIndexPath: Weak<InfiniteViewCell>] = [:]
    
    var indexPath = InfiniteIndexPath(forItem: 0, inSection: 0)
    var displayed = false
    var disposable: Disposable?
    
    func convertCellRect(_ rect: CGRect) -> CGRect {
        let size = CGSize(width: bounds.width, height: rect.height)
        return CGRect(origin: rect.origin, size: size)
    }
    
    func visibleCells<T>() -> [T] {
        return displayedCellRects.map { index, rect in
            cellIndexPaths[index]
        }
        .filter { indexPath in
            cellReferences[indexPath]?.object is T
        }
        .map { indexPath in
            cellReferences[indexPath]!.object as! T
        }
    }
    func visibleCenterCell<T>() -> T? {
        let point = CGPoint(x: center.x, y: contentOffset.y + center.y)
        if let indexPath = indexPathForRowAtPoint(point) {
            return cellReferences[indexPath]?.object as? T
        }
        
        return nil
    }
    
    func indexPathForRowAtPoint(_ point: CGPoint) -> InfiniteIndexPath? {
        if let cellRect: (index: Int, rect: CGRect) = displayedCellRects.filter({ index, rect in
            return convertCellRect(rect).contains(point)
        }).first {
            return cellIndexPaths[cellRect.index]
        }
        
        return nil
    }
    
    func cellForRowAtIndexPath<T>(_ indexPath: InfiniteIndexPath) -> T? {
        return cellReferences[indexPath]?.object as? T
    }
    
    func rectForRowAtIndexPath(_ indexPath: InfiniteIndexPath) -> CGRect {
        if let index = cellIndexPaths.index(of: indexPath) {
            return convertCellRect(cellRects[index])
        }
        return .zero
    }
    
    func deselectRowAtIndexPath(_ indexPath: InfiniteIndexPath) {
        cellReferences[indexPath]?.object?.selected = false
    }
    
    func selectRowAtIndexPath(_ indexPath: InfiniteIndexPath) {
        cellReferences[indexPath]?.object?.selected = true
        refInfiniteView?.addSelectedIndexPath(indexPath)
    }
    
    fileprivate var displayedCellRects: [(Int, CGRect)] = []
    fileprivate var visibleRect: CGRect {
        return CGRect(origin: contentOffset, size: bounds.size)
    }
    
    fileprivate func removeCellReference(_ indexPath: InfiniteIndexPath, reference: Weak<InfiniteViewCell>?) {
        reference?.object?.displayed = false
        cellReferences[indexPath] = nil
    }
    
    override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)
        
        if newSuperview == nil {
            cellReferences.forEach(removeCellReference)
        } else {
            clipsToBounds = false
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        
        if let touch = touches.first {
            if let indexPath = indexPathForRowAtPoint(touch.location(in: self)) {
                selectRowAtIndexPath(indexPath)
            }
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        contentSize.width = bounds.width
        
        guard displayed else { return }
        
        didEndDisplayingCells(false)
        willDisplayCells()
    }
    
    fileprivate func insertContentCell(_ cell: InfiniteViewCell, index: Int) {
        cell.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
        insertSubview(cell, at: index)
        cellReferences[cell.indexPath] = Weak(cell)
    }
    
    fileprivate func removeContentCell(_ cell: InfiniteViewCell) {
        cell.removeFromSuperview()
        removeCellReference(cell.indexPath, reference: cellReferences[cell.indexPath])
    }
    
    fileprivate func addContentCellWithConfigure(_ index: Int, rect: CGRect) {
        guard let infiniteView = refInfiniteView else { return }
        
        let rowIndexPath = cellIndexPaths[index]
        if let cell = refInfiniteView?.dataSource?.infiniteView(infiniteView, cellForItemAtIndexPath: rowIndexPath) {
            cell.frame = rect
            cell.frame.size.width = contentSize.width
            cell.layoutIfNeeded()
            
            UIView.performWithAnimation {
                cell.frame.size.width = self.bounds.width
            }
            cell.indexPath = rowIndexPath
            insertContentCell(cell, index: index)
        }
    }
    
    func configureCells(_ all: Bool = true) {
        if all {
            cellRects.enumerated().forEach(addContentCellWithConfigure)
        } else {
            let rect = visibleRect
            cellRects.enumerated().filter { index, cellRect in
                rect.intersects(cellRect)
            }.forEach(addContentCellWithConfigure)
        }
    }
    
    func willDisplayCells() {
        let rect = visibleRect
        cellRects.enumerated().forEach { index, cellRect in
            guard rect.intersects(cellRect) else { return }
            
            let rowIndexPath = cellIndexPaths[index]
            if cellReferences[rowIndexPath] == nil {
                addContentCellWithConfigure(index, rect: cellRect)
            }
            
            guard let cell = cellReferences[rowIndexPath]?.object , cell.displayed == false else { return }
            
            if let infiniteView = refInfiniteView {
                refInfiniteView?.delegate?.infiniteView?(infiniteView, willDisplayCell: cell, forItemAtIndexPath: cell.indexPath)
            }
            
            cell.displayed = true
            displayedCellRects.append((index, cellRect))
        }
    }
    
    func didEndDisplayingCells(_ all: Bool = true) {
        let rect = visibleRect
        displayedCellRects = displayedCellRects.filter { index, cellRect in
            guard all || rect.intersects(cellRect) == false else { return true }
            guard let cell = cellReferences[cellIndexPaths[index]]?.object , cell.displayed else { return true }
            
            cell.displayed = false
            
            if let infiniteView = refInfiniteView {
                refInfiniteView?.delegate?.infiniteView?(infiniteView, didEndDisplayingCell: cell, forItemAtIndexPath: cell.indexPath)
                
                if infiniteView.reusable {
                    removeContentCell(cell)
                }
            }
            
            return false
        }
    }
    
    func startObserveContentOffset() {
        disposable = refInfiniteView?.wrapperView.subscribeContentOffset { [weak self] contentOffset in
            self?.setContentOffset(CGPoint(x: 0, y: contentOffset.y), animated: false)
            self?.layoutIfNeeded()
        }
    }
}
