//
//  FormFieldOutline.swift
//  Cue
//

import SwiftUI

extension View {
    /// Matches `FormDropdown` stroke: rounded rect, 10pt radius, 1pt black stroke.
    func cueFormFieldOutline(cornerRadius: CGFloat = 10, color: Color = .black) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(color, lineWidth: 1)
        )
    }
}
