//
//  InfiniteView.swift
//  InfiniteView
//
//  Created by Kyohei Ito on 2015/11/04.
//  Copyright © 2015年 kyohei_ito. All rights reserved.
//

import UIKit

@objc public protocol InfiniteViewDataSource: class {
    func infiniteView(_ infiniteView: InfiniteView, numberOfItemsInSection section: Int) -> Int
    func infiniteView(_ infiniteView: InfiniteView, cellForItemAtIndexPath indexPath: InfiniteIndexPath) -> InfiniteViewCell
    
    @objc optional func numberOfSectionsInInfiniteView(_ infiniteView: InfiniteView) -> Int
    
    // grid
    /// row number in item at item indexPath default 1
    @objc optional func infiniteView(_ infiniteView: InfiniteView, numberOfRowsInItemAtIndexPath indexPath: InfiniteIndexPath) -> Int
}

@objc public protocol InfiniteViewDelegate {
    @objc optional func infiniteView(_ infiniteView: InfiniteView, willDisplayCell cell: InfiniteViewCell, forItemAtIndexPath indexPath: InfiniteIndexPath)
    @objc optional func infiniteView(_ infiniteView: InfiniteView, didEndDisplayingCell cell: InfiniteViewCell, forItemAtIndexPath indexPath: InfiniteIndexPath)
    
    @objc optional func infiniteView(_ infiniteView: InfiniteView, didSelectRowAtIndexPath indexPath: InfiniteIndexPath)
    
    // default is view bounds height
    @objc optional func infiniteView(_ infiniteView: InfiniteView, heightForRowAtIndexPath indexPath: InfiniteIndexPath) -> CGFloat
    
    @objc optional func infiniteViewDidScroll(_ infiniteView: InfiniteView)
    
    @objc optional func infiniteViewWillBeginDragging(_ infiniteView: InfiniteView)
    @objc optional func infiniteViewWillEndDragging(_ infiniteView: InfiniteView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>)
    @objc optional func infiniteViewDidEndDragging(_ infiniteView: InfiniteView, willDecelerate decelerate: Bool)
    
    @objc optional func infiniteViewWillBeginDecelerating(_ infiniteView: InfiniteView)
    @objc optional func infiniteViewDidEndDecelerating(_ infiniteView: InfiniteView)
    
    /// called when setContentOffset/scrollToItemAtIndexPath:animated: beginning. not called if not animating
    @objc optional func infiniteViewWillBeginScrollingAnimation(_ infiniteView: InfiniteView)
    @objc optional func infiniteViewDidEndScrollingAnimation(_ infiniteView: InfiniteView)
}

open class InfiniteView: UIView {
    fileprivate struct Group: ConstraintGroup {
        var top: Constraints = Constraints()
        var bottom: Constraints = Constraints()
        var left: Constraints = Constraints()
        var right: Constraints = Constraints()
        var width: Constraints = Constraints()
        var center: Constraints = Constraints()
        
        func allConstraints() -> Constraints {
            return top + bottom + left + right + width + center
        }
    }
    
    open var contentInset: UIEdgeInsets {
        get {
            let rect = baseView.frame
            let bottom = frame.height - (rect.origin.y + rect.height)
            let right = frame.width - (rect.origin.x + rect.width)
            return UIEdgeInsets(top: rect.origin.y, left: rect.origin.x, bottom: bottom, right: right)
        }
        set(insets) {
            removeConstraints(constraintGroup)
            constraintGroup.width.removeAll()
            constraintGroup.center.removeAll()
            constraintGroup.top.constant = insets.top
            constraintGroup.bottom.constant = insets.bottom
            constraintGroup.left.replace(baseView.leftSpaceConstraints(insets.left))
            constraintGroup.right.replace(baseView.rightSpaceConstraints(insets.right))
            addConstraints(constraintGroup)
            
            invalidateLayout()
        }
    }
    open var contentWidth: CGFloat {
        get { return baseView.bounds.width }
        set(width) {
            removeConstraints(constraintGroup)
            constraintGroup.width.replace(baseView.widthConstraints(width))
            constraintGroup.center.replace(baseView.centerXConstraints())
            constraintGroup.left.removeAll()
            constraintGroup.right.removeAll()
            addConstraints(constraintGroup)
            
            invalidateLayout()
        }
    }
    
    open var innerScrollView: UIScrollView {
        return wrapperView
    }
    open var contentSize: CGSize {
        return wrapperView.contentSize
    }
    open var contentOffset: CGPoint {
        return wrapperView.visibleContentOffset
    }
    
