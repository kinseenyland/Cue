//
//  ContentView.swift
//  Cue
//
//  Created by Kinsee Nyland on 1/29/26.
//

import SwiftUI

struct ContentView: View {
    @State private var vm = CueViewModel()

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {

                HStack {
                    Text("Cue")
                        .font(.largeTitle).bold()

                    Spacer()

                    Button("+ Sample Plan") {
                        Task { await vm.addSamplePlan() }
                    }
                    .buttonStyle(.borderedProminent)
                }

                if let status = vm.statusMessage {
                    Text(status).foregroundStyle(.green)
                }

                if let error = vm.errorMessage {
                    Text(error).foregroundStyle(.red)
                }

                Text("My Plans").font(.headline)

                if vm.plans.isEmpty {
                    Text("No plans yet. Tap + Sample Plan.")
                        .foregroundStyle(.secondary)
                } else {
                    List(vm.plans) { plan in
                        VStack(alignment: .leading) {
                            Text(plan.title).font(.headline)
                            Text("\(plan.type.rawValue.capitalized) • \(plan.difficulty.rawValue.capitalized)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()
            }
            .padding()
            .task {
                await vm.fetchPlans()
            }
        }
    }
}


//#Preview {
//    ContentView()
//        .modelContainer(for: Item.self, inMemory: true)
//}
