//
//  GroupIconView.swift
//  WhosThereios
//
//  Created by Ian McCurry on 3/17/26.
//

import SwiftUI

struct GroupIconView: View {
    let icon: String
    let size: CGFloat

    init(icon: String, size: CGFloat = 28) {
        self.icon = icon
        self.size = size
    }

    var body: some View {
        if GroupIcon.isCustomIcon(icon) {
            Image(icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            Text(icon)
                .font(.system(size: size * 0.7))
        }
    }
}
