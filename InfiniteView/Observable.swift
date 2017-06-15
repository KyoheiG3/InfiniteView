//
//  Observable.swift
//  InfiniteView
//
//  Created by Kyohei Ito on 2015/12/17.
//  Copyright © 2015年 kyohei_ito. All rights reserved.
//

import UIKit

protocol Disposable {
    func dispose()
}

typealias Observer = [Weak<Observable>]

protocol Publisher: class {
    var observerCollection: [String: Observer] { get set }
    
    func addObserver(_ observer: Observable, key: String)
    func removeObserver(_ observer: Observable, forKey: String)
    func publish(_ key :String, object: () -> AnyObject)
}

extension Publisher {
    func addObserver(_ observer: Observable, key: String) {
        guard observerCollection[key] != nil else {
            return observerCollection[key] = [Weak(observer)]
        }
        
        observerCollection[key]?.append(Weak(observer))
    }
    
    func removeObserver(_ observer: Observable, forKey key: String) {
        observerCollection[key]?.enumerated().forEach { index, element in
            if element.object == observer || element.object == nil {
                observerCollection[key]?.remove(at: index)
            }
        }
    }
    
    func publish(_ key :String, object: () -> AnyObject) {
        if let observers = observerCollection[key] {
            let value = object()
            
            observers.forEach {
                $0.object?.observe(key, value: value)
            }
        }
    }
}

class Observable: NSObject, Disposable {
    fileprivate var keyPath: String
    fileprivate var target: Publisher    // strong reference
    fileprivate var handler: ((AnyObject?) -> Void)?
    
    init(target: Publisher, forKeyPath keyPath: String, handler: @escaping (AnyObject?) -> Void) {
        self.keyPath = keyPath
        self.target = target
        self.handler = handler
        
        super.init()
        
        target.addObserver(self, key: keyPath)
    }
    
    func observe(_ key: String, value: AnyObject) {
        handler?(value)
    }
    
    func dispose() {
        target.removeObserver(self, forKey: keyPath)
        handler = nil
    }
    
    deinit {
        dispose()
    }
}
