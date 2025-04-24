//
//  UnlockDetectionManager.swift
//  boringNotch
//
//  Created on 4/23/2025.
//

import Foundation
import Combine
import SwiftUI

class UnlockDetectionManager: ObservableObject {
    @Published var isUnlocked: Bool = false
    private var observers: [NSObjectProtocol] = []
    
    init() {
        setupObservers()
    }
    
    private func setupObservers() {
        // Observe screen unlock notifications
        let unlockObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleUnlock()
        }
        
        observers.append(unlockObserver)
        
        // Also observe session activation as a backup method
        let sessionObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleUnlock()
        }
        
        observers.append(sessionObserver)
        
        // Additional notification that might be triggered on unlock
        let didUnlockObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleUnlock()
        }
        
        observers.append(didUnlockObserver)
    }
    
    private func handleUnlock() {
        // Set isUnlocked to true to trigger the animation
        isUnlocked = true
        
        // Reset after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.isUnlocked = false
        }
    }
    
    deinit {
        // Remove observers when the manager is deallocated
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }
}