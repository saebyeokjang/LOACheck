//
//  TaskRowView.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 3/21/25.
//

import SwiftUI
import SwiftData
import FirebaseAnalytics

struct TaskRowView: View {
    @Bindable var task: DailyTask
    var character: CharacterModel  // 캐릭터 모델 추가
    @State private var showRestingEditor: Bool = false
    @State private var isProcessing: Bool = false // 처리 중 상태 추가
    
    // 캐릭터 레벨에 따른 작업 이름
    private var taskDisplayName: String {
        return character.getTaskDisplayName(for: task)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 작업 제목과 완료 상태
            HStack {
                // 작업 이름 - 왼쪽으로 이동
                VStack(alignment: .leading, spacing: 2) {
                    Text(taskDisplayName)  // 계산 속성 사용
                        .font(.headline)
                        .foregroundColor(task.completionCount == task.type.maxCompletionCount ? .secondary : .primary)
                    // 취소선 적용: 에포나 의뢰는 3회 모두 완료했을 때만, 다른 항목은 완료하면 취소선
                        .strikethrough(task.type == .eponaQuest ?
                                       (task.completionCount == task.type.maxCompletionCount) :
                                        (task.completionCount > 0))
                }
                
                Spacer()
                
                // 휴식보너스 아이콘 (포인트가 소모될 수 있는 경우)
                if task.restingPoints >= task.type.pointsPerCompletion && task.completionCount < task.type.maxCompletionCount {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                        .padding(.trailing, 4)
                }
                
                // 체크박스
                Button(action: {
                    toggleTask() // 중복 처리 방지는 toggleTask() 내부에서 처리
                }) {
                    ZStack {
                        // 프레임 배경과 테두리
                        RoundedRectangle(cornerRadius: 4)
                            .fill(getCheckBackgroundColor())
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(getCheckBorderColor(), lineWidth: 1)
                            )
                            .frame(width: 32, height: 32)
                        
                        // 에포나 의뢰와 일반 작업 표시 구분
                        if task.type == .eponaQuest {
                            if task.completionCount == task.type.maxCompletionCount {
                                // 모두 완료한 경우 체크마크 표시
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.green)
                            } else if task.completionCount > 0 {
                                // 일부 완료한 경우 숫자 표시
                                Text("\(task.completionCount)")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(getCheckColor())
                            }
                        } else {
                            // 일반 작업 (쿠르잔/가디언) - 완료하면 체크마크
                            if task.completionCount > 0 {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
                .foregroundColor(task.completionCount > 0 ? .secondary : .primary)
                .cornerRadius(4)
                .frame(width: 44, height: 44) // 터치 영역 확장
                .contentShape(Rectangle()) // 명확한 터치 영역 정의
                .buttonStyle(ScaleButtonStyle()) // 커스텀 버튼 스타일 적용
                .disabled(isProcessing) // 처리 중 비활성화
            }
            
            // 휴식보너스 바
            HStack {
                // 휴식보너스 아이콘
                Image(systemName: "bed.double.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
                
                // 프로그레스 바
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // 배경
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 6)
                        
                        // 채워진 부분
                        RoundedRectangle(cornerRadius: 2)
                            .fill(getBarColor())
                            .frame(width: calculateWidth(geometry.size.width), height: 6)
                    }
                }
                .frame(height: 6)
                
                // 포인트 텍스트 및 편집 버튼
                HStack(spacing: 4) {
                    Text("\(task.restingPoints)/\(task.type.maxRestingPoints)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    // 편집 버튼
                    Button(action: {
                        showRestingEditor = true
                    }) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(ScaleButtonStyle()) // 편집 버튼에도 동일한 스타일 적용
                    .frame(width: 30, height: 30)
                    .contentShape(Circle())
                    .disabled(isProcessing) // 처리 중 비활성화
                }
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showRestingEditor) {
            RestingPointsEditorView(task: task)
        }
    }
    
    // 체크 색상 결정
    private func getCheckColor() -> Color {
        if task.completionCount == task.type.maxCompletionCount {
            return .green
        } else if task.completionCount > 0 {
            return .blue
        } else {
            return .gray
        }
    }
    
    // 체크박스 배경색 - 주간 레이드 스타일
    private func getCheckBackgroundColor() -> Color {
        if task.completionCount == task.type.maxCompletionCount {
            return Color.green.opacity(0.1)
        } else if task.completionCount > 0 {
            return Color.blue.opacity(0.1)
        } else {
            return Color.white
        }
    }
    
    // 체크박스 테두리 색상 - 주간 레이드 스타일
    private func getCheckBorderColor() -> Color {
        if task.completionCount == task.type.maxCompletionCount {
            return Color.green.opacity(0.3)
        } else if task.completionCount > 0 {
            return Color.blue.opacity(0.3)
        } else {
            return Color.gray.opacity(0.3)
        }
    }
    
    // 작업 토글 - 반응성 개선
    private func toggleTask() {
        // 이미 처리 중인 경우 무시
        guard !isProcessing else { return }
        
        // 중복 처리 방지 플래그 설정
        isProcessing = true
        
        // 즉시 상태 변경
        let currentCount = task.completionCount
        let maxCount = task.type.maxCompletionCount
        
        // 에포나 의뢰는 0→1→2→3→0으로 순환
        if task.type == .eponaQuest {
            if currentCount >= maxCount {
                // 최대 완료 상태에서 미완료로 돌아감
                // 모든 단계의 휴게 포인트 반환
                for i in 0..<currentCount {
                    task.returnRestingPoints(forStep: i)
                }
                task.completionCount = 0
            } else {
                // 다음 단계로 완료 상태 증가
                let _ = task.consumeRestingPoints()
                
                task.completionCount += 1
                task.lastCompletedAt = Date()
            }
        } else {
            // 일반 작업은 토글 (0→1→0)
            if currentCount == 0 {
                // 완료로 변경
                let _ = task.consumeRestingPoints()
                
                task.completionCount = task.type.maxCompletionCount
                task.lastCompletedAt = Date()
            } else {
                // 미완료로 변경하면서 사용했던 포인트 반환
                task.returnRestingPoints(forStep: 0)
                
                task.completionCount = 0
                task.lastCompletedAt = nil
            }
        }
        
        // 햅틱 피드백 제공
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // 동기화 플래그 설정 - 이 부분이 추가됨
        DataSyncManager.shared.markLocalChanges()
        
        // 매우 짧은 지연 후 처리 상태 해제
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isProcessing = false
        }
        
        // 일일 숙제 상태 변경 추적
            Analytics.logEvent("daily_task_toggled", parameters: [
                "task_type": task.type.rawValue,
                "is_completed": task.completionCount == task.type.maxCompletionCount,
                "character_level": character.level,
                "character_class": character.characterClass
            ])
    }
    
    // 채워진 너비 계산
    private func calculateWidth(_ totalWidth: CGFloat) -> CGFloat {
        let percentage = CGFloat(task.restingPoints) / CGFloat(task.type.maxRestingPoints)
        return totalWidth * min(percentage, 1.0)
    }
    
    // 포인트 양에 따른 색상 변경
    private func getBarColor() -> Color {
        let percentage = Double(task.restingPoints) / Double(task.type.maxRestingPoints)
        switch percentage {
        case 0..<0.25: return .blue
        case 0.25..<0.5: return .teal
        case 0.5..<0.75: return .green
        case 0.75...1.0: return .orange
        default: return .blue
        }
    }
}

// 버튼 누를 때 시각적 피드백을 제공하는 커스텀 버튼 스타일
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
