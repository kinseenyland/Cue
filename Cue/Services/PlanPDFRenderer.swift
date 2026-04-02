//
//  PlanPDFRenderer.swift
//  Cue
//

import SwiftUI

struct PlanPDFRenderer {

    static func render(plan: WorkoutPlan) -> URL? {
        let view = PlanPDFPageView(plan: plan)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(plan.title).pdf")

        var success = false
        renderer.render { size, context in
            var box = CGRect(origin: .zero, size: size)
            guard let pdf = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
            pdf.beginPDFPage(nil)
            context(pdf)
            pdf.endPDFPage()
            pdf.closePDF()
            success = true
        }
        return success ? url : nil
    }
}

// MARK: - PDF Page Layout

private struct PlanPDFPageView: View {
    let plan: WorkoutPlan

    private var difficultyLabel: String {
        switch plan.difficulty {
        case .easy: return "Low"
        case .medium: return "Medium"
        case .hard: return "High"
        }
    }

    private var warmUpMovements: [Movement] {
        plan.movements.filter { $0.section == .warmUp }
    }

    private var coolDownMovements: [Movement] {
        plan.movements.filter { $0.section == .coolDown }
    }

    private var mainSections: [(name: String, movements: [Movement])] {
        var result: [(name: String, movements: [Movement])] = []
        var nameToIndex: [String: Int] = [:]
        for m in plan.movements where m.section == .main {
            let key = m.sectionName ?? ""
            if let idx = nameToIndex[key] {
                result[idx].movements.append(m)
            } else {
                nameToIndex[key] = result.count
                result.append((name: key, movements: [m]))
            }
        }
        return result
    }

    private var hasSectionStructure: Bool {
        !warmUpMovements.isEmpty || !coolDownMovements.isEmpty ||
        mainSections.contains(where: { !$0.name.isEmpty })
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                Text(plan.title)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.black)

                HStack(spacing: 16) {
                    Label(plan.type.displayName, systemImage: typeIcon)
                    Label("\(plan.durationMinutes) min", systemImage: "timer")
                    Label(difficultyLabel, systemImage: "flame.fill")
                }
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            }
            .padding(.bottom, 16)

            Divider()
                .padding(.bottom, 16)

            // Movements
            if hasSectionStructure {
                if !warmUpMovements.isEmpty {
                    sectionBlock(title: "WARM-UP", movements: warmUpMovements)
                }
                if !mainSections.isEmpty {
                    mainBlock
                }
                if !coolDownMovements.isEmpty {
                    sectionBlock(title: "COOL-DOWN", movements: coolDownMovements)
                }
            } else {
                ForEach(plan.movements) { movement in
                    movementRow(movement)
                }
            }

            Spacer(minLength: 20)

            Divider()
                .padding(.top, 8)

            HStack {
                Text("Exported from Cue")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formattedDate)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)
        }
        .padding(40)
        .frame(width: 612, alignment: .topLeading)
        .background(Color.white)
    }

    private var typeIcon: String {
        switch plan.type {
        case .matPilates, .reformerPilates: return "figure.pilates"
        case .yoga: return "figure.yoga"
        case .cycle: return "bicycle"
        case .strength: return "dumbbell.fill"
        case .cardio: return "heart.fill"
        }
    }

    // MARK: - Section builders

    @ViewBuilder
    private func sectionBlock(title: String, movements: [Movement]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
                .kerning(1.2)
                .padding(.bottom, 2)

            ForEach(movements) { movement in
                movementRow(movement)
            }
        }
        .padding(.bottom, 14)
    }

    private var mainBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("MAIN WORKOUT")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
                .kerning(1.2)
                .padding(.bottom, 2)

            ForEach(mainSections.indices, id: \.self) { idx in
                let section = mainSections[idx]
                if !section.name.isEmpty {
                    Text(section.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.top, idx > 0 ? 6 : 0)
                }
                ForEach(section.movements) { movement in
                    movementRow(movement)
                }
            }
        }
        .padding(.bottom, 14)
    }

    @ViewBuilder
    private func movementRow(_ movement: Movement) -> some View {
        HStack {
            Text(movement.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.black)

            if let notes = movement.notes, !notes.isEmpty {
                Text("– \(notes)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(goalText(for: movement))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 10)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func goalText(for movement: Movement) -> String {
        switch movement.goalType {
        case .timed:
            return movement.seconds.map { "\($0) sec" } ?? ""
        case .reps:
            return movement.reps.map { "\($0) reps" } ?? ""
        case nil:
            return ""
        }
    }
}
