//
//  EnterPasscodeState.swift
//  PasscodeLock
//
//  Created by Yanko Dimitrov on 8/28/15.
//  Copyright © 2015 Yanko Dimitrov. All rights reserved.
//

import Foundation

public let PasscodeLockIncorrectPasscodeNotification = "passcode.lock.incorrect.passcode.notification"

struct EnterPasscodeState: PasscodeLockStateType {
    
    let title: String
    let description: String
    let isCancellableAction: Bool
    var isTouchIDAllowed = true
    
    fileprivate var isNotificationSent = false
    
    init(allowCancellation: Bool = false) {
        
        isCancellableAction = allowCancellation
        title = localizedStringFor("PasscodeLockEnterTitle", comment: "Enter passcode title")
        description = localizedStringFor("PasscodeLockEnterDescription", comment: "Enter passcode description")
    }
    
    mutating func acceptPasscode(_ passcode: [String], fromLock lock: PasscodeLockType) {
        
        guard let currentPasscode = lock.repository.passcode else {
            lock.delegate?.passcodeLockDidFail(lock, reason: .repositoryHasNoPasscode)
            return
        }
        
        if lock.configuration.throttlePolicy.isThrottled {
            lock.delegate?.passcodeLockDidFail(lock, reason: .throttled)
            return
        }
        
        if passcode == currentPasscode {
            lock.configuration.throttlePolicy.markSuccess()
            lock.delegate?.passcodeLockDidSucceed(lock)
            
        } else {
            lock.configuration.throttlePolicy.markFailure()
            
            if lock.configuration.throttlePolicy.isThrottled {
                lock.delegate?.passcodeLockDidFail(lock, reason: .throttled)
                return
            } else {
                lock.delegate?.passcodeLockDidFail(lock, reason: .incorrectPasscode)
            }

        }
    }
}
