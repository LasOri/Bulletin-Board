import LINKER

public struct Icons {

    private static func svg(size: Int = 16, paths: [String], fill: Bool = false) -> Element<AnyHTMLContext> {
        let strokeAttrs: [Attribute] = fill ? [] : [
            Attribute(name: "stroke", value: "currentColor"),
            Attribute(name: "stroke-width", value: "2"),
            Attribute(name: "stroke-linecap", value: "round"),
            Attribute(name: "stroke-linejoin", value: "round"),
            Attribute(name: "fill", value: "none")
        ]

        let fillAttrs: [Attribute] = fill ? [
            Attribute(name: "fill", value: "currentColor")
        ] : []

        var attrs: [Attribute] = [
            Attribute(name: "xmlns", value: "http://www.w3.org/2000/svg"),
            Attribute(name: "viewBox", value: "0 0 24 24"),
            Attribute(name: "width", value: "\(size)"),
            Attribute(name: "height", value: "\(size)")
        ]
        attrs.append(contentsOf: strokeAttrs)
        attrs.append(contentsOf: fillAttrs)

        let pathElements: [AnyNode] = paths.map { d in
            AnyNode(Element<AnyHTMLContext>(
                tag: "path",
                attributes: [Attribute(name: "d", value: d)],
                children: []
            ))
        }

        return Element<AnyHTMLContext>(
            tag: "svg",
            attributes: attrs,
            children: pathElements
        )
    }

    public static func plus(size: Int = 16) -> Element<AnyHTMLContext> {
        svg(size: size, paths: ["M12 5v14", "M5 12h14"])
    }

    public static func refresh(size: Int = 16) -> Element<AnyHTMLContext> {
        svg(size: size, paths: [
            "M1 4v6h6",
            "M23 20v-6h-6",
            "M20.49 9A9 9 0 0 0 5.64 5.64L1 10",
            "M23 14l-4.64 4.36A9 9 0 0 1 3.51 15"
        ])
    }

    public static func checkAll(size: Int = 16) -> Element<AnyHTMLContext> {
        svg(size: size, paths: [
            "M18 7l-8 8-4-4",
            "M22 7l-8 8",
            "M12 15l-2 2-4-4"
        ])
    }

    public static func mail(size: Int = 16) -> Element<AnyHTMLContext> {
        svg(size: size, paths: [
            "M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z",
            "M22 6l-10 7L2 6"
        ])
    }

    public static func star(filled: Bool = false, size: Int = 16) -> Element<AnyHTMLContext> {
        let path = "M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"
        if filled {
            return svg(size: size, paths: [path], fill: true)
        }
        return svg(size: size, paths: [path])
    }

    public static func archive(size: Int = 16) -> Element<AnyHTMLContext> {
        svg(size: size, paths: [
            "M21 8v13H3V8",
            "M1 3h22v5H1z",
            "M10 12h4"
        ])
    }

    public static func unarchive(size: Int = 16) -> Element<AnyHTMLContext> {
        svg(size: size, paths: [
            "M21 8v13H3V8",
            "M1 3h22v5H1z",
            "M12 11v6",
            "M9 14l3-3 3 3"
        ])
    }

    public static func settings(size: Int = 16) -> Element<AnyHTMLContext> {
        svg(size: size, paths: [
            "M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6z",
            "M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"
        ])
    }

    public static func grid(size: Int = 16) -> Element<AnyHTMLContext> {
        svg(size: size, paths: [
            "M3 3h7v7H3z",
            "M14 3h7v7h-7z",
            "M14 14h7v7h-7z",
            "M3 14h7v7H3z"
        ])
    }

    public static func list(size: Int = 16) -> Element<AnyHTMLContext> {
        svg(size: size, paths: [
            "M8 6h13",
            "M8 12h13",
            "M8 18h13",
            "M3 6h.01",
            "M3 12h.01",
            "M3 18h.01"
        ])
    }

