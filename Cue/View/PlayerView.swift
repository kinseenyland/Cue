//
//  PlayerView.swift
//  Cue
//
//  Created by Kinsee Nyland on 2/10/26.
//

import SwiftUI

struct PlayerView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hot Pilates Core")
                        .font(.title3).bold()

                    ProgressView(value: 0.6)
                        .tint(.orange)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Plank")
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
                        Button {} label: {
                            Image(systemName: "backward.fill")
                        }

                        Button {} label: {
                            Image(systemName: "play.fill")
                        }
                        .font(.title2)

                        Button {} label: {
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
                    Button("Next Move") {}
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.bordered)

                    Button {
                    } label: {
                        Image(systemName: "pause.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.orange)
                    }
                }
            }
            .padding()
            .navigationTitle("Workout + Music")
        }
    }
}

#Preview {
    PlayerView()
}
