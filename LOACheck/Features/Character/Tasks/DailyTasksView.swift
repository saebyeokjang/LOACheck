//
//  DailyTasksView.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/21/25.
//

import SwiftUI

struct DailyTasksView: View {
    var tasks: [DailyTask]
    var character: CharacterModel  // 캐릭터 모델 추가
    var isActiveView: Bool = true // 현재 활성화된 페이지인지 여부
    @State private var showRestingPointsInfo = false
    
    private var sortedTasks: [DailyTask] {
        tasks.sorted { task1, task2 in
            let order: [DailyTask.TaskType] = [.eponaQuest, .chaosGate, .guardianRaid]
            let index1 = order.firstIndex(of: task1.type) ?? Int.max
            let index2 = order.firstIndex(of: task2.type) ?? Int.max
            return index1 < index2
        }
    }
    
    // 복잡한 문자열 처리를 위한 계산 속성
    private var chaosContentName: String {
        return character.level >= 1640 ? "쿠르잔 전선" : "카오스 던전"
    }
    
    private var alertMessage: String {
        let message = """
        컨텐츠 미완료 시 다음 날 오전 6시에 휴식보너스가 충전됩니다
        
        • 에포나 의뢰: 미완료 1회당 10포인트
        클리어 시 1회당 20포인트 소모
        
        • \(chaosContentName): 미완료 시 20포인트
        클리어 시 40포인트 소모
        
        • 가디언 토벌: 미완료 시 10포인트
        클리어 시 20포인트 소모
        
        휴식보너스 사용 시
        추가 보상을 획득할 수 있습니다
        """
        return message
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("일일 숙제")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                // 휴게 포인트 설명 버튼
                Button(action: {
                    showRestingPointsInfo = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                        Text("휴식보너스")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                    .padding(8) // 터치 영역 확장
                    .contentShape(Rectangle()) // 명확한 터치 영역 정의
                }
                .buttonStyle(ScaleButtonStyle()) // 버튼 스타일 적용
            }
            
            Divider()
            
            // 최적화된 태스크 목록
            LazyVStack(spacing: 8) {
                ForEach(sortedTasks) { task in
                    TaskRowView(task: task, character: character)  // 캐릭터 전달
                    
                    if task != sortedTasks.last {
                        Divider()
                            .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .alert(isPresented: $showRestingPointsInfo) {
            Alert(
                title: Text("휴식보너스 시스템"),
                message: Text(alertMessage),
                dismissButton: .default(Text("확인"))
            )
        }
        // 비활성 뷰일 때는 입력 비활성화 (페이지 전환 중)
        .allowsHitTesting(isActiveView)
    }
}
