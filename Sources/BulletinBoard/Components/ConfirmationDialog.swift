import LINKER

public struct ConfirmationDialog {

    public struct Props {
        public let message: String
        public let pendingAction: String

        public init(message: String, pendingAction: String) {
            self.message = message
            self.pendingAction = pendingAction
        }
    }

    public static func render(props: Props) -> [AnyNode] {
        let overlay = Element<AnyHTMLContext>(
            tag: "div",
            attributes: [
                Attribute(name: "class", value: "confirmation-overlay"),
                Attribute(name: "role", value: "dialog"),
                Attribute(name: "aria-modal", value: "true"),
                Attribute(name: "aria-label", value: "Confirmation")
            ],
            children: [
                AnyNode(Element<AnyHTMLContext>(
                    tag: "div",
                    attributes: [Attribute(name: "class", value: "confirmation-dialog")],
                    children: [
                        AnyNode(Element<AnyHTMLContext>(
                            tag: "p",
                            attributes: [Attribute(name: "class", value: "confirmation-dialog__message")],
                            children: [AnyNode(Text(props.message))]
                        )),
                        AnyNode(Element<AnyHTMLContext>(
                            tag: "div",
                            attributes: [Attribute(name: "class", value: "confirmation-dialog__actions")],
                            children: [
                                AnyNode(Element<AnyHTMLContext>(
                                    tag: "button",
                                    attributes: [
                                        Attribute(name: "type", value: "button"),
                                        Attribute(name: "class", value: "confirmation-dialog__cancel"),
                                        Attribute(name: "data-action", value: "cancel-confirmation")
                                    ],
                                    children: [AnyNode(Text("Cancel"))]
                                )),
                                AnyNode(Element<AnyHTMLContext>(
                                    tag: "button",
                                    attributes: [
                                        Attribute(name: "type", value: "button"),
                                        Attribute(name: "class", value: "confirmation-dialog__confirm"),
                                        Attribute(name: "data-action", value: "confirm-action"),
                                        Attribute(name: "data-pending-action", value: props.pendingAction)
                                    ],
                                    children: [AnyNode(Text("Confirm"))]
                                ))
                            ]
                        ))
                    ]
                ))
            ]
        )

        return [AnyNode(overlay)]
    }
}