    open var pagingEnabled: Bool {
        get { return wrapperView.isPagingEnabled }
        set { wrapperView.isPagingEnabled = newValue }
    }
    open var scrollEnabled: Bool {
        get { return wrapperView.isScrollEnabled }
        set { wrapperView.isScrollEnabled = newValue }
    }
    open var infinite: Bool {
        get { return scrollView.dataSource.infinite }
        set { scrollView.dataSource.infinite = newValue }
    }
    open var reusable: Bool {
        get { return scrollView.reusable }
        set { scrollView.reusable = newValue }
    }
    open var separatorColor: UIColor? {
        get { return scrollView.separatorColor }
        set { scrollView.separatorColor = newValue }
    }
    
    open fileprivate(set) var indexPathsForSelectedRows: Set<InfiniteIndexPath> = []
    
    let baseView = PermitEventView(frame: .zero)
    let scrollView = InfiniteScrollView(frame: .zero)
    let wrapperView = InfiniteScrollWrapperView(frame: .zero)
    fileprivate var cellReuseQueue: CellReuseQueue = CellReuseQueue()
    fileprivate var registeredObject: [String: AnyObject] = [:]
    fileprivate var constraintGroup: Group = Group()
    
    @IBOutlet open weak var dataSource: InfiniteViewDataSource?
    @IBOutlet open weak var delegate: InfiniteViewDelegate?
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        addBaseView()
        addContentView()
        addWrapperView()
        
        scrollView.startObserveContentOffset()
        scrollView.replaceGestureRecognizers(wrapperView.gestureRecognizers)
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        clipsToBounds = true
        addBaseView()
        addContentView()
        addWrapperView()
        
        scrollView.startObserveContentOffset()
        scrollView.replaceGestureRecognizers(wrapperView.gestureRecognizers)
    }
    
    func addBaseView() {
        baseView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(baseView)
        
        constraintGroup.top.append(baseView.topSpaceConstraints())
        constraintGroup.bottom.append(baseView.bottomSpaceConstraints())
        constraintGroup.left.append(baseView.leftSpaceConstraints())
        constraintGroup.right.append(baseView.rightSpaceConstraints())
        addConstraints(constraintGroup)
    }
    
    func addContentView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.isScrollEnabled = false
        baseView.addSubview(scrollView)
        
        var edges = Constraints()
        edges.append(scrollView.edgesSpaceConstraints())
        baseView.addConstraints(edges)
    }
    
    func addWrapperView() {
        wrapperView.translatesAutoresizingMaskIntoConstraints = false
        wrapperView.isUserInteractionEnabled = false
        wrapperView.showsHorizontalScrollIndicator = false
        wrapperView.showsVerticalScrollIndicator = false
        wrapperView.delegate = self
        baseView.addSubview(wrapperView)
        
        var edges = Constraints()
        edges.append(wrapperView.edgesSpaceConstraints())
        baseView.addConstraints(edges)
    }
    
    open func dequeueReusableCellWithReuseIdentifier(_ identifier: String) -> InfiniteViewCell {
        if reusable, let view = cellReuseQueue.dequeue(identifier) {
            view.reuseIdentifier = identifier
            view.prepareForReuse()
            return view
        }
        
        var reuseContent: InfiniteViewCell!
        if let nib = registeredObject[identifier] as? UINib, let instance = nib.instantiate(withOwner: nil, options: nil).first as? InfiniteViewCell {
            reuseContent = instance
        } else if let T = registeredObject[identifier] as? InfiniteViewCell.Type {
            reuseContent = T.init(frame: scrollView.bounds)
        } else {
            fatalError("could not dequeue a view of kind: UIView with identifier \(identifier) - must register a nib or a class for the identifier")
        }
        
        if reusable {
            cellReuseQueue.append(reuseContent, forQueueIdentifier: identifier)
        }
        
        return reuseContent
    }
    
    /// For each reuse identifier that the infinite view will use, register either a class or a nib from which to instantiate a cell.
    /// If a nib is registered, it must contain exactly 1 top level object which is a InfiniteViewCell.
    /// If a class is registered, it will be instantiated via alloc/initWithFrame:
    open func registerNib(_ nib: UINib?, forCellWithReuseIdentifier identifier: String) {
        registeredObject[identifier] = nib
    }
    
    open func registerClass<T: InfiniteViewCell>(_ viewClass: T.Type, forCellWithReuseIdentifier identifier: String) {
        registeredObject[identifier] = viewClass
    }
    
    /// Discard the dataSource and delegate data, also requery as necessary.
    open func reloadData() {
        scrollView.dataSource.removeContents()
        scrollView.dataSource.constraint.removeAll()
        scrollView.needsReload = true
        
        scrollView.setNeedsLayout()
        layoutIfNeeded()
    }
    
    /// Relayout as necessary.
    open func invalidateLayout() {
        scrollView.needsLayout = true
        
        scrollView.setNeedsLayout()
    }
    
    /// Information about the current state of the infinite view.
    
    open func numberOfSections() -> Int {
        return scrollView.dataSource.numberOfSections()
    }
    
    open func numberOfItemsInSection(_ section: Int) -> Int {
        return scrollView.dataSource.numberOfItemsInSection(section)
    }
    
    open func rectForRowAtIndexPath(_ indexPath: InfiniteIndexPath) -> CGRect? {
        let itemIndexPath = InfiniteIndexPath(forItem: indexPath.item, inSection: indexPath.section)
        return scrollView.contentViewAtIndexPath(itemIndexPath, absolute: true)?.scrollView?.rectForRowAtIndexPath(indexPath)
    }
    
    open func cellForRowAtIndexPath(_ indexPath: InfiniteIndexPath) -> InfiniteViewCell? {
        let itemIndexPath = InfiniteIndexPath(forItem: indexPath.item, inSection: indexPath.section)
        return scrollView.contentViewAtIndexPath(itemIndexPath, absolute: true)?.scrollView?.cellForRowAtIndexPath(indexPath)
    }
    
    open func scrollToItemAtIndexPath(_ indexPath: InfiniteIndexPath, animated: Bool = false) {
        let itemIndexPath = InfiniteIndexPath(forItem: indexPath.item, inSection: indexPath.section)
        if let view = scrollView.contentViewAtIndexPath(itemIndexPath, absolute: false) {
            let offsetY: CGFloat
            if let rect = scrollView.contentViewAtIndexPath(itemIndexPath, absolute: true)?.scrollView?.rectForRowAtIndexPath(indexPath) {
                offsetY = rect.origin.y
            } else {
                offsetY = wrapperView.contentOffset.y
            }
            let offset = CGPoint(x: view.frame.origin.x - scrollView.leftAroundWidth, y: offsetY)
            setContentOffset(offset, animated: animated)
        }
    }
    
    open func setContentOffset(_ contentOffset: CGPoint, animated: Bool = false, needLayout: Bool = false) {
        if contentOffset == wrapperView.contentOffset {
            return
        }
        
        if animated {
            delegate?.infiniteViewWillBeginScrollingAnimation?(self)
            
            UIView.animate(withDuration: 0.3,
                animations: {
                    self.wrapperView.setContentOffset(contentOffset, animated: needLayout)
                },
                completion: { _ in
                    self.wrapperView.delegate?.scrollViewDidEndScrollingAnimation?(self.wrapperView)
            })
        } else {
            wrapperView.setContentOffset(contentOffset, animated: false)
        }
    }
}

