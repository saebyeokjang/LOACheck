//
//  AuthManager.swift
//  LOACheck
//
//  Created by Saebyeok Jang on 4/8/25.
//

import Foundation
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import GoogleSignIn

/// Firebase 인증을 관리하는 클래스
class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    // 인증 상태를 관찰할 수 있는 Published 속성
    @Published var isLoggedIn: Bool = false
    @Published var currentUser: User?
    @Published var isLoading: Bool = false
    @Published var error: Error?
    
    // 최초 로그인 여부 (데이터 마이그레이션 용도)
    @Published var isFirstTimeLogin: Bool = false
    
    // 대표 캐릭터 이름 저장용 속성
    @Published var representativeCharacter: String = ""
    
    private var authStateHandler: AuthStateDidChangeListenerHandle?
    
    private init() {
        // 대표 캐릭터 이름 로드 - 기본 값은 전역 설정에서 가져옴
        self.representativeCharacter = UserDefaults.standard.string(forKey: "representativeCharacter") ?? ""
        
        setupFirebase()
        setupAuthStateListener()
    }
    
    // Firebase 초기화
    private func setupFirebase() {
        // 앱이 이미 설정되었는지 확인 (중복 초기화 방지)
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }
    
    // 인증 상태 변경 리스너 설정
    private func setupAuthStateListener() {
        authStateHandler = Auth.auth().addStateDidChangeListener { [weak self] (_, firebaseUser) in
            guard let self = self else { return }
            
            Task {
                await MainActor.run {
                    if let firebaseUser = firebaseUser {
                        self.currentUser = User(from: firebaseUser)
                        self.isLoggedIn = true
                        
                        // 사용자별 대표 캐릭터 로드
                        let userRepChar = UserDefaults.standard.string(forKey: "representativeCharacter_\(firebaseUser.uid)") ?? ""
                        if !userRepChar.isEmpty {
                            self.representativeCharacter = userRepChar
                        }
                        
                        if UserDefaults.standard.object(forKey: "hasCompletedInitialSync_\(firebaseUser.uid)") == nil {
                            self.isFirstTimeLogin = true
                        }
                    } else {
                        self.currentUser = nil
                        self.isLoggedIn = false
                        
                        // 로그아웃 시 대표 캐릭터는 전역 설정으로 돌아감
                        self.representativeCharacter = UserDefaults.standard.string(forKey: "representativeCharacter") ?? ""
                    }
                }
            }
        }
    }
    
    // MARK: - 공용 속성 및 메서드
    
    // 현재 사용자 ID 반환
    var userId: String {
        return currentUser?.id ?? ""
    }
    
    // 사용자 표시명 반환
    var displayName: String {
        if !representativeCharacter.isEmpty {
            return representativeCharacter
        }
        return currentUser?.displayName ?? "사용자"
    }
    
    // 사용자 이메일 반환
    var email: String {
        return currentUser?.email ?? ""
    }
    
    // 대표 캐릭터 설정
    func setRepresentativeCharacter(_ characterName: String) {
        self.representativeCharacter = characterName
        
        // 전역 설정에 저장
        UserDefaults.standard.set(characterName, forKey: "representativeCharacter")
        
        // 사용자별 설정에 저장
        if isLoggedIn, let uid = currentUser?.id {
            UserDefaults.standard.set(characterName, forKey: "representativeCharacter_\(uid)")
            
            // 여기서 직접 Firestore 업데이트를 명시적으로 수행
            Task {
                do {
                    let db = Firestore.firestore()
                    try await db.collection("users").document(uid).updateData([
                        "displayName": characterName
                    ])
                    
                    Logger.debug("Firestore에 대표 캐릭터 이름 '\(characterName)' 업데이트 완료")
                    
                    // 현재 사용자 객체도 업데이트
                    if var updatedUser = self.currentUser {
                        updatedUser.displayName = characterName
                        await MainActor.run {
                            self.currentUser = updatedUser
                        }
                    }
                } catch {
                    Logger.error("Firestore 대표 캐릭터 업데이트 실패: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // 대표 캐릭터 이름으로 표시 이름 업데이트
    func updateDisplayNameToRepCharacter() {
        guard isLoggedIn, !representativeCharacter.isEmpty, let uid = currentUser?.id else { return }
        
        Task {
            do {
                // Firestore에 표시 이름 업데이트
                let db = Firestore.firestore()
                try await db.collection("users").document(uid).updateData([
                    "displayName": representativeCharacter
                ])
                
                // 현재 사용자 객체 업데이트
                if var updatedUser = currentUser {
                    updatedUser.displayName = representativeCharacter
                    await MainActor.run {
                        self.currentUser = updatedUser
                    }
                }
                
                Logger.debug("사용자 표시 이름이 '\(representativeCharacter)'(으)로 업데이트되었습니다.")
            } catch {
                Logger.error("사용자 표시 이름 업데이트 실패", error: error)
            }
        }
    }
    
    func updateFirestoreDisplayName() async -> Bool {
        guard isLoggedIn, let uid = currentUser?.id, !representativeCharacter.isEmpty else {
            return false
        }
        
        do {
            let db = Firestore.firestore()
            try await db.collection("users").document(uid).updateData([
                "displayName": representativeCharacter
            ])
            
            Logger.debug("Firestore displayName 직접 업데이트 성공: '\(representativeCharacter)'")
            return true
        } catch {
            Logger.error("Firestore displayName 직접 업데이트 실패: \(error.localizedDescription)")
            return false
        }
    }
    
    // 로그인 성공 후 처리 (Apple/Google 공통)
    private func handleSuccessfulLogin(user: FirebaseAuth.User) async {
        // 대표 캐릭터 이름 불러오기
        let userRepChar = UserDefaults.standard.string(forKey: "representativeCharacter_\(user.uid)") ?? ""
        let globalRepChar = UserDefaults.standard.string(forKey: "representativeCharacter") ?? ""
        
        // 우선순위: 사용자별 설정 > 전역 설정 > 기본값
        let displayName: String
        if !userRepChar.isEmpty {
            displayName = userRepChar
            await MainActor.run {
                self.representativeCharacter = userRepChar
            }
        } else if !globalRepChar.isEmpty {
            displayName = globalRepChar
            // 사용자별 설정 저장
            UserDefaults.standard.set(globalRepChar, forKey: "representativeCharacter_\(user.uid)")
            await MainActor.run {
                self.representativeCharacter = globalRepChar
            }
        } else {
            displayName = user.displayName ?? "사용자"
        }
        
        // Firestore에 사용자 프로필 저장
        let db = Firestore.firestore()
        do {
            try await db.collection("users").document(user.uid).setData([
                "displayName": displayName,
                "email": user.email ?? "",
                "lastActive": FieldValue.serverTimestamp()
            ], merge: true)
        } catch {
            Logger.error("사용자 프로필 저장 실패", error: error)
        }
    }
    
    // 로그아웃
    func signOut() async -> Bool {
        do {
            try Auth.auth().signOut()
            return true
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
            return false
        }
    }
    
    // 계정 삭제
    func deleteAccount() async -> Bool {
        guard let user = Auth.auth().currentUser else { return false }
        
        do {
            try await user.delete()
            return true
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
            return false
        }
    }
    
    // MARK: - Apple 로그인
    
    func signInWithApple(idToken: String, nonce: String) async -> Bool {
        await MainActor.run {
            self.isLoading = true
        }
        
        do {
            let credential = OAuthProvider.credential(
                withProviderID: "apple.com",
                idToken: idToken,
                rawNonce: nonce
            )
            
            let result = try await Auth.auth().signIn(with: credential)
            
            // 로그인 성공 후 처리
            await handleSuccessfulLogin(user: result.user)
            
            await MainActor.run {
                self.currentUser = User(from: result.user)
                self.isLoggedIn = true
                self.isLoading = false
            }
            
            return true
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
            return false
        }
    }
    
    // MARK: - Google 로그인
    func signInWithGoogle() async -> Bool {
        await MainActor.run {
            self.isLoading = true
        }
        
        do {
            let result = try await signInWithGoogleInternal()
            
            // 구글 인증 정보 가져오기
            guard let idToken = result.user.idToken?.tokenString else {
                throw NSError(domain: "AuthManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "No ID token"])
            }
            
            // Firebase에 구글 인증 정보로 로그인
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: result.user.accessToken.tokenString)
            let authResult = try await Auth.auth().signIn(with: credential)
            
            // 로그인 성공 후 처리
            await handleSuccessfulLogin(user: authResult.user)
            
            // 유저 정보 저장
            await MainActor.run {
                self.currentUser = User(from: authResult.user)
                self.isLoggedIn = true
                self.isLoading = false
            }
            
            return true
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
            return false
        }
    }
    
    @MainActor
    private func signInWithGoogleInternal() async throws -> GIDSignInResult {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            throw NSError(domain: "AuthManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "No window scene found"])
        }
        
        guard let rootViewController = windowScene.windows.first?.rootViewController else {
            throw NSError(domain: "AuthManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "No root view controller found"])
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { signInResult, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let signInResult = signInResult else {
                    continuation.resume(throwing: NSError(domain: "AuthManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "No sign in result"]))
                    return
                }
                
                continuation.resume(returning: signInResult)
            }
        }
    }
    
    // 에러 메시지 초기화
    func clearError() {
        self.error = nil
    }
    
    // 인증 관련 상태 최초 로그인 플래그 초기화
    func markInitialSyncComplete() {
        guard let userId = currentUser?.id else { return }
        UserDefaults.standard.set(true, forKey: "hasCompletedInitialSync_\(userId)")
        isFirstTimeLogin = false
    }
}
