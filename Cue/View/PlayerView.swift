//
//  PlayerView.swift
//  Cue
//
//  Created by Kinsee Nyland on 2/10/26.
//

import SwiftUI

struct PlayerView: View {
    @State private var currentIndex = 0
    @State private var isPaused = false
    @State private var isShowingAlert = false
    @State private var alertMessage = ""

    private let moves = ["Plank", "Weighted Lunge", "Mountain Climbers", "Cool Down"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hot Pilates Core")
                        .font(.title3).bold()

                    ProgressView(value: progressValue)
                        .tint(.orange)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(currentMove)
                            .font(.title2).bold()
                        Text("Focus on form and breath.")
                            .foregroundStyle(.secondary)
                        HStack(spacing: 4) {
                            Image(systemName: "timer")
                            Text("0:29 remaining")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text("0:29")
                        .font(.system(size: 44, weight: .bold))
                        .monospacedDigit()
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)

                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "music.note")
                        Text("Not Like Us")
                            .font(.headline)
                        Spacer()
                        Image(systemName: "airpodspro")
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 16) {
                        Button {
                            alertMessage = "Previous track"
                            isShowingAlert = true
                        } label: {
                            Image(systemName: "backward.fill")
                        }

                        Button {
                            isPaused.toggle()
                        } label: {
                            Image(systemName: isPaused ? "play.fill" : "pause.fill")
                        }
                        .font(.title2)

                        Button {
                            alertMessage = "Next track"
                            isShowingAlert = true
                        } label: {
                            Image(systemName: "forward.fill")
                        }

                        Spacer()

                        Text("1:30")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)

                Spacer()

                HStack(spacing: 12) {
                    Button("Next Move") {
                        advanceMove()
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.bordered)

                    Button {
                        isPaused.toggle()
                    } label: {
                        Image(systemName: isPaused ? "play.circle.fill" : "pause.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.orange)
                    }
                }
            }
            .padding()
            .navigationTitle("Workout + Music")
        }
        .alert("Cue", isPresented: $isShowingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    private var currentMove: String {
        moves[currentIndex]
    }

    private var progressValue: Double {
        guard !moves.isEmpty else { return 0 }
        return Double(currentIndex + 1) / Double(moves.count)
    }

    private func advanceMove() {
        guard !moves.isEmpty else { return }
        currentIndex = (currentIndex + 1) % moves.count
        alertMessage = "Now playing: \(currentMove)"
        isShowingAlert = true
    }
}

#Preview {
    PlayerView()
}
