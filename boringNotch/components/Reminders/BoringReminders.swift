//
//  BoringReminders.swift
//  boringNotch
//
//  Created on 4/21/2025.
//

import SwiftUI
import EventKit
import Defaults

struct BoringReminders: View {
    @StateObject private var remindersManager = RemindersManager()
    @State private var showAddReminderPopup = false
    @State private var newReminderTitle = ""
    @State private var newReminderDueDate: Date = Date()
    @State private var showDatePicker = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Header with title and controls
            HStack {
                Text("Reminders")
                    .font(.system(size: 18))
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Toggle for showing completed reminders
                Button(action: {
                    remindersManager.toggleCompletionFilter()
                }) {
                    Image(systemName: remindersManager.showCompleted ? "checkmark.circle.fill" : "checkmark.circle")
                        .foregroundColor(remindersManager.showCompleted ? Defaults[.accentColor] : .gray)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Toggle Completed Reminders")
                
                // Add new reminder button
                Button(action: {
                    showAddReminderPopup = true
                }) {
                    Image(systemName: "plus.circle")
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Add New Reminder")
            }
            
            // Reminders list
            if remindersManager.reminders.isEmpty {
                EmptyRemindersView()
            } else {
                ReminderListView(reminders: remindersManager.reminders, toggleCompletion: remindersManager.toggleReminderCompletion)
            }
        }
        .popover(isPresented: $showAddReminderPopup) {
            AddReminderView(
                isPresented: $showAddReminderPopup,
                createReminder: { title, date in
                    let success = remindersManager.createReminder(title: title, dueDate: date)
                    if success {
                        showAddReminderPopup = false
                        newReminderTitle = ""
                    }
                    return success
                },
                openRemindersApp: {
                    remindersManager.openRemindersApp()
                    showAddReminderPopup = false
                }
            )
        }
    }
}

struct EmptyRemindersView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle")
                .font(.largeTitle)
                .foregroundColor(.gray)
            Text("No reminders")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Add a reminder to get started")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ReminderListView: View {
    let reminders: [EKReminder]
    let toggleCompletion: (EKReminder) -> Void
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(reminders, id: \.calendarItemIdentifier) { reminder in
                    ReminderRow(reminder: reminder, toggleCompletion: toggleCompletion)
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

struct ReminderRow: View {
    let reminder: EKReminder
    let toggleCompletion: (EKReminder) -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button(action: {
                toggleCompletion(reminder)
            }) {
                Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(reminder.isCompleted ? .green : .gray)
            }
            .buttonStyle(PlainButtonStyle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.title)
                    .font(.footnote)
                    .foregroundStyle(reminder.isCompleted ? .gray : .white)
                    .strikethrough(reminder.isCompleted)
                
                if let dueDateComponents = reminder.dueDateComponents,
                   let dueDate = Calendar.current.date(from: dueDateComponents) {
                    Text(dueDate, style: .date)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .opacity(reminder.isCompleted ? 0.6 : 1)
    }
}

struct AddReminderView: View {
    @Binding var isPresented: Bool
    let createReminder: (String, Date?) -> Bool
    let openRemindersApp: () -> Void
    
    @State private var title = ""
    @State private var notes = ""
    @State private var includeDueDate = false
    @State private var dueDate = Date()
    
    var body: some View {
        VStack(spacing: 16) {
            Text("New Reminder")
                .font(.headline)
            
            TextField("Title", text: $title)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            Toggle("Include Due Date", isOn: $includeDueDate)
            
            if includeDueDate {
                DatePicker("Due Date", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(CompactDatePickerStyle())
            }
            
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                
                Spacer()
                
                Button("Open Reminders App") {
                    openRemindersApp()
                }
                
                Button("Add") {
                    if !title.isEmpty {
                        let _ = createReminder(title, includeDueDate ? dueDate : nil)
                    }
                }
                .disabled(title.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 300)
    }
}

#Preview {
    BoringReminders()
        .frame(width: 250)
        .padding(.horizontal)
        .background(.black)
}