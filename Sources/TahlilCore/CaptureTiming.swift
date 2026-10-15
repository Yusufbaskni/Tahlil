import Foundation

public enum CaptureTiming {
    /// Islatma sonrası kalan saniye. `nil` henüz sayaç başlamadı demektir.
    public static func remainingSeconds(
        waitSeconds: Int,
        startedAt: Date?,
        now: Date = Date()
    ) -> Int? {
        guard waitSeconds > 0 else { return 0 }
        guard let startedAt else { return nil }
        let elapsed = now.timeIntervalSince(startedAt)
        return max(0, Int(ceil(Double(waitSeconds) - elapsed)))
    }

    public static func isReady(
        waitSeconds: Int,
        startedAt: Date?,
        now: Date = Date(),
        skipWait: Bool = false
    ) -> Bool {
        if skipWait || waitSeconds <= 0 { return true }
        guard let remaining = remainingSeconds(waitSeconds: waitSeconds, startedAt: startedAt, now: now) else {
            return false
        }
        return remaining == 0
    }

    public static func statusText(
        waitSeconds: Int,
        startedAt: Date?,
        now: Date = Date(),
        skipWait: Bool = false
    ) -> String {
        if skipWait {
            return "Bekleme atlandı (yalnızca test)."
        }
        if waitSeconds <= 0 {
            return "Bu şablon için bekleme gerekmiyor."
        }
        guard let remaining = remainingSeconds(waitSeconds: waitSeconds, startedAt: startedAt, now: now) else {
            return "Çubuğu ıslattıktan sonra sayacı başlatın. Okuma için \(waitSeconds) sn bekleyin."
        }
        if remaining == 0 {
            return "Bekleme tamam. Çekebilirsiniz."
        }
        return "Bekleme: \(remaining) sn"
    }
}
