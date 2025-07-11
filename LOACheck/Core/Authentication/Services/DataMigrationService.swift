//
//  DataMigrationService.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 4/9/25.
//

import Foundation
import SwiftData
import FirebaseFirestore

/// 데이터 마이그레이션을 관리하는 서비스 클래스
class DataMigrationService {
    static let shared = DataMigrationService()
    
    private init() {}
    
    /// 최초 로그인 또는 앱 업데이트 후 필요한 데이터 마이그레이션 수행
    func performMigrationIfNeeded(modelContext: ModelContext) {
        // 캐릭터 레벨 정규화 마이그레이션
        normalizeCharacterLevels(modelContext: modelContext)
        
        // 캐릭터 이름 등록 (파이어베이스에 검색 가능하도록)
        registerCharacterNamesToFirebase(modelContext: modelContext)
        
        // 캐릭터 데이터 구조 업데이트
        updateCharacterDataSchema(modelContext: modelContext)
    }
    
    /// 로그인 후 초기 데이터 마이그레이션 수행
    func performInitialMigrationAfterLogin(modelContext: ModelContext) {
        // 이미 마이그레이션이 수행되었는지 확인
        if UserDefaults.standard.bool(forKey: "initialMigrationCompleted_\(AuthManager.shared.userId)") {
            Logger.debug("초기 마이그레이션이 이미 완료되었습니다.")
            return
        }
        
        Logger.info("로그인 후 초기 데이터 마이그레이션 시작")
        
        // 캐릭터 이름 등록 (파이어베이스에 검색 가능하도록)
        registerCharacterNamesToFirebase(modelContext: modelContext)
        
        // 완료 표시
        UserDefaults.standard.set(true, forKey: "initialMigrationCompleted_\(AuthManager.shared.userId)")
        Logger.info("초기 데이터 마이그레이션 완료")
    }
    
    /// 모든 캐릭터의 레벨 정규화 (잘못된 값 수정)
    private func normalizeCharacterLevels(modelContext: ModelContext) {
        // 이미 마이그레이션이 수행되었는지 확인
        if UserDefaults.standard.bool(forKey: "levelMigrationCompleted") {
            return
        }
        
        do {
            Logger.info("캐릭터 레벨 정규화 마이그레이션 시작")
            
            let descriptor = FetchDescriptor<CharacterModel>()
            let characters = try modelContext.fetch(descriptor)
            var updatedCount = 0
            
            for character in characters {
                let originalLevel = character.level
                
                // 잘못된 레벨 값 수정
                if character.level < 0 {
                    character.level = 0
                    updatedCount += 1
                } else if character.level > 10000 {
                    // 큰 값(예: 61670)은 실제 레벨(61.67)로 변환
                    character.level = character.level / 1000
                    updatedCount += 1
                } else if character.level < 10 && character.level > 0 {
                    // 매우 작은 값은 직접 검토 필요
                    Logger.warning("의심스러운 레벨 값 발견: \(character.name)의 레벨 \(character.level)")
                }
                
                if character.level != originalLevel {
                    Logger.debug("캐릭터 '\(character.name)'의 레벨이 \(originalLevel)에서 \(character.level)로 정규화되었습니다.")
                }
            }
            
            Logger.info("캐릭터 레벨 정규화 완료: \(updatedCount)개 업데이트됨")
            
            // 마이그레이션 완료 표시
            UserDefaults.standard.set(true, forKey: "levelMigrationCompleted")
        } catch {
            Logger.error("캐릭터 레벨 정규화 실패", error: error)
        }
    }
    
    /// 캐릭터 이름을 파이어베이스에 등록 (대표 캐릭터만 등록하도록 수정)
    private func registerCharacterNamesToFirebase(modelContext: ModelContext) {
        guard AuthManager.shared.isLoggedIn else {
            Logger.debug("로그인되어 있지 않아서 캐릭터 이름 등록을 건너뜁니다.")
            return
        }
        
        Task {
            do {
                // 대표 캐릭터 이름 가져오기
                let representativeCharacter = UserDefaults.standard.string(forKey: "representativeCharacter")
                
                if let repCharName = representativeCharacter, !repCharName.isEmpty {
                    // 대표 캐릭터 이름만 등록
                    await registerCharacterNameToFirebase(repCharName)
                    Logger.info("대표 캐릭터 이름 등록 시도 완료: \(repCharName)")
                }
                
                // 나머지 캐릭터들은 등록하지 않음
            } catch {
                Logger.error("캐릭터 이름 등록 실패", error: error)
            }
        }
    }
    
    /// 단일 캐릭터 이름 파이어베이스 등록 - 대표 캐릭터를 위한 로직
    private func registerCharacterNameToFirebase(_ characterName: String) async {
        guard !characterName.isEmpty, AuthManager.shared.isLoggedIn, let userId = AuthManager.shared.currentUser?.id else {
            return
        }
        
        do {
            let db = Firestore.firestore()
            
            // 1. 현재 사용자의 기존 characterNames 문서 모두 삭제
            let snapshot = try await db.collection("characterNames")
                .whereField("userId", isEqualTo: userId)
                .getDocuments()
            
            // 기존 문서 삭제 (대표 캐릭터만 남기기 위함)
            if !snapshot.documents.isEmpty {
                let batch = db.batch()
                for doc in snapshot.documents {
                    batch.deleteDocument(doc.reference)
                }
                try await batch.commit()
                Logger.debug("기존 characterNames 문서 \(snapshot.documents.count)개 삭제 완료")
            }
            
            // 2. 대표 캐릭터만 등록
            let docRef = db.collection("characterNames").document(characterName)
            
            // 이미 등록된 캐릭터인지 확인
            let document = try await docRef.getDocument()
            
            if document.exists {
                // 이미 존재하는 경우
                if let existingUserId = document.data()?["userId"] as? String, existingUserId != userId {
                    // 다른 사용자가 이미 이 캐릭터 이름을 가지고 있음
                    Logger.debug("캐릭터 '\(characterName)'은 다른 사용자가 이미 등록했습니다.")
                    return
                } else if let existingUserId = document.data()?["userId"] as? String, existingUserId == userId {
                    // 이미 이 사용자가 등록했음 - 정보 업데이트 필요
                    Logger.debug("캐릭터 '\(characterName)'은 이미 등록되어 있습니다. 정보 업데이트 시도.")
                }
            }
            
            // 캐릭터 정보 등록
            try await FirebaseRepository.shared.storeCharacterDetails(characterName: characterName)
            
            Logger.debug("캐릭터 '\(characterName)' 등록 성공 (대표 캐릭터)")
        } catch {
            Logger.error("캐릭터 '\(characterName)' 등록 실패", error: error)
        }
    }
    
