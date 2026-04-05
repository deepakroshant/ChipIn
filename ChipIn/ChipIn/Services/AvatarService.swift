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
        let path = "\(userId.uuidString)/avatar.jpg"
        try await supabase.storage
            .from("avatars")
            .upload(path, data: data, options: FileOptions(contentType: "image/jpeg", upsert: true))
        let publicURL = try supabase.storage.from("avatars").getPublicURL(path: path)
        // Cache-bust with timestamp so AsyncImage picks up the new photo
        return publicURL.absoluteString + "?t=\(Int(Date().timeIntervalSince1970))"
    }

    /// Persists the avatar URL in the users table.
    func saveAvatarURL(userId: UUID, url: String) async throws {
        try await supabase
            .from("users")
            .update(["avatar_url": url])
            .eq("id", value: userId)
            .execute()
    }
}
