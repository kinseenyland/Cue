//
//  PlanMusicStepView.swift
//  Cue
//

import SwiftUI

// MARK: - Music Approach Choice Step

struct MusicApproachChoiceStepView: View {
    @EnvironmentObject private var vm: PlanCreationViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("How do you\napproach music?")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 24)

                VStack(spacing: 12) {
                    choiceCard(
                        title: "Music First",
                        subtitle: "Pick your playlists, then build movements",
                        value: .musicFirst
                    )
                    choiceCard(
                        title: "Movements First",
                        subtitle: "Build your workout, then add music",
                        value: .workoutFirst
                    )
                }
                .padding(.horizontal, 24)
            }
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func choiceCard(title: String, subtitle: String, value: MusicApproach) -> some View {
        let isSelected = vm.musicFlowChoice == value
        return Button {
            vm.musicFlowChoice = value
        } label: {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : .black)
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.white)
                }
            }
            .padding(20)
            .background(isSelected ? Color.black : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.black, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Pick Music Step

struct PlanPickMusicStepView: View {
    @EnvironmentObject private var vm: PlanCreationViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("Pick Your Music")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 24)

                VStack(alignment: .leading, spacing: 20) {
                    PlanSectionPlaylistPicker(
                        title: "Warm-up playlist",
                        selectedPlaylistId: $vm.draft.warmUpPlaylistId
                    )
                    PlanSectionPlaylistPicker(
                        title: "Main workout playlist",
                        selectedPlaylistId: $vm.draft.mainPlaylistId
                    )
                    PlanSectionPlaylistPicker(
                        title: "Cool-down playlist",
                        selectedPlaylistId: $vm.draft.coolDownPlaylistId
                    )
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            Task { await vm.loadSpotifyPlaylistsIfNeeded() }
        }
    }
}

// MARK: - Assigned Playlist Label

struct AssignedPlaylistLabel: View {
    let name: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "music.note.list")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Text(name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}
