//
//  FirebaseHandler.swift
//  Registrar
//
//  Created by Ezekiel Abuhoff on 10/11/24.
//

import Foundation
import Combine
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth
import GoogleSignIn

enum FirebaseHandler {
    enum Failure: Error {
        case unknown
        case signInNeeded
        case firebase(Error)
    }

    struct DatabaseKey {
        private init() {}
        
        static let event = "events"
    }

    static var firestore: Firestore!
    static var currentUser: User? {
        Auth.auth().currentUser
    }
    static var userIsAnonymous: Bool {
        currentUser?.isAnonymous ?? false
    }

    static var actionCodeSettings = {
        let actionCodeSettings = ActionCodeSettings()
        actionCodeSettings.url = URL(string: "https://www.example.com")
        actionCodeSettings.handleCodeInApp = true
        actionCodeSettings.setIOSBundleID(Bundle.main.bundleIdentifier!)
        return actionCodeSettings
    }()

    static func startUp() {
        FirebaseApp.configure()
        firestore = Firestore.firestore()
    }

    // MARK: - Sign In
    static func signInWithGoogle() -> Future<Bool, Error> {
        if GIDSignIn.sharedInstance.hasPreviousSignIn() {
            return refreshSignInWithGoogle()
        } else {
            return initiateFreshSignInWithGoogle()
        }
    }

    private static func refreshSignInWithGoogle() -> Future<Bool, Error> {
        Future { promise in
            GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
                if let error = error {
                    promise(Result.failure(Failure.firebase(error)))
                    return
                }
                guard user != nil else {
                    promise(Result.failure(Failure.unknown))
                    return
                }

                promise(Result.success(true))
            }
        }
    }

    private static func initiateFreshSignInWithGoogle() -> Future<Bool, Error> {
        Future { promise in
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController,
                  let clientID = FirebaseApp.app()?.options.clientID
            else {
                promise(Result.failure(Failure.unknown))
                return
            }

            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

            GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { result, error in
                guard error == nil,
                      let user = result?.user,
                      let idToken = user.idToken?.tokenString
                else {
                    promise(Result.failure(Failure.unknown))
                    return
                }

                let signInCredential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                                 accessToken: user.accessToken.tokenString)
                completeSignIn(with: signInCredential, promise: promise)
            }
        }
    }

    private static func completeSignIn(with credential: AuthCredential,
                                       promise: @escaping (Result<Bool, Error>) -> Void
    ) {
        Auth.auth().signIn(with: credential) { result, error in
            if let error = error {
                promise(Result.failure(Failure.firebase(error)))
                return
            }
            promise(Result.success(true))
        }
    }

    // MARK: - Events
    static func createEvent(_ draft: Event.Draft) -> Future<Bool, Error> {
        Future { promise in
            guard let currentUserID = currentUser?.uid else { promise(Result.failure(Failure.signInNeeded)); return }

            var formattedDraft = draft.asDictionary()
            formattedDraft[Event.DatabaseKey.creator] = currentUserID

            firestore.collection(DatabaseKey.event).document()
                .setData(formattedDraft) { error in
                    if let error = error {
                        promise(Result.failure(error))
                        return
                    }
                    promise(Result.success(true))
                }
        }
    }

    static func getMyEvents() -> Future<[Event], Error> {
        Future { promise in
            guard let currentUserID = currentUser?.uid else { promise(Result.failure(Failure.signInNeeded)); return }

            firestore
                .collection(DatabaseKey.event)
                .whereField(Event.DatabaseKey.creator, isEqualTo: currentUserID)
                .getDocuments { querySnapshot, err in
                    guard let querySnapshot = querySnapshot else {
                        promise(Result.failure(Failure.unknown))
                        return
                    }
                    let events: [Event] = querySnapshot.documents.compactMap { document in
                        try? document.data(as: Event.self)
                    }
                    promise(Result.success(events))
                }
        }
    }

    static func joinEvent(_ eventID: String) -> Future<Bool, Error> {
        Future { promise in
            Task {
                guard let currentUserID = currentUser?.uid else { promise(Result.failure(Failure.signInNeeded)); return }

                let eventRef = firestore.collection(DatabaseKey.event).document(eventID)

                eventRef.updateData([Event.DatabaseKey.attending: FieldValue.arrayUnion([currentUserID])])

//                let result = runTransaction { transaction, errorPointer in
//                    let eventSnapshot: DocumentSnapshot
//                    try eventSnapshot = transaction.getDocument(eventRef)
//
//                    guard let oldAttending = eventSnapshot.data()?["attending"] as? [String] else {
//                        let error = NSError(
//                            domain: "AppErrorDomain",
//                            code: -1,
//                            userInfo: [
//                                NSLocalizedDescriptionKey: "Unable to retrieve population from snapshot \(eventSnapshot)"
//                            ]
//                        )
//                        errorPointer?.pointee = error
//                        return
//                    }
//
//                    transaction.updateData(["attending": oldAttending + [currentUserID]], forDocument: eventRef)
//
//                    guard errorPointer?.pointee == nil else { throw Failure.unknown }
//                }
            }
        }
    }

