//
//  LegalSectionView.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 4/15/25.
//

import SwiftUI

struct LegalSectionView: View {
    var body: some View {
        Section(header: Text("법적 고지")) {
            Link("이용약관", destination: URL(string: "https://saebyeokjang.github.io/LOACheck/terms")!)
                .foregroundColor(.blue)
            
            Link("개인정보 처리방침", destination: URL(string: "https://saebyeokjang.github.io/LOACheck/privacy-policy")!)
                .foregroundColor(.blue)
        }
    }
}
