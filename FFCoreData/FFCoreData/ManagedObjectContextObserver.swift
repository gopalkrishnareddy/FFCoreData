//
//  ManagedObjectContextObserver.swift
//  FFCoreData
//
//  Created by Florian Friedrich on 24.1.15.
//  Copyright 2015 Florian Friedrich
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation
import CoreData

public class MOCObserver {
    public typealias MOCObserverBlock = (observer: MOCObserver, changes: [String: [NSManagedObjectID]]?) -> ()
    
    private struct MOCNotificationObserver {
        let observer: NSObjectProtocol
        let object: NSObject?
    }
    
    #if swift(>=3.0)
    private let notificationCenter = NotificationCenter.default
    #else
    private let notificationCenter = NSNotificationCenter.defaultCenter()
    #endif
    
    public private(set) final var contexts: [NSManagedObjectContext]?
    
    private var observers = [MOCNotificationObserver]()
    #if swift(>=3.0)
    private let workerQueue = OperationQueue()
    
    public final var queue: OperationQueue
    #else
    private let workerQueue = NSOperationQueue()
    
    public final var queue: NSOperationQueue
    #endif
    public final var handler: MOCObserverBlock
    
    public init(contexts: [NSManagedObjectContext]? = nil, fireInitially: Bool = false, block: MOCObserverBlock) {
        self.contexts = contexts
        self.handler = block
        #if swift(>=3.0)
            self.queue = OperationQueue.current ?? OperationQueue.main
            let observerBlock: (note: Notification) -> Void = { [unowned self] (note) in
                self.managedObjectContextDidChange(notification: note)
            }
            if let contexts = contexts, !contexts.isEmpty {
                contexts.forEach {
                    let obsObj = notificationCenter.addObserver(forName: .NSManagedObjectContextObjectsDidChange, object: $0, queue: workerQueue, using: observerBlock)
                    observers.append(MOCNotificationObserver(observer: obsObj, object: $0))
                }
            } else {
                let obsObj = notificationCenter.addObserver(forName: .NSManagedObjectContextObjectsDidChange, object: nil, queue: workerQueue, using: observerBlock)
                observers.append(MOCNotificationObserver(observer: obsObj, object: nil))
            }
        #else
            self.queue = NSOperationQueue.currentQueue() ?? NSOperationQueue.mainQueue()
            let observerBlock: (note: NSNotification) -> Void = { [unowned self] (note) in
                self.managedObjectContextDidChange(note)
            }
            if let contexts = contexts where !contexts.isEmpty {
                contexts.forEach {
                    let obsObj = notificationCenter.addObserverForName(NSManagedObjectContextObjectsDidChangeNotification, object: $0, queue: workerQueue, usingBlock: observerBlock)
                    observers.append(MOCNotificationObserver(observer: obsObj, object: $0))
                }
            } else {
                let obsObj = notificationCenter.addObserverForName(NSManagedObjectContextObjectsDidChangeNotification, object: nil, queue: workerQueue, usingBlock: observerBlock)
                observers.append(MOCNotificationObserver(observer: obsObj, object: nil))
            }
        #endif
        if fireInitially {
            block(observer: self, changes: nil)
        }
    }
    
    deinit {
        observers.forEach {
            #if swift(>=3.0)
                notificationCenter.removeObserver($0.observer, name: .NSManagedObjectContextObjectsDidChange, object: $0.object)
            #else
                notificationCenter.removeObserver($0.observer, name: NSManagedObjectContextObjectsDidChangeNotification, object: $0.object)
            #endif
        }
    }
    
    #if swift(>=3.0)
    internal func include(managedObject: NSManagedObject) -> Bool {
        return true
    }
    #else
    internal func includeManagedObject(object: NSManagedObject) -> Bool {
        return true
    }
    #endif
    
    private final func managedObjectContextDidChange(notification: NSNotification) {
        #if swift(>=3.0)
            if let userInfo = notification.userInfo, let changes = filtered(changeDictionary: userInfo) {
                queue.addOperation {
                    self.handler(observer: self, changes: changes)
                }
            }
        #else
            if let userInfo = notification.userInfo, changes = filteredChangeDictionary(userInfo) {
                queue.addOperationWithBlock {
                    self.handler(observer: self, changes: changes)
                }
            }
        #endif
    }
    
    #if swift(>=3.0)
    private final func filtered(changeDictionary changes: [NSObject: AnyObject]) -> [String: [NSManagedObjectID]]? {
        let inserted = changes[NSInsertedObjectsKey] as? Set<NSManagedObject>
        let updated = changes[NSUpdatedObjectsKey] as? Set<NSManagedObject>
        let deleted = changes[NSDeletedObjectsKey] as? Set<NSManagedObject>
        
        let insertedIDs = inserted?.filter(include).map { $0.objectID }
        let updatedIDs = updated?.filter(include).map { $0.objectID }
        let deletedIDs = deleted?.filter(include).map { $0.objectID }
        
        var newChanges = [String: [NSManagedObjectID]]()
        let objectIDsAndKeys = [
            (insertedIDs, NSInsertedObjectsKey),
            (updatedIDs, NSUpdatedObjectsKey),
            (deletedIDs, NSDeletedObjectsKey)
        ]
        for (objIDs, key) in objectIDsAndKeys {
            if objIDs?.count > 0 { newChanges[key] = objIDs }
        }
        return (newChanges.count > 0) ? newChanges : nil
    }
    #else
    private final func filteredChangeDictionary(changes: [NSObject: AnyObject]) -> [String: [NSManagedObjectID]]? {
        let inserted = changes[NSInsertedObjectsKey] as? Set<NSManagedObject>
        let updated = changes[NSUpdatedObjectsKey] as? Set<NSManagedObject>
        let deleted = changes[NSDeletedObjectsKey] as? Set<NSManagedObject>
        
        let insertedIDs = inserted?.filter(includeManagedObject).map { $0.objectID }
        let updatedIDs = updated?.filter(includeManagedObject).map { $0.objectID }
        let deletedIDs = deleted?.filter(includeManagedObject).map { $0.objectID }
        
        var newChanges = [String: [NSManagedObjectID]]()
        let objectIDsAndKeys = [
            (insertedIDs, NSInsertedObjectsKey),
            (updatedIDs, NSUpdatedObjectsKey),
            (deletedIDs, NSDeletedObjectsKey)
        ]
        for (objIDs, key) in objectIDsAndKeys {
            if objIDs?.count > 0 { newChanges[key] = objIDs }
        }
        return (newChanges.count > 0) ? newChanges : nil
    }
    #endif
}
