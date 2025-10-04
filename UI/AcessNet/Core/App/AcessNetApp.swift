//
//  AcessNetApp.swift
//  AcessNet
//
//  Created by Emilio Cruz Vargas on 21/09/25.
//

import SwiftUI
import UserNotifications

@main
struct AcessNetApp: App {
    private let notificationHandler = NotificationHandler()

    init() {
        UNUserNotificationCenter.current().delegate = notificationHandler
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
