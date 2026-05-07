import CoreGraphics

public enum Spacing {
    public static let xxs: CGFloat = 4
    public static let xs:  CGFloat = 8
    public static let sm:  CGFloat = 12
    public static let md:  CGFloat = 16
    public static let lg:  CGFloat = 24
    public static let xl:  CGFloat = 32
    public static let xxl: CGFloat = 48

    public static let cardCorner:    CGFloat = 16
    public static let buttonCorner:  CGFloat = 12
    /// Tighter button corner for the smaller watchOS canvas.
    public static let watchButtonCorner: CGFloat = 10
}
