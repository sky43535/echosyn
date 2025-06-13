import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth
import FirebaseMessaging
import UserNotifications

// MARK: - Models
struct User: Identifiable {
    var id: String
    var username: String
    var esid: String
    var flagged: Bool
    var banned: Bool
    var blockedESIDs: [String]
}

struct Chat: Identifiable {
    let id: String
    let otherUID: String
    let otherUsername: String
    let lastMessage: String?
    let timestamp: Date
    let flagged: Bool
    let timeout: Bool

    init(
        id: String,
        otherUID: String,
        otherUsername: String,
        lastMessage: String? = nil,
        timestamp: Date,
        flagged: Bool = false,
        timeout: Bool = false
    ) {
        self.id = id
        self.otherUID = otherUID
        self.otherUsername = otherUsername
        self.lastMessage = lastMessage
        self.timestamp = timestamp
        self.flagged = flagged
        self.timeout = timeout
    }
}

struct Message: Identifiable {
    var id: String
    var senderID: String
    var text: String
    var timestamp: Date
}

struct NotificationPost: Identifiable {
    var id: String
    var title: String
    var message: String
    var urgency: String
    var timestamp: Date
    var imageURL: String?
}

// MARK: - Main View
struct ContentView: View {
    // Splash, auth state
    @State private var newUsername: String = ""
    @State private var showSplash = true
    @State private var accessDenied = false
    @State private var isLoggedIn = false
    @State private var currentUser: User?
    @State private var showLogoutAlert = false
    @State private var showDeleteAlert = false
    @State private var showBlockConfirmation = false
    @State private var blockedUsers: [(id: String, username: String)] = []
    @State private var showUnblockConfirmation = false
    @State private var selectedBlockedUserToUnblock: (id: String, username: String)? = nil
    
    // Auth inputs
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var authError = ""
    @State var pin: String = ""
    
    // Chat and messaging
    @State private var scrollTarget: String?
    @State private var showingImagePicker = false
    @State private var pickedImage: UIImage?
    @State private var isFullScreenImage = false
    @State private var fullScreenImageURL: URL?
    @StateObject private var mapVM = MapViewModel()
    @State private var showingPinList = false
    @State private var chats: [Chat] = []
    @State private var selectedChat: Chat?
    @State private var messages: [Message] = []
    @State private var newMessage = ""
    @State private var esidToAdd = ""
    @State private var showESIDField = false
    @State private var userFlagged = false
    @State private var userTimeout = false
    // Notifications
    @State private var notifications: [NotificationPost] = []
    @State private var showNotifications = false
    @State private var notificationTitle = ""
    @State private var notificationMessage = ""
    @State private var notificationUrgency = "normal"
    @State private var notificationImageURL = ""
    
    let db = Firestore.firestore()
    
