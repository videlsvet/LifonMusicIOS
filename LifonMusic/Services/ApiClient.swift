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
