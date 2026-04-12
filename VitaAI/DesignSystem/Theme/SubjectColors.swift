import SwiftUI

enum SubjectColors {
    static let palette: [Color] = [
        VitaColors.accentHover,
        VitaTokens.PrimitiveColors.cyan400,
        VitaTokens.PrimitiveColors.indigo400,
        VitaTokens.PrimitiveColors.green400,
        VitaTokens.PrimitiveColors.orange400,
        VitaTokens.PrimitiveColors.red400,
        VitaTokens.PrimitiveColors.teal400,
        VitaTokens.PrimitiveColors.amber400,
    ]

    static func colorFor(subject: String) -> Color {
        var sum: UInt32 = 0
        for byte in subject.utf8 {
            sum = (sum &* 31) &+ UInt32(byte)
        }
        return palette[Int(sum) % palette.count]
    }
}