    public static func favorites(size: Int = 16) -> Element<AnyHTMLContext> {
        star(filled: false, size: size)
    }

    public static func search(size: Int = 16) -> Element<AnyHTMLContext> {
        svg(size: size, paths: [
            "M11 17a6 6 0 1 0 0-12 6 6 0 0 0 0 12z",
            "M21 21l-4.35-4.35"
        ])
    }

    public static func wrap(_ icon: Element<AnyHTMLContext>) -> Element<AnyHTMLContext> {
        Element<AnyHTMLContext>(
            tag: "span",
            attributes: [Attribute(name: "class", value: "toolbar-icon")],
            children: [AnyNode(icon)]
        )
    }

    public static func trash(size: Int = 16) -> Element<AnyHTMLContext> {
        svg(size: size, paths: [
            "M3 6h18",
            "M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"
        ])
    }

    public static func download(size: Int = 16) -> Element<AnyHTMLContext> {
        svg(size: size, paths: [
            "M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4",
            "M7 10l5 5 5-5",
            "M12 15V3"
        ])
    }

    public static func upload(size: Int = 16) -> Element<AnyHTMLContext> {
        svg(size: size, paths: [
            "M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4",
            "M17 8l-5-5-5 5",
            "M12 3v12"
        ])
    }

    public static func warning(size: Int = 16) -> Element<AnyHTMLContext> {
        svg(size: size, paths: [
            "M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z",
            "M12 9v4",
            "M12 17h.01"
        ])
    }

    public static func wifiOff(size: Int = 16) -> Element<AnyHTMLContext> {
        svg(size: size, paths: [
            "M1 1l22 22",
            "M16.72 11.06A10.94 10.94 0 0 1 19 12.55",
            "M5 12.55a10.94 10.94 0 0 1 5.17-2.39",
            "M10.71 5.05A16 16 0 0 1 22.56 9",
            "M1.42 9a15.91 15.91 0 0 1 4.7-2.88",
            "M8.53 16.11a6 6 0 0 1 6.95 0",
            "M12 20h.01"
        ])
    }

    public static func folder(size: Int = 16) -> Element<AnyHTMLContext> {
        svg(size: size, paths: [
            "M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"
        ])
    }

    public static func clock(size: Int = 16) -> Element<AnyHTMLContext> {
        svg(size: size, paths: [
            "M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20z",
            "M12 6v6l4 2"
        ])
    }

    public static func zap(size: Int = 16) -> Element<AnyHTMLContext> {
        svg(size: size, paths: [
            "M13 2L3 14h9l-1 10 10-12h-9l1-10z"
        ])
    }

    public static func info(size: Int = 16) -> Element<AnyHTMLContext> {
        svg(size: size, paths: [
            "M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20z",
            "M12 16v-4",
            "M12 8h.01"
        ])
    }

    public static func share(size: Int = 16) -> Element<AnyHTMLContext> {
        svg(size: size, paths: [
            "M4 12v8a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-8",
            "M16 6l-4-4-4 4",
            "M12 2v13"
        ])
    }

    public static func close(size: Int = 16) -> Element<AnyHTMLContext> {
        svg(size: size, paths: [
            "M18 6L6 18",
            "M6 6l12 12"
        ])
    }

    public static func check(size: Int = 16) -> Element<AnyHTMLContext> {
        svg(size: size, paths: [
            "M20 6L9 17l-5-5"
        ])
    }

    public static func circle(size: Int = 16) -> Element<AnyHTMLContext> {
        svg(size: size, paths: [
            "M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20z"
        ])
    }

    public static func arrowRight(size: Int = 16) -> Element<AnyHTMLContext> {
        svg(size: size, paths: [
            "M5 12h14",
            "M12 5l7 7-7 7"
        ])
    }

    public static func externalLink(size: Int = 16) -> Element<AnyHTMLContext> {
        svg(size: size, paths: [
            "M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6",
            "M15 3h6v6",
            "M10 14L21 3"
        ])
    }
}
