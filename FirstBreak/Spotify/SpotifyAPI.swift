//
//  SpotifyAPI.swift
//  FirstBreak
//
//  Created by 水原　樹 on 2025/01/04.
//

//import Foundation
//import Combine
//
//class SpotifyAPI {
//    private let clientId = "8689a3c59f064e31b759b6510a41529d"
//    private let clientSecret = "6f08ead524b441738595400206ecc2a1"
//    private var accessToken: String?
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
//            .decode(type: Track.self, decoder: JSONDecoder())
//            .eraseToAnyPublisher()
//    }
//}
