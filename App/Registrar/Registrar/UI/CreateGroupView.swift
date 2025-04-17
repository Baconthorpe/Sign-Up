//
//  CreateGroupView.swift
//  Registrar
//
//  Created by Ezekiel Abuhoff on 4/8/25.
//

import SwiftUI
import Combine

struct CreateGroupView: View {
    @Binding var path: NavigationPath

    @State var name: String = ""
    @State var description: String = ""
    @State var invalid: Bool = false

    @State var cancellables = Set<AnyCancellable>()

    var body: some View {
        VStack {
            HStack{
                Text("Name: ")
                    .foregroundStyle(invalid ? .red : .primary)
                TextField("Scooby Gang", text: $name)
                    .onChange(of: name) { invalid = false }
            }
            HStack{
                Text("Description: ")
                TextField("Keeping Sunnydale safe", text: $description)
            }
            Button {
                createGroup()
            } label: {
                Text("Create Group")
            }
        }
    }

    func createGroup() {
        guard !name.isEmpty else {
            invalid = true
            return
        }

        Provide.createGroup(
            name: name,
            description: description
        ).sink { completion in
            if case let .failure(error) = completion {
                log("Create Group Failed: \(error)")
            }
        } receiveValue: { groupCreated in
            log("Group created: \(groupCreated)", level: .verbose)
            path.removeLast()
        }.store(in: &cancellables)
    }
}
