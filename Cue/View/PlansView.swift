//
//  PlansView.swift
//  Cue
//
//  Created by Kinsee Nyland on 2/10/26.
//

import SwiftUI

struct PlansView: View {
    @State private var plans: [DraftPlan] = [
        DraftPlan(
            title: "Hot Pilates - Core",
            type: .pilates,
            difficulty: .medium,
            durationMinutes: 60,
            movements: ["Savasana", "Mountain Climbers", "Plank", "Cool Down"]
        )
    ]
    @State private var isPresentingForm = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ZStack(alignment: .bottomLeading) {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [Color.orange.opacity(0.9), Color.orange.opacity(0.4)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(height: 180)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Build your next class")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("Share plans in seconds")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        .padding(16)
                    }

                    ForEach(plans) { plan in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(plan.title)
                                .font(.title2).bold()

                            Text(plan.summaryLine)
                                .foregroundStyle(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(plan.movements, id: \.self) { movement in
                                HStack {
                                    Text(movement)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(12)
                            }
                        }

                        Button("Start Workout") {}
                            .frame(maxWidth: .infinity)
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                            .padding(.top, 8)
                    }
                }
                .padding()
            }
            .navigationTitle("Create + Share Plans")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        isPresentingForm = true
                    } label: {
                        Image(systemName: "plus")
                    }

                    Button {
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .sheet(isPresented: $isPresentingForm) {
            NavigationStack {
                WorkoutPlanFormView { newPlan in
                    plans.insert(newPlan, at: 0)
                }
            }
        }
    }
}

#Preview {
    PlansView()
}
