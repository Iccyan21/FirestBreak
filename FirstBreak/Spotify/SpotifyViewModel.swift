//
//  SpotifyViewModel.swift
//  FirstBreak
//
//  Created by 水原　樹 on 2025/01/04.
//

//import Foundation
//import Combine
//
//class SpotifyViewModel: ObservableObject {
//    @Published var currentTrack: Track?
//    private var cancellables = Set<AnyCancellable>()
//    private let spotifyAPI = SpotifyAPI()
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