    /// 캐릭터 데이터 구조 업데이트 (스키마 변경이 있을 경우)
    private func updateCharacterDataSchema(modelContext: ModelContext) {
        // 이전 버전에서 마이그레이션이 필요한 스키마 변경사항이 있을 경우 여기서 처리
        let currentAppVersion = AppUpdateService.shared.getCurrentAppVersion()
        let lastMigratedVersion = UserDefaults.standard.string(forKey: "lastMigratedVersion") ?? "0.0.0"
        
        // 버전 비교 후 필요한 마이그레이션 실행
        let needsMigration = AppUpdateService.shared.isUpdateAvailable(currentVersion: lastMigratedVersion, latestVersion: currentAppVersion)
        
        if !needsMigration {
            return
        }
        
        Logger.info("데이터 스키마 마이그레이션 시작 (버전: \(lastMigratedVersion) -> \(currentAppVersion))")
        
        // 여기서 버전별 마이그레이션 로직 실행
        
        // 버전 1.0.0에서 1.1.0으로 마이그레이션
        if lastMigratedVersion.starts(with: "1.0") && currentAppVersion.starts(with: "1.1") {
            migrateFrom1_0_To1_1(modelContext: modelContext)
        }
        
        if lastMigratedVersion.starts(with: "1.3") && currentAppVersion.starts(with: "1.4") {
            migrateFrom1_3_To1_4(modelContext: modelContext)
        }
        
        // 추가 버전 마이그레이션은 여기에 추가
        
        // 마이그레이션 완료 후 버전 업데이트
        UserDefaults.standard.set(currentAppVersion, forKey: "lastMigratedVersion")
        Logger.info("데이터 스키마 마이그레이션 완료")
    }
    
    // 버전 1.0.0에서 1.1.0으로 마이그레이션
    private func migrateFrom1_0_To1_1(modelContext: ModelContext) {
        do {
            Logger.info("버전 1.0.0에서 1.1.0으로 마이그레이션 중...")
            
            // 1. 모든 캐릭터 가져오기
            let descriptor = FetchDescriptor<CharacterModel>()
            let characters = try modelContext.fetch(descriptor)
            
            // 2. additionalGoldMap 필드 초기화 (1.1.0에서 추가된 필드)
            for character in characters {
                if character.additionalGoldMap.isEmpty || character.additionalGoldMap == "{}" {
                    character.additionalGoldMap = "{}"
                    
                    // 레이드 관문이 있는 경우 추가 골드 맵 초기화
                    if let gates = character.raidGates, !gates.isEmpty {
                        // 레이드별로 그룹화
                        let groupedGates = Dictionary(grouping: gates) { $0.raid }
                        
                        // 각 레이드의 additionalGoldMap에 초기값 설정
                        var additionalGoldMap: [String: Int] = [:]
                        for (raidName, _) in groupedGates {
                            additionalGoldMap[raidName] = 0
                        }
                        
                        // 맵 저장
                        character.additionalGoldForRaids = additionalGoldMap
                    }
                }
            }
            
            Logger.info("버전 1.0.0에서 1.1.0으로 마이그레이션 완료")
        } catch {
            Logger.error("버전 1.0.0에서 1.1.0으로 마이그레이션 실패", error: error)
        }
    }
    
    private func migrateFrom1_3_To1_4(modelContext: ModelContext) {
        do {
            Logger.info("버전 1.3.9에서 1.4.0으로 마이그레이션 중... (전투력 필드 추가)")
            
            // 모든 캐릭터 가져오기
            let descriptor = FetchDescriptor<CharacterModel>()
            let characters = try modelContext.fetch(descriptor)
            
            var migratedCount = 0
            
            // combatPower 필드 초기화
            for character in characters {
                // 전투력 필드가 없거나 0.0인 경우 초기화
                if character.combatPower == 0.0 {
                    character.combatPower = 0.0
                    migratedCount += 1
                    Logger.debug("캐릭터 '\(character.name)'의 전투력 필드 초기화 완료")
                }
            }
            
            // 변경사항 저장
            try modelContext.save()
            
            // 마이그레이션 완료 플래그 설정
            UserDefaults.standard.set(true, forKey: "combatPowerMigrationCompleted")
            
            Logger.info("버전 1.3.9에서 1.4.0으로 마이그레이션 완료 - \(migratedCount)개 캐릭터 업데이트")
            
            // 앱 업데이트 알림 표시 (선택사항)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                // 사용자에게 새로운 전투력 기능 안내
                Logger.info("전투력 기능이 추가되었습니다. 캐릭터 정보를 새로고침하여 전투력을 확인하세요.")
            }
            
        } catch {
            Logger.error("버전 1.3.9에서 1.4.0으로 마이그레이션 실패", error: error)
        }
    }
}
