//
//  RemindersManager.swift
//  boringNotch
//
//  Created on 4/21/2025.
//

import EventKit
import SwiftUI
import Defaults
import Combine

class RemindersManager: ObservableObject {
    @Published var reminders: [EKReminder] = []
    @Published var showCompleted: Bool = false
    private let eventStore = EKEventStore()
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    
    init() {
        checkRemindersAuthorization()
    }
    
    func checkRemindersAuthorization() {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        DispatchQueue.main.async {
            self.authorizationStatus = status
        }
        
        switch status {
            case .authorized, .fullAccess:
                fetchReminders()
            case .notDetermined:
                requestRemindersAccess()
            case .restricted, .denied, .writeOnly:
                // Handle the case where the user has denied or restricted access
                NSLog("Reminders access denied or restricted")
            @unknown default:
                print("Unknown authorization status")
        }
    }
    
    func requestRemindersAccess() {
        eventStore.requestFullAccessToReminders { [weak self] granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Reminders access error: \(error.localizedDescription)")
                }
                
                self?.authorizationStatus = granted ? .fullAccess : .denied
                if granted {
                    print("Reminders access granted")
                    self?.fetchReminders()
                } else {
                    print("Reminders access denied")
                }
            }
        }
    }
    
    func fetchReminders() {
        let predicate = eventStore.predicateForReminders(in: nil)
        
        eventStore.fetchReminders(matching: predicate) { [weak self] fetchedReminders in
            guard let reminders = fetchedReminders else { return }
            
            // Ensure we are on the main thread when updating UI
            DispatchQueue.main.async(execute: DispatchWorkItem(block: {
                if let strongSelf = self {
                    strongSelf.reminders = reminders
                        .filter { strongSelf.showCompleted || !$0.isCompleted }
                        .sorted(by: {
                            let date1 = strongSelf.getDueDate(for: $0)
                            let date2 = strongSelf.getDueDate(for: $1)
                            return date1 < date2
                        })
                }
            }))
        }
    }
    
    // Helper function to get the due date from an EKReminder
    private func getDueDate(for reminder: EKReminder) -> Date {
        if let dueDateComponents = reminder.dueDateComponents,
           let dueDate = Calendar.current.date(from: dueDateComponents) {
            return dueDate
        }
        return Date.distantFuture
    }
    

    func toggleCompletionFilter() {
        showCompleted.toggle()
        fetchReminders()
    }
    
    func toggleReminderCompletion(_ reminder: EKReminder) {
        reminder.isCompleted = !reminder.isCompleted
        
        do {
            try eventStore.save(reminder, commit: true)
            fetchReminders()
        } catch {
            print("Error toggling reminder completion: \(error)")
        }
    }
    
    func createReminder(title: String, notes: String? = nil, dueDate: Date? = nil, list: EKCalendar? = nil) -> Bool {
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        reminder.notes = notes
        
        if let dueDate = dueDate {
            reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
        }
        
        reminder.calendar = list ?? eventStore.defaultCalendarForNewReminders()
        
        do {
            try eventStore.save(reminder, commit: true)
            fetchReminders()
            return true
        } catch {
            print("Error creating reminder: \(error)")
            return false
        }
    }
    
    func openRemindersApp() {
        if let url = URL(string: "x-apple-reminderkit://") {
            NSWorkspace.shared.open(url)
        }
    }
}