    var body: some View {
        ZStack {
            if showSplash {
                splashView
            } else if accessDenied {
                accessDeniedView
            } else if !isLoggedIn {
                authView
            } else if showNotifications {
                notificationPage
            } else if let chat = selectedChat {
                NavigationStack {
                    chatDetailView(chat)
                }
            } else {
                chatHomeView
            }
        }
        .onAppear {
            
            // Existing onAppear logic
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                showSplash = false
                if let user = Auth.auth().currentUser {
                    loadUser(uid: user.uid)
                }
            }
        }
    }
    
    
    
    // MARK: - Splash Screens
    var splashView: some View {
        LinearGradient(colors: [.blue, .black], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
            .overlay(
                VStack {
                    Spacer()
                    Text("ECHO SYNC")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.purple)
                    Text("connecting to servers...")
                        .foregroundColor(.purple)
                    Spacer()
                    Text("© Skyler 2025")
                        .foregroundColor(.mint)
                        .font(.footnote)
                }
            )
    }
    
    var accessDeniedView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack {
                Spacer()
                Text("ACCESS DENIED")
                    .font(.largeTitle)
                    .foregroundColor(.red)
                Text("This device is banned.")
                    .foregroundColor(.pink)
                Text("contact echosync at (952)652-7647 or skylerp530@gmail.com")
                    .font(.caption2)
                    .foregroundColor(.blue)
                Spacer()
            }
        }
    }
    
    // MARK: - Auth View
    var authView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                Text("the oficial login ")
                Text("updates coming (beta 1.0)")
                    .font(.caption2)
                    .foregroundColor(.blue)
                Text("ECHO SYNC")
                    .font(.largeTitle)
                    .bold()
                    .foregroundColor(.red)
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .foregroundColor(.pink)
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .foregroundColor(.pink)
                TextField("Username (if signing up)", text: $username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .foregroundColor(.pink)
                if !authError.isEmpty {
                    Text(authError)
                        .foregroundColor(.purple)
                        .font(.caption)
                }
                Text("Password gotta be: • 6 to 10 characters long • At least one UPPERCASE letter (make it shout!) • At least one special character (you know, like !@#$%) • At least one number (can’t forget those digits) Keep it tight, keep it safe — that’s the rule!")
                    .font(.caption)
                    .foregroundColor(.orange)
                Button("Sign Up") { signUp() }
                    .foregroundColor(.black)
                    .padding()
                    .background(Color.mint)
                    .cornerRadius(8)
                Button("Login") { login() }
                    .foregroundColor(.mint)
                Text("(click to read)")
                    .foregroundColor(.white)
                Text("By logging in, you agree to our")
                Link("Terms & Conditions", destination: URL(string: "https://echosync.carrd.co")!)
                Text("Stuck logging in? Give us a ring at (952)-652-7647. If no one picks up, no worries — try again later or just shoot us a text or email at skylerp530@gmail.com, and We got you!")
                    .font(.footnote)
                    .foregroundColor(.green)
            }
            .font(.footnote)
            .foregroundColor(.purple)
            .padding()
        }
    }
    
    // MARK: - Auth Logic
    func signUp() {
        authError = ""
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                authError = error.localizedDescription
                return
            }
            guard let uid = result?.user.uid else { return }
            let esid = "es\(Int.random(in: 10000...99999))"
            let userData: [String: Any] = [
                "username": username,
                "esid": esid,
                "flagged": false,
                "banned": false,
                "blockedESIDs": []
            ]
            db.collection("users").document(uid).setData(userData) { err in
                if err == nil {
                    currentUser = User(id: uid, username: username, esid: esid, flagged: false, banned: false, blockedESIDs: [])
                    showSplash = false
                    isLoggedIn = true
                    loadChats()
                    
                    
                    
                }
            }
        }
    }
    
    
    func login() {
        authError = ""
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if let error = error {
                authError = error.localizedDescription
                return
                showSplash = false
                
            }
            guard let uid = result?.user.uid else { return }
            loadUser(uid: uid)
        }
    }
    
    func loadUser(uid: String) {
        db.collection("users").document(uid).getDocument { snap, _ in
            guard let data = snap?.data() else { return }
            let banned = data["banned"] as? Bool ?? false
            if banned {
                accessDenied = true
                isLoggedIn = false
                return
            }
            let username = data["username"] as? String ?? "Unknown"
            let esid = data["esid"] as? String ?? "none"
            let flagged = data["flagged"] as? Bool ?? false
            let blockedList = data["blockedESIDs"] as? [String] ?? []
            currentUser = User(id: uid, username: username, esid: esid, flagged: flagged, banned: banned, blockedESIDs: blockedList)
            isLoggedIn = true
            loadChats()
        }
    }
    
    // MARK: - Chat Home View
    
    func fetchMyFlags() {
        guard let uid = currentUser?.id else { return }
        db.collection("users").document(uid).getDocument { snap, _ in
            let data = snap?.data() ?? [:]
            userFlagged = data["flagged"] as? Bool ?? false
            userTimeout = data["timeout"] as? Bool ?? false
        }
    }
    
    func deleteChat(at offsets: IndexSet) {
        for index in offsets {
            let chatToDelete = chats[index]
            db.collection("chats").document(chatToDelete.id).delete()
        }
    }
    
    func loadChats() {
        guard let uid = currentUser?.id else { return }
        db.collection("chats")
            .whereField("participants", arrayContains: uid)
            .addSnapshotListener { snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                var newChats: [Chat] = []
                let group = DispatchGroup()
                for doc in docs {
                    let data = doc.data()
                    let id = doc.documentID
                    let participants = data["participants"] as? [String] ?? []
                    let otherUID = participants.first { $0 != uid } ?? "unknown"
                    if currentUser?.blockedESIDs.contains(otherUID) == true { continue }
                    
                    let timestamp = (data["lastMessageTime"] as? Timestamp)?
                        .dateValue() ?? Date.distantPast
                    
                    group.enter()
                    db.collection("users").document(otherUID).getDocument { userSnap, _ in
                        defer { group.leave() }
                        guard let userData = userSnap?.data() else { return }
                        let otherBlocked = userData["blockedESIDs"] as? [String] ?? []
                        if otherBlocked.contains(uid) { return }
                        
                        let otherUsername = userData["username"] as? String ?? "Loading..."
                        let lastMsg       = data["lastMessage"] as? String
                        let flagged       = userData["flagged"]   as? Bool   ?? false
                        let timeout       = userData["timeout"]   as? Bool   ?? false
                        
                        newChats.append(
                            Chat(
                                id:            id,
                                otherUID:      otherUID,
                                otherUsername: otherUsername,
                                lastMessage:   lastMsg,
                                timestamp:     timestamp,
                                flagged:       flagged,
                                timeout:       timeout
                            )
                        )
                    }
                }
                group.notify(queue: .main) {
                    newChats.sort { $0.timestamp > $1.timestamp }
                    chats = newChats
                }
            }
    }
    
    func addChatByESID() {
        guard let uid = currentUser?.id else { return }
        db.collection("users")
            .whereField("esid", isEqualTo: esidToAdd)
            .getDocuments { snap, _ in
                guard let userDoc = snap?.documents.first else {
                    print("No user found for ESID: \(esidToAdd)")
                    return
                }
                let otherUID = userDoc.documentID
                if otherUID == uid {
                    print("Can’t chat with yourself.")
                    return
                }
                db.collection("users").document(otherUID).getDocument { userSnap, _ in
                    let otherData    = userSnap?.data() ?? [:]
                    let otherBlocked = otherData["blockedESIDs"] as? [String] ?? []
                    if otherBlocked.contains(uid)
                        || currentUser?.blockedESIDs.contains(otherUID) == true {
                        print("User is blocked or has blocked you")
                        return
                    }
                    db.collection("chats")
                        .whereField("participants", arrayContains: uid)
                        .getDocuments { existing, _ in
                            let exists = existing?.documents.contains {
                                let parts = $0["participants"] as? [String] ?? []
                                return parts.contains(otherUID)
                            } ?? false
                            let data: [String: Any] = [
                                "participants":    [uid, otherUID],
                                "lastMessage":     "",
                                "lastMessageTime": FieldValue.serverTimestamp()
                            ]
                            if !exists {
                                db.collection("chats").addDocument(data: data) { _ in
                                    loadChats()
                                }
                            } else {
                                loadChats()
                            }
                            esidToAdd = ""
                        }
                }
            }
    }
    
    // MARK: - Settings View
    
    var settingsView: some View {
        Form {
            // MARK: - Account Info Section
            Section(header: Text("Account Info").foregroundColor(.mint)) {
                HStack {
                    Image(systemName: "pencil.circle")
                        .foregroundColor(.pink)
                    TextField("Username", text: $newUsername)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                .onAppear {
                    newUsername = currentUser?.username ?? ""
                }
                Button(action: {
                    let trimmed = newUsername.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty, let uid = currentUser?.id else { return }
                    db.collection("users").document(uid).updateData([
                        "username": trimmed
                    ]) { _ in
                        currentUser?.username = trimmed
                    }
                }) {
                    Label("Update Username", systemImage: "checkmark.seal.fill")
                }
                .foregroundColor(.mint)
                
                HStack {
                    Image(systemName: "person.crop.circle")
                        .foregroundColor(.pink)
                    Text("ESID")
                    Spacer()
                    Text(currentUser?.esid ?? "")
                        .textSelection(.enabled)
                        .foregroundColor(.primary)
                }
                HStack {
                    Image(systemName: "number")
                        .foregroundColor(.pink)
                    Text("UID")
                    Spacer()
                    Text(currentUser?.id ?? "")
                        .textSelection(.enabled)
                        .foregroundColor(.primary)
                }
            }
            
            // MARK: - Actions Section
            Section(header: Text("Actions").foregroundColor(.mint)) {
                Button(action: {
                    showLogoutAlert = true
                }) {
                    Label("Sign Out", systemImage: "arrowshape.turn.up.left.fill")
                }
                .foregroundColor(.blue)
                .alert("Sign Out?", isPresented: $showLogoutAlert) {
                    Button("Sign Out", role: .destructive) {
                        try? Auth.auth().signOut()
                        isLoggedIn = false
                        currentUser = nil
                    }
                    Button("Cancel", role: .cancel) {}
                }
                
                Button(action: {
                    showDeleteAlert = true
                }) {
                    Label("Delete Account", systemImage: "trash.fill")
                }
                .foregroundColor(.red)
                .alert("Delete Account?", isPresented: $showDeleteAlert) {
                    Button("Delete", role: .destructive) {
                        guard let uid = currentUser?.id else { return }
                        db.collection("users").document(uid).delete { _ in
                            Auth.auth().currentUser?.delete { _ in
                                isLoggedIn = false
                                currentUser = nil
                            }
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("You must be recently logged in to delete your account. If it fails, please sign out and log in again first.")
                }
            }
            
            // MARK: - Support Section
            Section(header: Text("Support").foregroundColor(.mint)) {
                Button(action: {
                    if let url = URL(string: "https://forms.gle/B3Gw98aN5HRQgkHY7") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Label("Send Feedback", systemImage: "bubble.left.and.bubble.right.fill")
                }
                .foregroundColor(.blue)
                
                Button(action: {
                    if let url = URL(string: "https://forms.gle/SMUmfHkjVjZLtto7A") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Label("Report Issue", systemImage: "exclamationmark.bubble.fill")
                }
                .foregroundColor(.orange)
                
                Divider()
                
                if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                    Text("App Version: \(version)")
                        .foregroundColor(.gray)
                        .font(.footnote)
                }
            }
            
            // MARK: - Blocked List Section
            Section(header: Text("Blocked List").foregroundColor(.mint)) {
                if blockedUsers.isEmpty {
                    Text("No blocked users")
                        .foregroundColor(.gray)
                } else {
                    ForEach(blockedUsers, id: \.id) { user in
                        HStack {
                            Text(user.username)
                            Spacer()
                            Button {
                                selectedBlockedUserToUnblock = user
                                showUnblockConfirmation = true
                            } label: {
                                Image(systemName: "person.crop.circle.fill.badge.checkmark")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .listStyle(InsetGroupedListStyle())
        .onAppear {
            fetchBlockedUsers()
        }
        .alert("Unblock User?", isPresented: $showUnblockConfirmation) {
            Button("Unblock", role: .destructive) {
                if let user = selectedBlockedUserToUnblock, let currentUID = currentUser?.id {
                    db.collection("users").document(currentUID).updateData([
                        "blockedESIDs": FieldValue.arrayRemove([user.id])
                    ]) { error in
                        if error == nil {
                            fetchBlockedUsers()
                        }
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to unblock \(selectedBlockedUserToUnblock?.username ?? "this user")?\n\nNote: You may need to restart the app for the chat to show back up.")
        }
    }
    
    // MARK: - Helper: Fetch Blocked Users
    func fetchBlockedUsers() {
        guard let uid = currentUser?.id else { return }
        db.collection("users").document(uid).getDocument { snap, _ in
            let data = snap?.data() ?? [:]
            let blockedESIDs = data["blockedESIDs"] as? [String] ?? []
            blockedUsers = []
            for blockedUID in blockedESIDs {
                db.collection("users").document(blockedUID).getDocument { snap2, _ in
                    let username = snap2?.data()?["username"] as? String ?? "Unknown"
                    blockedUsers.append((id: blockedUID, username: username))
                }
            }
        }
    }
    @MainActor
    var chatHomeView: some View {
        NavigationView {
            ZStack {
                LinearGradient(colors: [.blue, .black],
                               startPoint: .top,
                               endPoint: .bottom)
                .ignoresSafeArea()
                
                VStack(spacing: 10) {
                    List {
                        ForEach(chats) { chat in
                            Button {
                                selectedChat = chat
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(chat.otherUsername)
                                        .foregroundColor(.pink)
                                    if let msg = chat.lastMessage {
                                        Text(msg)
                                            .font(.caption)
                                            .foregroundColor(.pink.opacity(0.7))
                                    }
                                }
                            }
                        }
                        .onDelete(perform: deleteChat)
                    }
                    
                    HStack {
                        if showESIDField {
                            TextField("(example 'es12345')", text: $esidToAdd)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .foregroundColor(.pink)
                        }
                        Button {
                            withAnimation { showESIDField.toggle() }
                        } label: {
                            Image(systemName:
                                    showESIDField
                                  ? "xmark.seal.fill"
                                  : "person.crop.circle.fill.badge.plus"
                            )
                            .foregroundColor(.mint)
                            .imageScale(.large)
                            .padding(.horizontal, 6)
                        }
                        if showESIDField {
                            Button {
                                addChatByESID()
                            } label: {
                                Image(systemName: "plus.bubble.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.black)
                                    .padding(.horizontal)
                                    .background(Color.mint)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding()
                    
                    HStack {
                        Button {
                            fetchNotifications()
                            showNotifications = true
                        } label: {
                            Image(systemName: "bell.fill")
                                .foregroundColor(.mint)
                                .imageScale(.large)
                        }
                        Spacer()
                        
                        NavigationLink(destination: WeatherView()) {
                            Image(systemName: "cloud.sun.fill")
                                .foregroundColor(.pink)
                                .imageScale(.large)
                                .padding(.trailing, 4)
                        }
                        
                        NavigationLink(destination: MapView()) {
                            Image(systemName: "map.fill")
                                .foregroundColor(.pink)
                                .imageScale(.large)
                                .padding(.trailing, 4)
                        }
                        
                        NavigationLink(destination: settingsView) {
                            Image(systemName: "gearshape.fill")
                                .foregroundColor(.mint)
                                .imageScale(.large)
                                .padding()
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Image(systemName:
                            userFlagged
                          ? "lock.trianglebadge.exclamationmark.fill"
                          : userTimeout
                          ? "lock.badge.clock.fill"
                          : "lock.open.fill"
                    )
                    .foregroundColor(.pink)
                }
            }
            .onAppear {
                fetchMyFlags()
                loadChats()
                
            }
        }
    }
    // Add these at the top of your ChatDetailView container:
    
    
    // MARK: - Chat Detail View
    
    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    func loadMessages(for chat: Chat) {
        db.collection("chats")
            .document(chat.id)
            .collection("messages")
            .order(by: "timestamp")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error loading messages: \(error.localizedDescription)")
                    return
                }
                guard let documents = snapshot?.documents else { return }
                messages = documents.compactMap { doc in
                    let data = doc.data()
                    return Message(
                        id: doc.documentID,
                        senderID: data["senderID"] as? String ?? "",
                        text: data["text"] as? String ?? "",
                        timestamp: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                    )
                }
            }
    }
    
    func sendMessage(to chat: Chat) {
        guard let uid = currentUser?.id else { return }
        // Check blocks...
        let messageText = newMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !messageText.isEmpty else { return }
        let timestamp = Timestamp()
        let data: [String: Any] = [
            "text": messageText,
            "senderID": uid,
            "timestamp": timestamp
        ]
        let chatRef = db.collection("chats").document(chat.id)
        chatRef.collection("messages").addDocument(data: data) { error in
            if error == nil {
                chatRef.updateData([
                    "lastMessage": messageText,
                    "lastMessageSender": uid,
                    "lastMessageTime": timestamp
                ])
            }
        }
        newMessage = ""
    }
    
    func sendPin(_ pin: MapPin, to chat: Chat) {
        guard let uid = currentUser?.id else { return }
        let messageText = "pin shared \(pin.name) at \(pin.address)"
        let timestamp = Timestamp()
        let data: [String: Any] = [
            "text": messageText,
            "senderID": uid,
            "timestamp": timestamp
        ]
        let chatRef = db.collection("chats").document(chat.id)
        chatRef.collection("messages").addDocument(data: data) { error in
            if error == nil {
                chatRef.updateData([
                    "lastMessage": messageText,
                    "lastMessageSender": uid,
                    "lastMessageTime": timestamp
                ])
            }
        }
    }
    
    func chatDetailView(_ chat: Chat) -> some View {
        ScrollViewReader { scrollProxy in
            VStack {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        var lastDate: Date? = nil
                        ForEach(messages) { message in
                            let isNewDay: Bool = {
                                defer { lastDate = message.timestamp }
                                guard let previous = lastDate else { return true }
                                return !Calendar.current.isDate(previous, inSameDayAs: message.timestamp)
                            }()
                            VStack(
                                alignment: message.senderID == currentUser?.id ? .trailing : .leading,
                                spacing: 4
                            ) {
                                if isNewDay {
                                    Text(formattedDate(message.timestamp))
                                        .font(.caption)
                                        .foregroundColor(.pink.opacity(0.8))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 4)
                                }
                                Text(message.text)
                                    .padding()
                                    .background(
                                        message.senderID == currentUser?.id ? Color.blue : Color.orange
                                    )
                                    .cornerRadius(10)
                                    .foregroundColor(.black)
                                Text(message.timestamp, style: .time)
                                    .font(.caption2)
                                    .foregroundColor(.pink.opacity(0.7))
                            }
                            .frame(
                                maxWidth: .infinity,
                                alignment: message.senderID == currentUser?.id ? .trailing : .leading
                            )
                            .id(message.id)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Message input + buttons
                HStack {
                    TextField("Type a message", text: $newMessage)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .foregroundColor(.pink)
                    
                    // Share pin button
                    Button {
                        showingPinList = true
                    } label: {
                        Image(systemName: "mappin.and.ellipse.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.pink)
                    }
                    .padding(.leading, 8)
                    
                    // Send message button
                    Button {
                        sendMessage(to: chat)
                    } label: {
                        Image(systemName: "paperplane.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.mint)
                    }
                    .padding(.leading, 8)
                }
                .padding()
                
                Divider()
                
                // Block button
                HStack {
                    Spacer()
                    Button(action: {
                        showBlockConfirmation = true
                    }) {
                        Image(systemName: "person.crop.circle.fill.badge.xmark")
                            .font(.system(size: 24))
                            .foregroundColor(.red)
                    }
                    .alert("Block User?", isPresented: $showBlockConfirmation) {
                        Button("Block", role: .destructive) {
                            blockUser(uid: chat.otherUID)
                        }
                        Button("Cancel", role: .cancel) {}
                    }
                }
                .padding(.horizontal)
            }
            .navigationBarBackButtonHidden(true)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 4) {
                        Button(action: { selectedChat = nil }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.mint)
                        }
                        Text(chat.otherUsername)
                            .font(.headline)
                            .foregroundColor(.red)
                    }
                }
            }
            .onAppear {
                loadMessages(for: chat)
            }
            .onChange(of: messages.count) { _ in
                if let last = messages.last {
                    withAnimation {
                        scrollProxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            // Pin list sheet
            .sheet(isPresented: $showingPinList) {
                NavigationView {
                    List(mapVM.pins) { pin in
                        Button(action: {
                            sendPin(pin, to: chat)
                            showingPinList = false
                        }) {
                            VStack(alignment: .leading) {
                                Text(pin.name)
                                    .foregroundColor(.pink)
                                Text(pin.address)
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                    .navigationTitle("Select a Pin")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                showingPinList = false
                            }
                            .foregroundColor(.pink)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Block User
    func blockUser(uid: String) {
        guard let currentUID = currentUser?.id else { return }
        db.collection("users")
            .document(currentUID)
            .updateData(["blockedESIDs": FieldValue.arrayUnion([uid])]) { error in
                if let error = error {
                    print("Error blocking user: \(error.localizedDescription)")
                } else {
                    currentUser?.blockedESIDs.append(uid)
                    print("User \(uid) has been blocked.")
                    selectedChat = nil
                    loadChats()
                }
            }
    }
    
    
    // MARK: - Notifications Page
    var notificationPage: some View {
        ZStack {
            LinearGradient(colors: [.blue, .black], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack {
                Text("Global Notifications")
                    .font(.title2)
                    .foregroundColor(.yellow)
                List(notifications) { note in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(note.title)
                            .font(.headline)
                            .foregroundColor(note.urgency == "urgent" ? .mint : .pink)
                        Text(note.message)
                            .foregroundColor(.white)
                        Text(note.timestamp, style: .date)
                            .font(.caption)
                            .foregroundColor(.gray)
                        if let urlStr = note.imageURL, let url = URL(string: urlStr) {
                            AsyncImage(url: url) { phase in
                                if let img = phase.image {
                                    img
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .cornerRadius(8)
                                } else {
                                    ProgressView()
                                }
                            }
                            .frame(height: 120)
                        }
                    }
                    .padding(.vertical, 4)
                }
                Button("Back") {
                    showNotifications = false
                }
                .foregroundColor(.mint)
                .padding()
            }
        }
    }
    
    func fetchNotifications() {
        db.collection("notifications").order(by: "timestamp", descending: true)
            .getDocuments { snap, _ in
                guard let docs = snap?.documents else { return }
                notifications = docs.map { doc in
                    let d = doc.data()
                    let title = d["title"] as? String ?? ""
                    let message = d["message"] as? String ?? ""
                    let urgency = d["urgency"] as? String ?? "normal"
                    let timestamp = (d["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                    let imageURL = d["imageURL"] as? String
                    return NotificationPost(
                        id: doc.documentID,
                        title: title,
                        message: message,
                        urgency: urgency,
                        timestamp: timestamp,
                        imageURL: imageURL
                    )
                    
                }
            }
    }
}

