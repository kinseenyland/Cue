//
//  PlansView.swift
//  Cue
//
//  Created by Kinsee Nyland on 2/10/26.
//

import SwiftUI

struct PlansView: View {
    private let movements = [
        "Savasana",
        "Mountain Climbers",
        "Plank",
        "Cool Down"
    ]

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

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Hot Pilates - Core")
                            .font(.title2).bold()

                        Text("Type: Pilates • Difficulty: Medium • Time: 60 mins")
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(movements, id: \.self) { movement in
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
                .padding()
            }
            .navigationTitle("Create + Share Plans")
            .toolbar {
                Button {
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
    }
}

#Preview {
    PlansView()
}
