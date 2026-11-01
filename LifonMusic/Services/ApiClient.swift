import Foundation

public enum FetchCatalogResult {
    case success([Album])
    case maintenance(String)
    case offline
    case error(String)
}

public enum UsernameCheckResult {
    case needsPassword
    case hasPassword
    case error(String)
}

public enum AuthResult {
    case success(String)
    case error(String)
}

public final class ApiClient {
    public static let shared = ApiClient()
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        self.session = URLSession(configuration: config)
    }

    // MARK: - Catalog
    public func fetchAlbums() async -> FetchCatalogResult {
        guard let url = URL(string: "\(ApiConfig.base)/albums") else {
            return .error("Некорректный URL")
        }

        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse else {
                return .error("Ошибка ответа сервера")
            }

            if http.statusCode == 503 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let err = json["error"] as? String, err == "maintenance" {
                    let msg = json["message"] as? String ?? "Сервис временно недоступен"
                    return .maintenance(msg)
                }
            }

            guard http.statusCode == 200 else {
                return .error("Ошибка сервера (\(http.statusCode))")
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let ok = json["ok"] as? Bool, ok,
                  let arr = json["albums"] as? [[String: Any]] else {
                return .error("Неверный формат ответа")
            }

            var albums: [Album] = []
            for a in arr {
                guard let id = a["id"] as? Int,
                      let title = a["title"] as? String,
                      let year = a["year"] as? String else { continue }

                let rawCover = (a["cover_url"] as? String) ?? (a["cover"] as? String)
                let coverUrl = ApiConfig.toAbsoluteUrl(rawCover)
                let glowColor = a["glow_color"] as? String

                var tracks: [Track] = []
                if let tArr = a["tracks"] as? [[String: Any]] {
                    for t in tArr {
                        guard let tId = t["id"] as? Int,
                              let tTitle = t["title"] as? String else { continue }
                        let duration = (t["duration"] as? String) ?? "0:00"
                        let rawAudio = (t["audio_url"] as? String) ?? (t["audio"] as? String)
                        let audioUrl = ApiConfig.toAbsoluteUrl(rawAudio) ?? ""
                        let tAlbumId = (t["album_id"] as? Int) ?? (t["albumId"] as? Int) ?? id
                        let artist = (t["artist"] as? String) ?? "CUPSIZE"
                        let featArtist = t["feat_artist"] as? String
                        let tCover = ApiConfig.toAbsoluteUrl(t["cover_url"] as? String)

                        tracks.append(
                            Track(
                                id: tId,
                                title: tTitle,
                                duration: duration,
                                audioUrl: audioUrl,
                                albumId: tAlbumId,
                                artist: artist,
                                featArtist: featArtist,
                                coverUrl: tCover
                            )
                        )
                    }
                }

                albums.append(
                    Album(
                        id: id,
                        title: title,
                        year: year,
                        coverUrl: coverUrl,
                        glowColor: glowColor,
                        tracks: tracks
                    )
                )
            }

            return .success(albums)
        } catch let err as URLError {
            if err.code == .notConnectedToInternet || err.code == .timedOut || err.code == .cannotConnectToHost {
                return .offline
            }
            return .error("Ошибка сети: \(err.localizedDescription)")
        } catch {
            return .error("Ошибка загрузки: \(error.localizedDescription)")
        }
    }

    // MARK: - Auth
    public func checkUsername(_ username: String) async -> UsernameCheckResult {
        guard let url = URL(string: "\(ApiConfig.base)/auth/login") else {
            return .error("Некорректный URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["username": username]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .error("Ошибка ответа сервера")
            }

            let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            if (json["needs_password"] as? Bool) == true {
                return .needsPassword
            }
            if let err = json["error"] as? String {
                if err == "password_required" {
                    return .hasPassword
                } else if err == "invalid_credentials" {
                    return .error("Аккаунта с таким ником нет. Для регистрации — войди через браузер")
                } else if err == "telegram_only" {
                    return .error("Этот аккаунт входит только через Telegram")
                }
            }
            return .error("Ошибка (код \(http.statusCode))")
        } catch {
            return .error("Нет соединения с сервером")
        }
    }

    public func login(username: String, password: String) async -> AuthResult {
        guard let url = URL(string: "\(ApiConfig.base)/auth/login") else {
            return .error("Некорректный URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["username": username, "password": password]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .error("Ошибка ответа сервера")
            }

            let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            let ok = (json["ok"] as? Bool) ?? false

            if (200...299).contains(http.statusCode) && ok {
                if let token = json["token"] as? String, !token.isEmpty {
                    return .success(token)
                }
                return .error("Сервер не вернул токен")
            }

            let err = json["error"] as? String
            let message = json["message"] as? String
            switch err {
            case "telegram_only":
                return .error("Этот аккаунт входит только через Telegram")
            case "invalid_credentials":
                return .error("Неверный пароль")
            case "account_locked":
                return .error("Слишком много попыток. Попробуй позже")
            case "invalid_input":
                return .error(message ?? "Некорректные данные")
            default:
                if http.statusCode == 401 {
                    return .error("Неверный пароль")
                }
                return .error(message ?? "Ошибка сервера (\(http.statusCode))")
            }
        } catch {
            return .error("Нет соединения с сервером")
        }
    }

    // MARK: - Likes
    public func fetchLikes(token: String) async -> Set<Int>? {
        guard let url = URL(string: "\(ApiConfig.base)/likes") else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let arr = json["liked"] as? [Int] else { return nil }
            return Set(arr)
        } catch {
            return nil
        }
    }

    public func addLike(token: String, trackId: Int) async -> Bool {
        await sendLikeRequest(method: "POST", token: token, trackId: trackId)
    }

    public func removeLike(token: String, trackId: Int) async -> Bool {
        await sendLikeRequest(method: "DELETE", token: token, trackId: trackId)
    }

    private func sendLikeRequest(method: String, token: String, trackId: Int) async -> Bool {
        guard let url = URL(string: "\(ApiConfig.base)/likes") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        let body = ["track_id": trackId]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            return (200...299).contains(http.statusCode)
        } catch {
            return false
        }
    }

    // MARK: - Listen Tracking & Stats
    public func recordListen(token: String, trackId: Int, durationMs: Int64) async -> Bool {
        guard let url = URL(string: "\(ApiConfig.base)/listens") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "track_id": trackId,
            "duration_ms": durationMs,
            "platform": "ios"
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            return (200...299).contains(http.statusCode)
        } catch {
            return false
        }
    }

    public func fetchStats(token: String) async -> StatsResult? {
        guard let url = URL(string: "\(ApiConfig.base)/stats") else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            return try? JSONDecoder().decode(StatsResult.self, from: data)
        } catch {
            return nil
        }
    }

    // MARK: - Achievements
    public func fetchAllAchievements() async -> [Achievement] {
        guard let url = URL(string: "\(ApiConfig.base)/achievements") else { return [] }
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return [] }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let arr = json["achievements"] as? [[String: Any]] else { return [] }
            let arrData = try JSONSerialization.data(withJSONObject: arr)
            return (try? JSONDecoder().decode([Achievement].self, from: arrData)) ?? []
        } catch {
            return []
        }
    }

    public func fetchMyAchievements(token: String) async -> [UserAchievement] {
        guard let url = URL(string: "\(ApiConfig.base)/achievements/my") else { return [] }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return [] }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let arr = json["achievements"] as? [[String: Any]] else { return [] }
            let arrData = try JSONSerialization.data(withJSONObject: arr)
            return (try? JSONDecoder().decode([UserAchievement].self, from: arrData)) ?? []
        } catch {
            return []
        }
    }

    // MARK: - Notifications & Online Ping
    public func fetchBroadcastNotification() async -> BroadcastNotification? {
        guard let url = URL(string: "\(ApiConfig.base)/notification") else { return nil }
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let items = json["items"] as? [[String: Any]],
                  let first = items.first,
                  let id = first["id"] as? Int,
                  let title = first["title"] as? String,
                  !title.isEmpty else { return nil }
            let body = (first["body"] as? String) ?? ""
            return BroadcastNotification(id: id, title: title, body: body)
        } catch {
            return nil
        }
    }

    public func pingProfile(token: String) async {
        guard let url = URL(string: "\(ApiConfig.base)/profile/ping") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        _ = try? await session.data(for: request)
    }

    // MARK: - Wave
    public func fetchWaveTracks() async -> [Track]? {
        guard let url = URL(string: "\(ApiConfig.base)/wave") else { return nil }
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let ok = json["ok"] as? Bool, ok,
                  (json["enabled"] as? Bool) ?? true,
                  let arr = json["tracks"] as? [[String: Any]] else { return nil }

            var tracks: [Track] = []
            for t in arr {
                guard let tId = t["id"] as? Int,
                      let tTitle = t["title"] as? String else { continue }
                let duration = (t["duration"] as? String) ?? "0:00"
                let rawAudio = (t["audio_url"] as? String) ?? (t["audio"] as? String)
                guard let audioUrl = ApiConfig.toAbsoluteUrl(rawAudio), !audioUrl.isEmpty else { continue }
                let tAlbumId = (t["album_id"] as? Int) ?? (t["albumId"] as? Int) ?? 0
                let artist = (t["artist"] as? String) ?? "CUPSIZE"
                let featArtist = t["feat_artist"] as? String
                let tCover = ApiConfig.toAbsoluteUrl(t["cover_url"] as? String)

                tracks.append(
                    Track(
                        id: tId,
                        title: tTitle,
                        duration: duration,
                        audioUrl: audioUrl,
                        albumId: tAlbumId,
                        artist: artist,
                        featArtist: featArtist,
                        coverUrl: tCover
                    )
                )
            }
            return tracks.isEmpty ? nil : tracks.shuffled()
        } catch {
            return nil
        }
    }

    // MARK: - Playlists
    public func fetchPlaylists(token: String) async -> [UserPlaylist] {
        guard let url = URL(string: "\(ApiConfig.base)/playlists") else { return [] }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return [] }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let ok = json["ok"] as? Bool, ok,
                  let arr = json["playlists"] as? [[String: Any]] else { return [] }

            return arr.compactMap { item in
                guard let publicId = item["public_id"] as? String, !publicId.isEmpty else { return nil }
                let id = (item["id"] as? Int) ?? 0
                let title = (item["title"] as? String) ?? "Без названия"
                let trackCount = item["track_count"] as? Int
                return UserPlaylist(id: id, title: title, publicId: publicId, trackCount: trackCount)
            }
        } catch {
            return []
        }
    }

    public func createPlaylist(token: String, title: String) async -> UserPlaylist? {
        guard let url = URL(string: "\(ApiConfig.base)/playlists") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let body = ["title": title.trimmingCharacters(in: .whitespacesAndNewlines)]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let ok = json["ok"] as? Bool, ok,
                  let publicId = json["public_id"] as? String, !publicId.isEmpty else { return nil }
            return UserPlaylist(id: 0, title: title.trimmingCharacters(in: .whitespacesAndNewlines), publicId: publicId, trackCount: 0)
        } catch {
            return nil
        }
    }

    public func deletePlaylist(token: String, publicId: String) async -> Bool {
        guard let url = URL(string: "\(ApiConfig.base)/playlists/\(publicId)") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return false }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let ok = json["ok"] as? Bool else { return false }
            return ok
        } catch {
            return false
        }
    }

    public func addTrackToPlaylist(token: String, publicId: String, trackId: Int) async -> Bool {
        guard let url = URL(string: "\(ApiConfig.base)/playlists/\(publicId)/tracks") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let body = ["track_id": trackId]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return false }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let ok = json["ok"] as? Bool else { return false }
            return ok
        } catch {
            return false
        }
    }

    public func fetchPlaylistTracks(publicId: String) async -> [Int] {
        guard let url = URL(string: "\(ApiConfig.base)/playlist/\(publicId)") else { return [] }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return [] }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let ok = json["ok"] as? Bool, ok,
                  let arr = json["tracks"] as? [Int] else { return [] }
            return arr
        } catch {
            return []
        }
    }

    // MARK: - Playback Sync
    public func fetchPlaybackSync(token: String) async -> RemotePlaybackState? {
        guard let url = URL(string: "\(ApiConfig.base)/profile/playback") else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let ok = json["ok"] as? Bool, ok,
                  let state = json["state"] as? [String: Any],
                  let trackId = state["track_id"] as? Int, trackId > 0 else { return nil }

            let pos = (state["position_ms"] as? NSNumber)?.int64Value ?? 0
            let playing = (state["is_playing"] as? Bool) ?? false
            let updated = (state["updated_at"] as? NSNumber)?.int64Value ?? 0
            return RemotePlaybackState(trackId: trackId, positionMs: pos, isPlaying: playing, updatedAt: updated)
        } catch {
            return nil
        }
    }

    public func savePlaybackSync(token: String, trackId: Int, positionMs: Int64, isPlaying: Bool) async -> Bool {
        guard let url = URL(string: "\(ApiConfig.base)/profile/playback") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "track_id": trackId,
            "position_ms": min(max(positionMs, 0), 86_400_000),
            "is_playing": isPlaying
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            return (200...299).contains(http.statusCode)
        } catch {
            return false
        }
    }

    // MARK: - Profile Details, Avatar & Supporters
    public func fetchProfileDetails(token: String) async -> (username: String?, avatarUrl: String?, listenMs: Int64?) {
        guard let url = URL(string: "\(ApiConfig.base)/profile") else { return (nil, nil, nil) }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return (nil, nil, nil) }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let ok = json["ok"] as? Bool, ok,
                  let user = json["user"] as? [String: Any] else { return (nil, nil, nil) }

            let username = user["username"] as? String
            let rawAvatar = user["avatar_url"] as? String
            let avatarUrl = ApiConfig.toAbsoluteUrl(rawAvatar)
            let totals = json["totals"] as? [String: Any]
            let listenMs = (totals?["listen_ms"] as? NSNumber)?.int64Value

            return (username, avatarUrl, listenMs)
        } catch {
            return (nil, nil, nil)
        }
    }

    public func uploadAvatar(token: String, imageData: Data) async -> String? {
        guard let url = URL(string: "\(ApiConfig.base)/profile/avatar") else { return nil }
        let boundary = "----LifonMUSICiOS\(Int(Date().timeIntervalSince1970 * 1000))"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"avatar.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let ok = json["ok"] as? Bool, ok,
                  let raw = json["avatar_url"] as? String else { return nil }
            return ApiConfig.toAbsoluteUrl(raw)
        } catch {
            return nil
        }
    }

    public func fetchSupporters() async -> [Supporter] {
        guard let url = URL(string: "\(ApiConfig.base)/supporters") else { return [] }
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return [] }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let ok = json["ok"] as? Bool, ok,
                  let arr = json["supporters"] as? [[String: Any]] else { return [] }

            return arr.compactMap { item in
                guard let name = item["name"] as? String, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
                let handle = (item["handle"] as? String) ?? ""
                let color = (item["color"] as? String) ?? "#8b5cf6"
                return Supporter(name: name, handle: handle, color: color)
            }
        } catch {
            return []
        }
    }

    // MARK: - Remote Lyrics
    public func fetchRemoteLyrics(trackId: Int) async -> String? {
        guard let url = URL(string: "\(ApiConfig.base)/albums/tracks/\(trackId)/lyrics") else { return nil }
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let lrc = json["lrc"] as? String,
                  !lrc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return lrc
        } catch {
            return nil
        }
    }
}
