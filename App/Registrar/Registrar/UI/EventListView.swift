//
//  EventListView.swift
//  Registrar
//
//  Created by Ezekiel Abuhoff on 4/7/25.
//

import SwiftUI
import Combine

struct EventListView: View {
    @EnvironmentObject var navigation: Navigation

    @State var events: [Event] = []

    @State var cancellables = Set<AnyCancellable>()
    @State var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            VStack {
                Text("EVENTS")
                
                List {
                    ForEach(events) { event in
                        NavigationLink(value: event) { Text(event.title) }
                    }
                }.onAppear(perform: getEvents)
                    .navigationDestination(for: Event.self) { event in
                        EventDetailsView(event: event)
                    }

                NavigationLink("Create Event", value: true)
                    .navigationDestination(for: Bool.self) { _ in
                        CreateEventView(path: $path)
                    }
                
                Button {
                    navigation.location = .createGroup
                } label: {
                    Text("Create Group")
                }
            }
        }
    }

    func getEvents() {
        Provide.getMyEvents().sink { completion in
            if case let .failure(error) = completion {
                log("Get Events Failed: \(error)")
            }
        } receiveValue: { events in
            log("Get Events Succeeded - count: \(events.count)", level: .verbose)
            self.events = events
        }.store(in: &cancellables)
    }
}
