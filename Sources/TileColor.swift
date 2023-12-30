#if os(Linux)
import Glibc.ncurses
#else
import Darwin.ncurses
#endif

enum TileColor {
    static var colorIndex: Int16 = 2
    static var colorPairIndex: [Int: Int32] = [:]
    static var colorFgColorIndex: [Color: Int16] = [:]
    static var colorBgColorIndex: [Color: Int16] = [:]

    struct Color: Hashable {
        let red: Int16
        let green: Int16
        let blue: Int16
    }

    static func setColor(forTile tile: Int) {
        if let calculatedColor = colorPairIndex[tile] {
            attron(COLOR_PAIR(calculatedColor))
        } else {
            // Check for fg and bg colors, if not indexed add them
            // Then add the pair.
            let fgIndex: Int16
            let bgIndex: Int16

            let fgColor = foregroundColor(forTile: tile)
            let bgColor = backgroundColor(forTile: tile)

            if let cachedFgIndex = colorFgColorIndex[fgColor] {
                fgIndex = cachedFgIndex
            } else {
                init_color(colorIndex, fgColor.red, fgColor.green, fgColor.blue)
                colorFgColorIndex[fgColor] = colorIndex
                fgIndex = colorIndex
                colorIndex += 1
            }

            if let cachedBgIndex = colorFgColorIndex[bgColor] {
                bgIndex = cachedBgIndex
            } else {
                init_color(colorIndex, bgColor.red, bgColor.green, bgColor.blue)
                colorBgColorIndex[bgColor] = colorIndex
                bgIndex = colorIndex
                colorIndex += 1
            }

            init_pair(colorIndex, fgIndex, bgIndex)
            colorPairIndex[tile] = Int32(colorIndex)
            colorIndex += 1
            attron(COLOR_PAIR((colorPairIndex[tile]!)))
        }
    }

    static func unsetColor(forTile tile: Int) {
        attroff(COLOR_PAIR(colorPairIndex[tile]!))
    }

    /// Returns red, green, blue background color values for a given tile value.
    /// - Parameter tile: The tile to create the color for.
    /// - Returns: The color for the tile value.
    static func backgroundColor(forTile tile: Int) -> Color { // swiftlint:disable:this cyclomatic_complexity
        let hex: Int
        switch tile {
        case 0:
            hex = 0xccc1b4
        case 1:
            hex = 0xeee4da
        case 2:
            hex = 0xeee1c9
        case 3:
            hex = 0xf3b27a
        case 4:
            hex = 0xf69664
        case 5:
            hex = 0xf77c5f
        case 6:
            hex = 0xf75f3b
        case 7:
            hex = 0xedd073
        case 8:
            hex = 0xedcc62
        case 9:
            hex = 0xedc950
        case 10:
            hex = 0xedc53f
        case 11:
            hex = 0xedc22e
        default:
            hex = 0x3c3a33
        }

        let red = (Float((hex >> 16) & 0xFF)/255) * 1000.0
        let green = (Float((hex >> 8) & 0xFF)/255.0) * 1000.0
        let blue = (Float(hex & 0xFF)/255.0) * 1000.0

        return Color(red: Int16(red), green: Int16(green), blue: Int16(blue))
    }

    /// Returns red, green, blue text color values for a given tile value.
    /// - Parameter tile: The tile to create the color for.
    /// - Returns: The color for the tile value.
    static func foregroundColor(forTile tile: Int) -> Color {
        let hex: Int
        switch tile {
        case 0:
            hex = 0xFFFFFF
        case 1, 2:
            hex = 0x776e65
        case 3, 4, 5, 6, 7, 8, 9, 10, 11:
            hex = 0xf9f6f2
        default:
            hex = 0xf9f6f2
        }

        let red = (Float((hex >> 16) & 0xFF)/255) * 1000.0
        let green = (Float((hex >> 8) & 0xFF)/255.0) * 1000.0
        let blue = (Float(hex & 0xFF)/255.0) * 1000.0

        return Color(red: Int16(red), green: Int16(green), blue: Int16(blue))
    }
}
