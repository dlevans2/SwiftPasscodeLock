//
//  PasscodeLockViewController.swift
//  PasscodeLock
//
//  Created by Yanko Dimitrov on 8/28/15.
//  Copyright © 2015 Yanko Dimitrov. All rights reserved.
//

import UIKit

public protocol PasscodeEntryDelegate: class {
    func onSuccess(_ viewController: PasscodeLockViewController) -> Void
    func onThrottle(_ viewController: PasscodeLockViewController) -> Void
}

open class PasscodeLockViewController: UIViewController, PasscodeLockTypeDelegate {
    public enum LockState {
        case enterPasscode
        case setPasscode
        case changePasscode
        case removePasscode
        
        func getState() -> PasscodeLockStateType {
            switch self {
            case .enterPasscode: return EnterPasscodeState()
            case .setPasscode: return SetPasscodeState()
            case .changePasscode: return ChangePasscodeState()
            case .removePasscode: return EnterPasscodeState(allowCancellation: true)
            }
        }
    }
    
    @IBOutlet open weak var titleLabel: UILabel?
    @IBOutlet open weak var descriptionLabel: UILabel?
    @IBOutlet open var placeholders: [PasscodeSignPlaceholderView] = [PasscodeSignPlaceholderView]()
    @IBOutlet open weak var cancelButton: UIButton?
    @IBOutlet open weak var deleteSignButton: UIButton?
    @IBOutlet open weak var touchIDButton: UIButton?
    @IBOutlet open weak var placeholdersX: NSLayoutConstraint?
    
    open weak var delegate: PasscodeEntryDelegate?
    
    open var dismissCompletionCallback: (()->Void)?
    open var animateOnDismiss: Bool
    open var notificationCenter: NotificationCenter?
    
    internal let passcodeConfiguration: PasscodeLockConfigurationType
    internal let passcodeLock: PasscodeLockType
    internal var isPlaceholdersAnimationCompleted = true
    
    fileprivate var shouldTryToAuthenticateWithBiometrics = true
    
    var eventSubscribers: [EventSubscriber]! = []
    
    // MARK: - Initializers
    
	public init(state: PasscodeLockStateType, configuration: PasscodeLockConfigurationType, animateOnDismiss: Bool = true, nibName: String = "PasscodeLockView", bundle: Bundle? = nil) {

        self.animateOnDismiss = animateOnDismiss

        passcodeConfiguration = configuration
        passcodeLock = PasscodeLock(state: state, configuration: configuration)
        
        let bundleToUse = bundle ?? bundleForResource(nibName, ofType: "nib")
        
        super.init(nibName: nibName, bundle: bundleToUse)
        
        passcodeLock.delegate = self
        notificationCenter = NotificationCenter.default
    }
    
    public convenience init(state: LockState,
                            configuration: PasscodeLockConfigurationType,
                            animateOnDismiss: Bool = true,
                            shouldAuthenticateOnForeground: Bool = true
        ) {
        self.init(state: state.getState(), configuration: configuration, animateOnDismiss: animateOnDismiss)
        
        var eventSubscribers: [EventSubscriber] = []
        if shouldAuthenticateOnForeground {
            eventSubscribers = [
                EventSubscriber(target: self,
                    selector: #selector(appWillEnterForegroundHandler),
                    eventName: NSNotification.Name.UIApplicationWillEnterForeground.rawValue),
                EventSubscriber(target: self,
                    selector: #selector(appDidEnterBackgroundHandler),
                    eventName: NSNotification.Name.UIApplicationDidEnterBackground.rawValue)
            ]
        }
        self.eventSubscribers = eventSubscribers
    }
    
