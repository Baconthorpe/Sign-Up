//
//  Event.swift
//  Registrar
//
//  Created by Ezekiel Abuhoff on 10/18/24.
//

struct Event: Codable, Identifiable {

    let id: Int
    let creator: String
    let title: String
    let attending: [String]

    struct DatabaseKey {
        private init() {}

        static let creator = "creator"
        static let title = "title"
        static let attending = "attending"
    }

    struct Draft {
        let title: String
        let description: String
        let attending: [String] = []

        func asDictionary() -> [String: Any] {
            ["title": title,
             "description": description,
             "attending" : attending]
        }
    }
}
