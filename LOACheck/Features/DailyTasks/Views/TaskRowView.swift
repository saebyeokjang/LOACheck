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
    var character: CharacterModel
    @State private var showRestingEditor: Bool = false
    @State private var isProcessing: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    
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
                    Text(taskDisplayName)
                        .font(.headline)
                        .foregroundColor(task.completionCount == task.type.maxCompletionCount ? Color.textSecondary : Color.textPrimary)
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
                    toggleTask()
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
                        
                        // 완료 시 체크마크 표시
                        if task.completionCount > 0 {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.green)
                        }
                    }
                }
                .foregroundColor(task.completionCount > 0 ? Color.textSecondary : Color.textPrimary)
                .cornerRadius(4)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .buttonStyle(DefaultButtonStyle())
                .disabled(isProcessing)
            }
            
            // 휴식보너스 바
            HStack {
                // 휴식보너스 아이콘 (다크모드에서도 잘 보이도록 컬러 조정)
                Image(systemName: "bed.double.fill")
                    .font(.system(size: 12))
                    .foregroundColor(colorScheme == .dark ? .blue : .blue)
                
                // 프로그레스 바
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // 배경 (다크모드에서 더 잘 보이도록 불투명도 조정)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(colorScheme == .dark ? 0.3 : 0.2))
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
                        .foregroundColor(Color.textSecondary)
                    
                    // 편집 버튼 (다크모드에서 더 잘 보이도록 컬러 조정)
                    Button(action: {
                        showRestingEditor = true
                    }) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(colorScheme == .dark ? .blue.opacity(0.8) : .blue)
                    }
                    .buttonStyle(DefaultButtonStyle())
                    .frame(width: 30, height: 30)
                    .contentShape(Circle())
                    .disabled(isProcessing)
                }
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showRestingEditor) {
            RestingPointsEditorView(task: task)
        }
    }
    
    // 체크 색상 결정 (다크모드에서 더 잘 보이도록 수정)
    private func getCheckColor() -> Color {
        if task.completionCount == task.type.maxCompletionCount {
            return colorScheme == .dark ? .green.opacity(0.9) : .green
        } else if task.completionCount > 0 {
            return colorScheme == .dark ? .blue.opacity(0.9) : .blue
        } else {
            return colorScheme == .dark ? .gray.opacity(0.7) : .gray
        }
    }
    
    // 체크박스 배경색 - 다크모드 대응 개선
    private func getCheckBackgroundColor() -> Color {
        if task.completionCount == task.type.maxCompletionCount {
            return Color.green.opacity(colorScheme == .dark ? 0.2 : 0.1)
        } else if task.completionCount > 0 {
            return Color.blue.opacity(colorScheme == .dark ? 0.2 : 0.1)
        } else {
            return colorScheme == .dark ? Color.black.opacity(0.2) : Color.white
        }
    }
    
    // 체크박스 테두리 색상 - 다크모드 대응 개선
    private func getCheckBorderColor() -> Color {
        if task.completionCount == task.type.maxCompletionCount {
            return Color.green.opacity(colorScheme == .dark ? 0.5 : 0.3)
        } else if task.completionCount > 0 {
            return Color.blue.opacity(colorScheme == .dark ? 0.5 : 0.3)
        } else {
            return Color.gray.opacity(colorScheme == .dark ? 0.5 : 0.3)
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
        
        // 동기화 플래그 설정
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
    
    // 포인트 양에 따른 색상 변경 (다크모드에서 더 잘 보이도록 수정)
    private func getBarColor() -> Color {
        let percentage = Double(task.restingPoints) / Double(task.type.maxRestingPoints)
        
        switch percentage {
        case 0..<0.25:
            return colorScheme == .dark ? Color.blue.opacity(0.8) : Color.blue
        case 0.25..<0.5:
            return colorScheme == .dark ? Color.teal.opacity(0.8) : Color.teal
        case 0.5..<0.75:
            return colorScheme == .dark ? Color.green.opacity(0.8) : Color.green
        case 0.75...1.0:
            return colorScheme == .dark ? Color.orange.opacity(0.8) : Color.orange
        default:
            return colorScheme == .dark ? Color.blue.opacity(0.8) : Color.blue
        }
    }
}
