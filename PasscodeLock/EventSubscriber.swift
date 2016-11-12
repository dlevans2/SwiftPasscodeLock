//
//  EventSubscriber.swift
//  PasscodeLock
//
//  Created by Mark Hudnall on 9/1/16.
//  Copyright © 2016 Yanko Dimitrov. All rights reserved.
//

import Foundation

class EventSubscriber {
    weak var target: AnyObject?
    let selector: Selector
    let eventName: String
    let object: AnyObject?
    
    let notificationCenter: NotificationCenter
    
    init(target: AnyObject,
         selector: Selector,
         eventName: String,
         object: AnyObject? = nil,
         notificationCenter: NotificationCenter = NotificationCenter.default) {
        self.target = target
        self.selector = selector
        self.eventName = eventName
        self.object = object
        self.notificationCenter = notificationCenter
    }
    
    func unsubscribe() {
        self.notificationCenter.removeObserver(self)
    }
    
    func subscribe() {
        self.notificationCenter.addObserver(self, selector: #selector(handleEvent), name: NSNotification.Name(rawValue: self.eventName), object: self.object)
    }
    
    @objc func handleEvent(_ notification: Notification) {
        let _ = target?.perform(self.selector, with: notification)
    }
}
