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
    
    private var authStateHandler: AuthStateDidChangeListenerHandle?
    
    private init() {
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
                        self.currentUser = User(from: firebaseUser) //
                        self.isLoggedIn = true
                        
                        if UserDefaults.standard.object(forKey: "hasCompletedInitialSync_\(firebaseUser.uid)") == nil {
                            self.isFirstTimeLogin = true
                        }
                    } else {
                        self.currentUser = nil
                        self.isLoggedIn = false
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
        return currentUser?.displayName ?? "사용자"
    }
    
    // 사용자 이메일 반환
    var email: String {
        return currentUser?.email ?? ""
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
            
            await MainActor.run {
                self.currentUser = User(from: result.user)
                self.isLoggedIn = true
                self.isLoading = false
            }
            
            // 여기서 직접 사용자 프로필 저장
            let db = Firestore.firestore()
            try await db.collection("users").document(result.user.uid).setData([
                "displayName": result.user.displayName ?? "사용자",
                "email": result.user.email ?? "",
                "lastActive": FieldValue.serverTimestamp()
            ], merge: true)
            
            return true
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
            return false
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
    
    // MARK: - Google 로그인
    func signInWithGoogle() async -> Bool {
        await MainActor.run {
            self.isLoading = true
        }
        
        do {
            // 루트 뷰 컨트롤러 가져오기
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController else {
                await MainActor.run {
                    self.error = NSError(domain: "AuthManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "No root view controller found"])
                    self.isLoading = false
                }
                return false
            }
            
            // 구글 로그인 SDK 호출 - 타입 명시
            let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<GIDSignInResult, Error>) in
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
            
            // 구글 인증 정보 가져오기
            guard let idToken = result.user.idToken?.tokenString else {
                throw NSError(domain: "AuthManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "No ID token"])
            }
            
            // Firebase에 구글 인증 정보로 로그인
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: result.user.accessToken.tokenString)
            let authResult = try await Auth.auth().signIn(with: credential)
            
            // 유저 정보 저장
            await MainActor.run {
                self.currentUser = User(from: authResult.user)
                self.isLoggedIn = true
                self.isLoading = false
            }
            
            // Firestore에 사용자 정보 저장
            let db = Firestore.firestore()
            try await db.collection("users").document(authResult.user.uid).setData([
                "displayName": authResult.user.displayName ?? "사용자",
                "email": authResult.user.email ?? "",
                "lastActive": FieldValue.serverTimestamp()
            ], merge: true)
            
            return true
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
            return false
        }
    }
}