//    static func createTicket(_ draft: TicketDraft) -> AnyPublisher<Bool, Error> {
//        Future { promise in
//            guard let currentUserID = currentUser?.uid else { promise(Result.failure(Failure.signInNeeded)); return }
//
//            var formattedDraft = draft.asDictionary()
//            formattedDraft["assignee"] = currentUserID
//
//            firestore.collection(ticketKey).document()
//                .setData(formattedDraft) { error in
//                    if let error = error {
//                        promise(Result.failure(error))
//                        return
//                    }
//                    promise(Result.success(true))
//                }
//        }.eraseToAnyPublisher()
//    }
//
//    static func getTickets() -> AnyPublisher<[Ticket], Error> {
//        Future { promise in
//            guard let currentUserID = currentUser?.uid else { promise(Result.failure(Failure.signInNeeded)); return }
//
//            firestore
//                .collection(ticketKey)
//                .whereField("assignee", isEqualTo: currentUserID)
//                .getDocuments { querySnapshot, err in
//                    guard let querySnapshot = querySnapshot else {
//                        promise(Result.failure(Failure.unknown))
//                        return
//                    }
//                    let tickets: [Ticket] = querySnapshot.documents.compactMap { document in
//                        try? document.data(as: Ticket.self)
//                    }
//                    promise(Result.success(tickets))
//                }
//        }.eraseToAnyPublisher()
//    }

    static func signIn(email: String) -> Future<String, Error> {
        Future { promise in
            Auth.auth().sendSignInLink(toEmail: email, actionCodeSettings: actionCodeSettings) { error in
                if let error = error {
                    promise(Result.failure(error))
                    return
                }
                promise(Result.success(email))
            }
        }
    }

    static func signInAnonymously() -> Future<Bool, Error> {
        Future { promise in
            Auth.auth().signInAnonymously() { authResult, error in
                if let error = error {
                    promise(Result.failure(error))
                    return
                }
                promise(Result.success(currentUser?.isAnonymous ?? true))
            }
        }
    }
}

extension FirebaseHandler {
    private static func runTransaction(
        _ action: @escaping (Transaction, ErrorPointer) throws -> ()
    ) -> Future<Bool, Error> {
        Future { promise in
            Task {
                var errorToThrow: Error?
                let _ = try await firestore.runTransaction { transaction, errorPointer in
                    do { try action(transaction, errorPointer) } catch { errorToThrow = error }
                    return nil
                }
                if let errorToThrow { promise(.failure(errorToThrow)) }
                promise(.success(true))
            }
        }
    }

    private static func experiment() -> Future<Bool, Error> {
        Future { promise in
            Task { let _ = try await throwingThing() }
            promise(.success(true))
        }
    }

    private static func throwingThing() async throws -> Bool {
        if true {
            return true
        } else {
            throw Failure.signInNeeded
        }
    }
}
