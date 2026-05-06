import SwiftUI

struct SkeletonBlock: View {
    var width: CGFloat? = nil
    var height: CGFloat = 16
    var corner: CGFloat = 8

    var body: some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(Color.inkMuted.opacity(0.18))
            .frame(width: width, height: height)
            .redacted(reason: .placeholder)
    }
}

extension View {
    /// Wraps the view in a skeleton state when `isLoading` is true.
    func skeleton(_ isLoading: Bool) -> some View {
        self.redacted(reason: isLoading ? .placeholder : [])
    }
}
