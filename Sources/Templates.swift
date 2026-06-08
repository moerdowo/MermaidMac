import Foundation

struct DiagramTemplate: Identifiable {
    let id = UUID()
    let name: String
    let symbol: String
    let code: String
}

enum MermaidTemplate {
    static let welcome = """
    %% Welcome to MermaidMac — edit on the left, preview on the right.
    flowchart TD
        A[Start] --> B{Is it working?}
        B -->|Yes| C[Great!]
        B -->|No| D[Check the syntax]
        D --> B
        C --> E[Ship it 🚀]
    """

    static let all: [DiagramTemplate] = [
        DiagramTemplate(name: "Flowchart", symbol: "arrow.triangle.branch", code: """
        flowchart LR
            A[Start] --> B{Decision}
            B -->|Yes| C[Do this]
            B -->|No| D[Do that]
            C --> E[End]
            D --> E
        """),
        DiagramTemplate(name: "Sequence", symbol: "arrow.left.arrow.right", code: """
        sequenceDiagram
            autonumber
            participant U as User
            participant A as App
            participant S as Server
            U->>A: Click button
            A->>S: API request
            S-->>A: 200 OK
            A-->>U: Show result
        """),
        DiagramTemplate(name: "Class", symbol: "square.stack.3d.up", code: """
        classDiagram
            class Animal {
                +String name
                +int age
                +makeSound() void
            }
            class Dog {
                +fetch() void
            }
            class Cat {
                +scratch() void
            }
            Animal <|-- Dog
            Animal <|-- Cat
        """),
        DiagramTemplate(name: "State", symbol: "circle.grid.cross", code: """
        stateDiagram-v2
            [*] --> Idle
            Idle --> Running : start
            Running --> Paused : pause
            Paused --> Running : resume
            Running --> [*] : stop
        """),
        DiagramTemplate(name: "ER", symbol: "tablecells", code: """
        erDiagram
            CUSTOMER ||--o{ ORDER : places
            ORDER ||--|{ LINE_ITEM : contains
            CUSTOMER {
                string name
                string email
            }
            ORDER {
                int id
                date created
            }
        """),
        DiagramTemplate(name: "Gantt", symbol: "chart.bar", code: """
        gantt
            title Project Plan
            dateFormat YYYY-MM-DD
            section Design
            Research      :a1, 2026-01-01, 7d
            Wireframes    :a2, after a1, 5d
            section Build
            Implementation:b1, after a2, 14d
            Testing       :b2, after b1, 7d
        """),
        DiagramTemplate(name: "Pie", symbol: "chart.pie", code: """
        pie showData
            title Favorite Languages
            "Swift" : 45
            "Rust" : 30
            "TypeScript" : 25
        """),
        DiagramTemplate(name: "Git", symbol: "arrow.triangle.pull", code: """
        gitGraph
            commit
            branch develop
            checkout develop
            commit
            commit
            checkout main
            merge develop
            commit
        """),
        DiagramTemplate(name: "Mindmap", symbol: "brain", code: """
        mindmap
            root((MermaidMac))
                Editor
                    Syntax highlight
                    Line numbers
                Preview
                    Live render
                    Zoom & pan
                Export
                    SVG
                    PNG
        """),
        DiagramTemplate(name: "Journey", symbol: "figure.walk", code: """
        journey
            title My Working Day
            section Morning
                Make tea: 5: Me
                Check email: 3: Me
            section Work
                Write code: 5: Me
                Code review: 2: Me, Team
        """),
        DiagramTemplate(name: "Timeline", symbol: "timeline.selection", code: """
        timeline
            title History of the Web
            1991 : First website
            2004 : Web 2.0
            2008 : Mobile web
            2026 : AI everywhere
        """),
        DiagramTemplate(name: "Quadrant", symbol: "squareshape.split.2x2", code: """
        quadrantChart
            title Effort vs Impact
            x-axis Low Effort --> High Effort
            y-axis Low Impact --> High Impact
            quadrant-1 Do now
            quadrant-2 Plan
            quadrant-3 Skip
            quadrant-4 Quick wins
            Feature A: [0.3, 0.8]
            Feature B: [0.7, 0.7]
            Feature C: [0.2, 0.3]
        """)
    ]
}
