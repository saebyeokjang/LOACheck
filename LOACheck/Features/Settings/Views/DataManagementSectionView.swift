//
//  DataManagementSectionView.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 4/11/25.
//

import SwiftUI

struct DataManagementSectionView: View {
    @Binding var isShowingResetConfirmation: Bool
    
    var body: some View {
        Section(header: Text("데이터 관리")) {
            Button(action: {
                // 확인 알림 표시
                isShowingResetConfirmation = true
            }) {
                Text("모든 데이터 초기화")
                    .foregroundColor(.red)
            }
        }
    }
}

#Preview {
    DataManagementSectionView(
        isShowingResetConfirmation: .constant(false)
    )
}
