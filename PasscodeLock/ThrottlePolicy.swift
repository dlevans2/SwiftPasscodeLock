//
//  ThrottlePolicy.swift
//  PasscodeLock
//
//  Created by Mark Hudnall on 9/1/16.
//  Copyright © 2016 Yanko Dimitrov. All rights reserved.
//

import Foundation

public struct ThrottleMessage {
    let title: String?
    let body: String
    
    public init(title: String?, body: String) {
        self.title = title
        self.body = body
    }
}

public protocol ThrottlePolicy {
    var isThrottled: Bool { get }
    var throttleRemovedAt: TimeInterval { get }
    var message: ThrottleMessage { get }
    func markSuccess() -> Void
    func markFailure() -> Void
}

public struct NoThrottlePolicy: ThrottlePolicy {
    public let isThrottled: Bool = false
    public let throttleRemovedAt: TimeInterval = -1
    public var message: ThrottleMessage = ThrottleMessage(title: nil,
                                                   body: "This message should never be shown because this policy does no throttling.")
    public func markFailure() { }
    public func markSuccess() { }
    
    public init() {}
}
