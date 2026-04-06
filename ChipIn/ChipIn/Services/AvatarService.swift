import Foundation
import UIKit
import Supabase

struct AvatarService {
    /// Uploads a JPEG avatar to the avatars storage bucket and returns the public URL string.
    func uploadAvatar(userId: UUID, image: UIImage) async throws -> String {
        guard let data = image
            .chipInReceiptPrepared(maxDimension: 400)
            .chipInJPEGDataForReceipt(quality: 0.85) else {
            throw NSError(domain: "AvatarService", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Image conversion failed"])
        }
        let path = "\(userId.uuidString.lowercased())/avatar.jpg"
        do {
            try await supabase.storage
                .from("avatars")
                .upload(path, data: data, options: FileOptions(contentType: "image/jpeg", upsert: true))
        } catch {
            throw Self.wrap(error, kind: .upload)
        }
        let publicURL: URL
        do {
            publicURL = try supabase.storage.from("avatars").getPublicURL(path: path)
        } catch {
            throw Self.wrap(error, kind: .upload)
        }
        return publicURL.absoluteString + "?t=\(Int(Date().timeIntervalSince1970))"
    }

    /// Persists the avatar URL in the users table.
    func saveAvatarURL(userId: UUID, url: String) async throws {
        do {
            try await supabase
                .from("users")
                .update(["avatar_url": url])
                .eq("id", value: userId)
                .execute()
        } catch {
            throw Self.wrap(error, kind: .profile)
        }
    }

    private enum Kind { case upload, profile }

    private static func wrap(_ error: Error, kind: Kind) -> NSError {
        let raw = error.localizedDescription
        if raw.contains("row-level security") || raw.contains("new row violates") {
            switch kind {
            case .upload:
                return NSError(
                    domain: "AvatarService",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey:
                        "Couldn’t upload the photo (storage blocked). In Supabase: create bucket `avatars` (public read), then run the SQL policies so paths look like `{your user id}/avatar.jpg`. See repo `supabase/migrations/017_avatar_rls_fix.sql`."
                    ]
                )
            case .profile:
                return NSError(
                    domain: "AvatarService",
                    code: 3,
                    userInfo: [NSLocalizedDescriptionKey:
                        "Photo uploaded but profile couldn’t be updated (database rules). Run the `users_modify` policy fix in `017_avatar_rls_fix.sql`."
                    ]
                )
            }
        }
        return NSError(domain: "AvatarService", code: 9, userInfo: [NSLocalizedDescriptionKey: raw])
    }
}
