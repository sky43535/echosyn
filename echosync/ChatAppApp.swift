//
//  ChatAppApp.swift
//  ChatApp
//
//  Created by Owner on 5/19/25.
//
import Firebase
import SwiftUI
import Firebase

@main
struct ChatAppApp: App {
  
 
    // Initialize Firebase when the app launches
    init() {
        FirebaseApp.configure() 
    
       
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