    public required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        clearEvents()
    }
    
    // MARK: - View
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        deleteSignButton?.isEnabled = false
        touchIDButton?.imageView?.contentMode = .scaleAspectFill
        
        setupEvents()
    }
    
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        updatePasscodeView()
    }
    
    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if shouldTryToAuthenticateWithBiometrics && passcodeConfiguration.shouldRequestTouchIDImmediately {
        
            authenticateWithBiometrics()
        }
    }
    
    internal func updatePasscodeView() {
        
        titleLabel?.text = passcodeLock.state.title
        descriptionLabel?.text = passcodeLock.state.description
        cancelButton?.isHidden = !passcodeLock.state.isCancellableAction
        touchIDButton?.isHidden = !passcodeLock.isTouchIDAllowed
    }
    
    // MARK: - Events
    
    fileprivate func setupEvents() {
        self.eventSubscribers.forEach { (subscriber: EventSubscriber) in
            subscriber.subscribe()
        }
    }
    
    fileprivate func clearEvents() {
        self.eventSubscribers.forEach { (subscriber: EventSubscriber) in
            subscriber.unsubscribe()
        }
    }
    
    open func appWillEnterForegroundHandler(_ notification: Notification) {
        
        if passcodeConfiguration.shouldRequestTouchIDImmediately {
            authenticateWithBiometrics()
        }
    }
    
    open func appDidEnterBackgroundHandler(_ notification: Notification) {
        
        shouldTryToAuthenticateWithBiometrics = false
    }
    
    // MARK: - Actions
    
    @IBAction func passcodeSignButtonTap(_ sender: PasscodeSignButton) {
        
        guard isPlaceholdersAnimationCompleted else { return }
        
        passcodeLock.addSign(sender.passcodeSign)
    }
    
    @IBAction func cancelButtonTap(_ sender: UIButton) {
        
        dismissPasscodeLock(passcodeLock)
    }
    
    @IBAction func deleteSignButtonTap(_ sender: UIButton) {
        
        passcodeLock.removeSign()
    }
    
    @IBAction func touchIDButtonTap(_ sender: UIButton) {
        
        passcodeLock.authenticateWithBiometrics()
    }
    
    open func authenticateWithBiometrics() {
        
        guard passcodeConfiguration.repository.hasPasscode else { return }

        if passcodeLock.isTouchIDAllowed {
            
            passcodeLock.authenticateWithBiometrics()
        }
    }
    
    internal func dismissPasscodeLock(_ lock: PasscodeLockType, completionHandler: (() -> Void)? = nil) {
        
        // if presented as modal
        if presentingViewController?.presentedViewController == self {
            
            dismiss(animated: animateOnDismiss, completion: { [weak self] _ in
                
                self?.dismissCompletionCallback?()
                
                completionHandler?()
            })
            
            return
            
        // if pushed in a navigation controller
        } else if navigationController != nil {
        
            let _ = navigationController?.popViewController(animated: animateOnDismiss)
        }
        
        dismissCompletionCallback?()
        
        completionHandler?()
    }
    
    // MARK: - Animations
    
    internal func animateWrongPassword() {
        
        deleteSignButton?.isEnabled = false
        isPlaceholdersAnimationCompleted = false
        
        animatePlaceholders(placeholders, toState: .error)
        
        placeholdersX?.constant = -40
        view.layoutIfNeeded()
        
        UIView.animate(
            withDuration: 0.5,
            delay: 0,
            usingSpringWithDamping: 0.2,
            initialSpringVelocity: 0,
            options: [],
            animations: {
                
                self.placeholdersX?.constant = 0
                self.view.layoutIfNeeded()
            },
            completion: { completed in
                
                self.isPlaceholdersAnimationCompleted = true
                self.animatePlaceholders(self.placeholders, toState: .inactive)
        })
    }
    
    internal func animatePlaceholders(_ placeholders: [PasscodeSignPlaceholderView], toState state: PasscodeSignPlaceholderView.State) {
        
        for placeholder in placeholders {
            
            placeholder.animateState(state)
        }
    }
    
    fileprivate func animatePlacehodlerAtIndex(_ index: Int, toState state: PasscodeSignPlaceholderView.State) {
        
        guard index < placeholders.count && index >= 0 else { return }
        
        placeholders[index].animateState(state)
    }
    
    func showThrottleMessage(_ message: ThrottleMessage, completion: ((UIAlertAction) -> Void)?) {
        let alertController = UIAlertController(title: message.title,
                                                message: message.body,
                                                preferredStyle: .alert)
        
        
        let OKAction = UIAlertAction(title: "OK", style: .default, handler: completion)
        alertController.addAction(OKAction)
        
        self.present(alertController, animated: true) {
        }
    }

    // MARK: - PasscodeLockDelegate
    
    open func passcodeLockDidSucceed(_ lock: PasscodeLockType) {
        deleteSignButton?.isEnabled = true
        animatePlaceholders(placeholders, toState: .inactive)
        dismissPasscodeLock(lock, completionHandler: { [weak self] _ in
            if let strongSelf = self {
                strongSelf.delegate?.onSuccess(strongSelf)
            }
        })
    }
    
    open func passcodeLockDidFail(_ lock: PasscodeLockType, reason: PasscodeFailureReason) {
        switch reason {
        case .incorrectPasscode:
            animateWrongPassword()
        case .throttled:
            animateWrongPassword()
            showThrottleMessage(lock.configuration.throttlePolicy.message) { (action) in
                self.delegate?.onThrottle(self)
            }
        default:
            animateWrongPassword()
        }
    }
    
    open func passcodeLockDidChangeState(_ lock: PasscodeLockType) {
        updatePasscodeView()
        animatePlaceholders(placeholders, toState: .inactive)
        deleteSignButton?.isEnabled = false
    }
    
    open func passcodeLock(_ lock: PasscodeLockType, addedSignAtIndex index: Int) {
        
        animatePlacehodlerAtIndex(index, toState: .active)
        deleteSignButton?.isEnabled = true
    }
    
    open func passcodeLock(_ lock: PasscodeLockType, removedSignAtIndex index: Int) {
        
        animatePlacehodlerAtIndex(index, toState: .inactive)
        
        if index == 0 {
            
            deleteSignButton?.isEnabled = false
        }
    }
}