extension InfiniteView {
    public func deselectRowAtIndexPath(_ indexPath: InfiniteIndexPath) {
        indexPathsForSelectedRows.remove(indexPath)
        
        let itemIndexPath = InfiniteIndexPath(forItem: indexPath.item, inSection: indexPath.section)
        scrollView.contentViewAtIndexPath(itemIndexPath, absolute: true)?.scrollView?.deselectRowAtIndexPath(indexPath)
    }
    
    func addSelectedIndexPath(_ indexPath: InfiniteIndexPath) {
        indexPathsForSelectedRows.insert(indexPath)
        delegate?.infiniteView?(self, didSelectRowAtIndexPath: indexPath)
    }
}

// MARK: - Visibility
extension InfiniteView {
    public func visibleCells() -> [InfiniteViewCell] {
        return scrollView.visibleContents().filter { (view: ContentView) in
            view.scrollView != nil
        }.flatMap { $0.scrollView!.visibleCells() }
    }
    
    public func visibleCells<T>() -> [T] {
        return scrollView.visibleContents().filter { (view: ContentView) in
            view.scrollView != nil
        }.flatMap { $0.scrollView!.visibleCells() }
    }
    
    public func visibleCenterCell() -> InfiniteViewCell? {
        return scrollView.visibleCenterContent()?.scrollView?.visibleCenterCell()
    }
    
    public func visibleCenterCell<T>() -> T? {
        return scrollView.visibleCenterContent()?.scrollView?.visibleCenterCell()
    }
}

// MARK: - UIScrollViewDelegate
extension InfiniteView: UIScrollViewDelegate {
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        wrapperView.publish("contentOffset") {
            NSValue(cgPoint: scrollView.contentOffset)
        }
        delegate?.infiniteViewDidScroll?(self)
    }
    
    // MARK: Dragging
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        delegate?.infiniteViewWillBeginDragging?(self)
    }
    
    public func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        delegate?.infiniteViewWillEndDragging?(self, withVelocity: velocity, targetContentOffset: targetContentOffset)
    }
    
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        delegate?.infiniteViewDidEndDragging?(self, willDecelerate: decelerate)
    }
    
    // MARK: Decelerating
    public func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {
        delegate?.infiniteViewWillBeginDecelerating?(self)
    }
    
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        delegate?.infiniteViewDidEndDecelerating?(self)
    }
    
    // MARK: ScrollingAnimation
    public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        delegate?.infiniteViewDidEndScrollingAnimation?(self)
    }
}
