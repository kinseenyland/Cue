//
//  MusicLink.swift
//  Cue
//
//  Created by Kinsee Nyland on 2/5/26.
//

enum MusicProvider: String, Codable { case spotify, appleMusic }

struct MusicLink: Codable, Hashable {
    var provider: MusicProvider
    var playlistId: String
    var playlistName: String
}
