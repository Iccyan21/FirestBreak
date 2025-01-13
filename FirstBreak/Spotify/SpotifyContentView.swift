//
//  SpotifyContentView.swift
//  FirstBreak
//
//  Created by 水原　樹 on 2025/01/04.
//

//import SwiftUI
//import ARKit
//import RealityKit
//import SafariServices
//
//struct SpotifyContentView: View {
//    @StateObject private var spotifyViewModel = SpotifyViewModel()
//    @StateObject private var arViewModel = ARViewModel()
//    
//    var body: some View {
//        ZStack {
//            ARViewContainer(arViewModel: arViewModel)
//                .edgesIgnoringSafeArea(.all)
//            
//            if let currentTrack = spotifyViewModel.currentTrack {
//                VStack {
//                    Spacer()
//                    TrackInfoView(track: currentTrack)
//                }
//            } else {
//                VStack {
//                    Spacer()
//                    Button(action: {
//                        spotifyViewModel.login()
//                    }) {
//                        Text("Login with Spotify")
//                            .foregroundColor(.white)
//                            .padding()
//                            .background(Color.green)
//                            .cornerRadius(8)
//                    }
//                    .padding()
//                }
//            }
//        }
//    }
//}
//
//
//// ARViewContainer.swift
//import SwiftUI
//import ARKit
//import RealityKit
//
//struct ARViewContainer: UIViewRepresentable {
//    @ObservedObject var arViewModel: ARViewModel
//    
//    func makeUIView(context: Context) -> ARView {
//        let arView = ARView(frame: .zero)
//        let config = ARWorldTrackingConfiguration()
//        arView.session.run(config)
//        return arView
//    }
//    
//    func updateUIView(_ uiView: ARView, context: Context) {
//        if let trackInfo = arViewModel.currentTrackInfo {
//            updateTrackAnchor(in: uiView, with: trackInfo)
//        }
//    }
//    
//    private func updateTrackAnchor(in arView: ARView, with trackInfo: TrackInfo) {
//        // Remove existing anchors
//        arView.scene.anchors.removeAll()
//        
//        // Create text entity
//        let textMesh = MeshResource.generateText(
//            trackInfo.title,
//            extrusionDepth: 0.01,
//            font: .systemFont(ofSize: 0.1),
//            containerFrame: .zero,
//            alignment: .center,
//            lineBreakMode: .byTruncatingTail
//        )
//        
//        let textMaterial = SimpleMaterial(color: .white, isMetallic: true)
//        let textEntity = ModelEntity(mesh: textMesh, materials: [textMaterial])
//        
//        // Create anchor and add to scene
//        let anchor = AnchorEntity(plane: .horizontal)
//        anchor.addChild(textEntity)
//        arView.scene.addAnchor(anchor)
//    }
//}
//
//// SpotifyViewModel.swift
//import Foundation
//import Combine
//
//class SpotifyViewModel: ObservableObject {
//    @Published var currentTrack: Track?
//    private var cancellables = Set<AnyCancellable>()
//    private let spotifyAPI = SpotifyAPI()
//    
//    func login() {
//        spotifyAPI.startAuth()
//    }
//    
//    func startListening() {
//        Timer.publish(every: 1.0, on: .main, in: .common)
//            .autoconnect()
//            .sink { [weak self] _ in
//                self?.getCurrentTrack()
//            }
//            .store(in: &cancellables)
//    }
//    
//    private func getCurrentTrack() {
//        spotifyAPI.getCurrentTrack()
//            .receive(on: DispatchQueue.main)
//            .sink(
//                receiveCompletion: { completion in
//                    if case .failure(let error) = completion {
//                        print("Error fetching current track: \(error)")
//                    }
//                },
//                receiveValue: { [weak self] track in
//                    self?.currentTrack = track
//                }
//            )
//            .store(in: &cancellables)
//    }
//}
//
//// SpotifyAPI.swift
//import Foundation
//import Combine
//
//class SpotifyAPI {
//    private let clientId = "YOUR_CLIENT_ID"
//    private let clientSecret = "YOUR_CLIENT_SECRET"
//    private let redirectUri = "firstbreak://callback"
//    private var accessToken: String?
//    private var cancellables = Set<AnyCancellable>()
//    
//    // 認証開始
//    func startAuth() {
//        let scopes = "user-read-currently-playing user-read-playback-state"
//        
//        // Spotifyアプリを直接開くためのURL
//        let spotifyAuthURL = "spotify:authorize" +
//        "?client_id=\(clientId)" +
//        "&response_type=code" +
//        "&redirect_uri=firstbreak://callback" +
//        "&scope=\(scopes)"
//        
//        guard let url = URL(string: spotifyAuthURL) else {
//            print("Invalid Spotify auth URL")
//            return
//        }
//        
//        // Spotifyアプリを開く
//        UIApplication.shared.open(url) { success in
//            if !success {
//                print("Failed to open Spotify app")
//            }
//        }
//    }
//    
//    // 認証コードをアクセストークンと交換
//    func handleAuthCallback(code: String) {
//        guard let url = URL(string: "https://accounts.spotify.com/api/token") else {
//            return
//        }
//        
//        // Basic認証用のヘッダーを作成
//        let authString = "\(clientId):\(clientSecret)".data(using: .utf8)?.base64EncodedString() ?? ""
//        
//        var request = URLRequest(url: url)
//        request.httpMethod = "POST"
//        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
//        request.setValue("Basic \(authString)", forHTTPHeaderField: "Authorization")
//        
//        // リクエストボディの作成
//        let bodyParams = [
//            "grant_type": "authorization_code",
//            "code": code,
//            "redirect_uri": redirectUri
//        ]
//        request.httpBody = bodyParams
//            .map { "\($0.key)=\($0.value)" }
//            .joined(separator: "&")
//            .data(using: .utf8)
//        
//        // トークン取得リクエストの実行
//        URLSession.shared.dataTaskPublisher(for: request)
//            .map(\.data)
//            .decode(type: TokenResponse.self, decoder: JSONDecoder())
//            .receive(on: DispatchQueue.main)
//            .sink(
//                receiveCompletion: { completion in
//                    if case .failure(let error) = completion {
//                        print("Token exchange error: \(error)")
//                    }
//                },
//                receiveValue: { [weak self] response in
//                    self?.accessToken = response.access_token
//                    // トークン取得成功を通知
//                    NotificationCenter.default.post(name: .spotifyAuthSucceeded, object: nil)
//                }
//            )
//            .store(in: &cancellables)
//    }
//    
//    func getCurrentTrack() -> AnyPublisher<Track, Error> {
//        guard let accessToken = accessToken else {
//            return authenticate()
//                .flatMap { [weak self] token -> AnyPublisher<Track, Error> in
//                    self?.accessToken = token
//                    return self?.fetchCurrentTrack(token: token) ?? Fail(error: APIError.unauthorized).eraseToAnyPublisher()
//                }
//                .eraseToAnyPublisher()
//        }
//        
//        return fetchCurrentTrack(token: accessToken)
//    }
//    
//    private func authenticate() -> AnyPublisher<String, Error> {
//        guard let authString = "\(clientId):\(clientSecret)"
//            .data(using: .utf8)?
//            .base64EncodedString() else {
//            return Fail(error: APIError.unauthorized).eraseToAnyPublisher()
//        }
//        
//        guard let url = URL(string: "https://accounts.spotify.com/api/token") else {
//            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
//        }
//        
//        var request = URLRequest(url: url)
//        request.httpMethod = "POST"
//        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
//        request.setValue("Basic \(authString)", forHTTPHeaderField: "Authorization")
//        request.httpBody = "grant_type=client_credentials".data(using: .utf8)
//        
//        return URLSession.shared.dataTaskPublisher(for: request)
//            .map(\.data)
//            .decode(type: AuthResponse.self, decoder: JSONDecoder())
//            .map(\.access_token)
//            .eraseToAnyPublisher()
//    }
//    
//    private struct AuthResponse: Codable {
//        let access_token: String
//        let token_type: String
//        let expires_in: Int
//    }
//    
//    struct SpotifyError: Codable {
//        let error: ErrorDetails
//    }
//    
//    struct ErrorDetails: Codable {
//        let status: Int
//        let message: String
//    }
//    
//    private func fetchCurrentTrack(token: String) -> AnyPublisher<Track, Error> {
//        guard let url = URL(string: "https://api.spotify.com/v1/me/player/currently-playing") else {
//            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
//        }
//        
//        var request = URLRequest(url: url)
//        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
//        
//        return URLSession.shared.dataTaskPublisher(for: request)
//            .map(\.data)
//            .handleEvents(receiveOutput: { data in
//                if let json = try? JSONSerialization.jsonObject(with: data, options: .allowFragments),
//                   let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
//                   let prettyString = String(data: prettyData, encoding: .utf8) {
//                    print("Raw Response JSON:")
//                    print(prettyString)
//                }
//            })
//            .tryMap { data -> Track in
//                // まずエラーレスポンスかどうかを確認
//                if let error = try? JSONDecoder().decode(SpotifyError.self, from: data) {
//                    throw APIError.spotifyError(message: error.error.message)
//                }
//                
//                // 正常なレスポンスの場合
//                guard let response = try? JSONDecoder().decode(SpotifyResponse.self, from: data),
//                      let track = response.item else {
//                    throw APIError.invalidResponse
//                }
//                
//                return track
//            }
//            .mapError { error -> Error in
//                if let apiError = error as? APIError {
//                    return apiError
//                }
//                return APIError.unknown
//            }
//            .eraseToAnyPublisher()
//    }
//    
//    enum APIError: Error {
//        case invalidURL
//        case unauthorized
//        case unknown
//        case noData
//        case invalidResponse
//        case spotifyError(message: String)
//        
//        var localizedDescription: String {
//            switch self {
//            case .invalidURL:
//                return "Invalid URL"
//            case .unauthorized:
//                return "Unauthorized"
//            case .unknown:
//                return "Unknown error occurred"
//            case .noData:
//                return "No data received"
//            case .invalidResponse:
//                return "Invalid response from server"
//            case .spotifyError(let message):
//                return "Spotify error: \(message)"
//            }
//        }
//    }
//    
//}
//
//// SceneDelegate.swift
//class SceneDelegate: UIResponder, UIWindowSceneDelegate {
//    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
//        guard let url = URLContexts.first?.url,
//              let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
//              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
//            return
//        }
//        
//        // SpotifyAPIインスタンスを取得して認証コードを処理
//        if let spotifyAPI = (UIApplication.shared.delegate as? AppDelegate)?.spotifyAPI {
//            spotifyAPI.handleAuthCallback(code: code)
//        }
//    }
//}
//
//// AppDelegate.swift
//class AppDelegate: UIResponder, UIApplicationDelegate {
//    var spotifyAPI: SpotifyAPI?
//    
//    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
//        spotifyAPI = SpotifyAPI()
//        return true
//    }
//}
//
//// TokenResponse.swift
//struct TokenResponse: Codable {
//    let access_token: String
//    let token_type: String
//    let scope: String
//    let expires_in: Int
//    let refresh_token: String?
//}
//
//// Notification extension
//extension Notification.Name {
//    static let spotifyAuthSucceeded = Notification.Name("spotifyAuthSucceeded")
//}
//
//// Models.swift
//struct SpotifyResponse: Codable {
//    let item: Track?
//    let is_playing: Bool
//}
//
//struct Track: Codable {
//    let name: String
//    let album: Album
//    let artists: [Artist]
//    let duration_ms: Int?
//}
//
//struct Album: Codable {
//    let name: String
//    let images: [SpotifyImage]
//}
//
//struct Artist: Codable {
//    let name: String
//}
//
//struct SpotifyImage: Codable {
//    let url: String
//    let height: Int
//    let width: Int
//}
//
//enum APIError: Error {
//    case invalidURL
//    case unauthorized
//    case unknown
//}
//
//// TrackInfoView.swift
//struct TrackInfoView: View {
//    let track: Track
//    
//    var body: some View {
//        VStack(spacing: 8) {
//            AsyncImage(url: URL(string: track.album.images.first?.url ?? "")) { image in
//                image
//                    .resizable()
//                    .aspectRatio(contentMode: .fit)
//                    .frame(width: 200, height: 200)
//                    .cornerRadius(8)
//            } placeholder: {
//                ProgressView()
//            }
//            
//            Text(track.name)
//                .font(.title2)
//                .bold()
//            
//            Text(track.artists.map(\.name).joined(separator: ", "))
//                .font(.subheadline)
//                .foregroundColor(.secondary)
//        }
//        .padding()
//        .background(.ultraThinMaterial)
//        .cornerRadius(16)
//        .padding()
//    }
//}
//
//// ARViewModel.swift
//import Foundation
//
//class ARViewModel: ObservableObject {
//    @Published var currentTrackInfo: TrackInfo?
//    
//    func updateTrackInfo(_ track: Track) {
//        currentTrackInfo = TrackInfo(
//            title: track.name,
//            artist: track.artists.map(\.name).joined(separator: ", "),
//            albumArtURL: track.album.images.first?.url
//        )
//    }
//}
//
//struct TrackInfo {
//    let title: String
//    let artist: String
//    let albumArtURL: String?
//}
