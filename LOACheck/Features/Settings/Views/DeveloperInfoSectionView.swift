//
//  DeveloperInfoSectionView.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 4/11/25.
//

import SwiftUI

struct DeveloperInfoSectionView: View {
    var body: some View {
        Section(header: Text("만든 사람")) {
            Link("개발자에게 피드백 보내기", destination: URL(string: "mailto:dev.saebyeok@gmail.com?subject=LOACheck 피드백")!)
            Text("실리안 • 기상술사김새벽")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    DeveloperInfoSectionView()
}
