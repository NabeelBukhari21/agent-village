import Foundation
import simd

/// Where in the village an agent goes to do a kind of work.
enum StationKind: String, CaseIterable {
    case postOffice, forge, library, observatory, questBoard

    var title: String {
        switch self {
        case .postOffice: "Post Office"
        case .forge: "Code Forge"
        case .library: "Grand Library"
        case .observatory: "Star Observatory"
        case .questBoard: "Quest Board"
        }
    }

    /// Center of the building's footprint (tile units; x right, z down).
    var buildingPosition: SIMD3<Float> {
        switch self {
        case .library: [-12.5, 0, -6.5]
        case .forge: [-5, 0, -10]
        case .postOffice: [5, 0, -10]
        case .observatory: [12.5, 0, -6.5]
        case .questBoard: [2.6, 0, 6.4]
        }
    }

    /// Where the agent stands while working here.
    var workSpot: SIMD3<Float> {
        switch self {
        case .library: [-12.5, 0, -2.6]
        case .forge: [-4.2, 0, -6.1]
        case .postOffice: [5.6, 0, -6.1]
        case .observatory: [12.5, 0, -2.6]
        case .questBoard: [0, 0, 7.6]
        }
    }

    /// Angle (degrees) of the work spot as seen from the plaza center.
    var angle: Float {
        let w = workSpot
        return atan2(w.x, w.z) * 180 / .pi
    }

    /// Direction the agent faces while working (yaw; 0 = down/south, pi = up/north).
    var workYaw: Float {
        switch self {
        case .forge, .postOffice: .pi / 2      // face right, toward the anvil / sorting table
        case .library, .observatory: -.pi / 2  // face left, toward the lectern / hologram
        case .questBoard: 0                    // face the player
        }
    }
}

enum HairStyle { case twinTails, spiky, longStraight, messy }
enum Accessory { case ribbon, headband, glasses, goggles }
enum HeldProp { case letter, hammer, book, tablet }
enum WorkMotion { case sort, hammer, read, observe }

struct AgentTask: Identifiable {
    var id = UUID()
    var isCustom = false
    let title: String
    let lines: [String]
    let doneLine: String
    let duration: Double
    let tokens: Int
    /// When set, the agent stops partway and asks the player for approval.
    let approvalPrompt: String?
}

struct Persona: Identifiable {
    let id: String
    let name: String
    let title: String
    let role: String
    let station: StationKind
    let hairStyle: HairStyle
    let accessory: Accessory
    let prop: HeldProp
    let motion: WorkMotion

    let hair: UInt32
    let hairShade: UInt32
    let eye: UInt32
    let outfit: UInt32
    let outfitAccent: UInt32
    let skin: UInt32
    let aura: UInt32

    let greeting: String
    let idleLines: [String]
    let tasks: [AgentTask]
}

extension Persona {
    static let roster: [Persona] = [hana, ren, yuki, kaito]

    static let hana = Persona(
        id: "hana", name: "Hana", title: "Mail Mage", role: "Inbox & email agent",
        station: .postOffice, hairStyle: .twinTails, accessory: .ribbon, prop: .letter, motion: .sort,
        hair: 0xFF8FB8, hairShade: 0xE0558F, eye: 0xE8366E, outfit: 0xFFFFFF, outfitAccent: 0xE8366E,
        skin: 0xFFE3D3, aura: 0xFF6FA5,
        greeting: "Hiii! Your inbox is my battlefield. Nothing gets past me~!",
        idleLines: ["Inbox zero is a lifestyle","Hmm hmm~ ♪","So many newsletters…","I smell spam."],
        tasks: [
            AgentTask(title: "Triage 37 unread emails",
                      lines: ["37 unread… let's sort these!","Newsletter, newsletter… archive!","Ooh, this one looks important.","Labeling receipts *"],
                      doneLine: "Inbox zero achieved!", duration: 16, tokens: 4200, approvalPrompt: nil),
            AgentTask(title: "Draft reply to landlord",
                      lines: ["Reading the lease email…","Polite but firm. Got it.","Drafting a reply~"],
                      doneLine: "Reply sent!", duration: 14, tokens: 2600,
                      approvalPrompt: "I drafted a reply to your landlord about the lease renewal. Can I send it?"),
            AgentTask(title: "Unsubscribe from 6 promo lists",
                      lines: ["Bye-bye, flash sales!","Unsubscribe… unsubscribe…","You will not be missed!"],
                      doneLine: "6 lists gone, poof!", duration: 11, tokens: 1500, approvalPrompt: nil),
            AgentTask(title: "Flag overdue invoices",
                      lines: ["Scanning for invoices…","Found one from last month!","Adding a red flag !"],
                      doneLine: "2 invoices flagged!", duration: 12, tokens: 1900, approvalPrompt: nil),
        ]
    )

    static let ren = Persona(
        id: "ren", name: "Ren", title: "Code Smith", role: "Coding agent",
        station: .forge, hairStyle: .spiky, accessory: .headband, prop: .hammer, motion: .hammer,
        hair: 0xE8EEF7, hairShade: 0x9FB2CC, eye: 0x27C2E8, outfit: 0x232A3D, outfitAccent: 0x27C2E8,
        skin: 0xFFDCC6, aura: 0x3BD4FF,
        greeting: "Yo. Bring me a bug and I'll forge you a fix.",
        idleLines: ["Ship it.","Who wrote this regex…","Tests are love.","One more commit."],
        tasks: [
            AgentTask(title: "Fix login session bug",
                      lines: ["Reproducing the bug…","Found it — off-by-one in the session check!","Hammering out a patch"],
                      doneLine: "Bug slain.", duration: 17, tokens: 8800, approvalPrompt: nil),
            AgentTask(title: "Write unit tests for API",
                      lines: ["12 tests… 13… 14…","Mocking the network layer.","All green!"],
                      doneLine: "Coverage +18%!", duration: 15, tokens: 6100, approvalPrompt: nil),
            AgentTask(title: "Refactor payments module",
                      lines: ["This file is 900 lines. Ugh.","Splitting it up…","Much cleaner."],
                      doneLine: "Refactor forged!", duration: 18, tokens: 9400,
                      approvalPrompt: "The refactor is ready and tests pass. Can I open a pull request?"),
        ]
    )

    static let yuki = Persona(
        id: "yuki", name: "Yuki", title: "Lore Seeker", role: "Research agent",
        station: .library, hairStyle: .longStraight, accessory: .glasses, prop: .book, motion: .read,
        hair: 0xB7A6F2, hairShade: 0x7E68D8, eye: 0x6C5CE7, outfit: 0x3A4C9A, outfitAccent: 0xF5D76E,
        skin: 0xFFE8DA, aura: 0xA78BFA,
        greeting: "Ah, a visitor. Shall I tell you what the scrolls say?",
        idleLines: ["Knowledge is power… and tokens.","Citation needed.","Fascinating…","Page 412…"],
        tasks: [
            AgentTask(title: "Research AI agent startups",
                      lines: ["Searching 40 sources…","Three new raises this week!","Cross-checking the numbers…"],
                      doneLine: "Report compiled!", duration: 18, tokens: 12000, approvalPrompt: nil),
            AgentTask(title: "Summarize 12 papers",
                      lines: ["Paper 1 of 12…","Oh, this one is clever.","Distilling the key ideas…"],
                      doneLine: "12 papers, 1 page.", duration: 16, tokens: 15400, approvalPrompt: nil),
            AgentTask(title: "Compare vector databases",
                      lines: ["Benchmarks, benchmarks…","Pricing tables are a maze.","Drawing a comparison chart."],
                      doneLine: "Comparison done!", duration: 15, tokens: 9800,
                      approvalPrompt: "My comparison is finished. Shall I share it with your team?"),
        ]
    )

    static let kaito = Persona(
        id: "kaito", name: "Kaito", title: "Star Analyst", role: "Data agent",
        station: .observatory, hairStyle: .messy, accessory: .goggles, prop: .tablet, motion: .observe,
        hair: 0x5FD39A, hairShade: 0x2E9E6B, eye: 0xF2A93B, outfit: 0xF4F6FA, outfitAccent: 0x2E9E6B,
        skin: 0xF7D2B8, aura: 0x4ADE80,
        greeting: "The numbers whisper to me. Want to hear them?",
        idleLines: ["Correlation isn't causation!","p < 0.05 *","So many charts…","The stars align."],
        tasks: [
            AgentTask(title: "Analyze weekly metrics",
                      lines: ["Pulling 7 days of data…","Revenue up 9%!","Plotting the trend lines…"],
                      doneLine: "Weekly report ready!", duration: 15, tokens: 7200, approvalPrompt: nil),
            AgentTask(title: "Detect signup anomalies",
                      lines: ["Scanning signups…","Wait… Tuesday looks weird.","Signups dropped 12%!"],
                      doneLine: "Anomaly logged.", duration: 14, tokens: 6400,
                      approvalPrompt: "Signups dropped 12% on Tuesday. Should I alert the team channel?"),
            AgentTask(title: "Forecast next month",
                      lines: ["Fitting the model…","Seasonality detected!","The stars say: growth."],
                      doneLine: "Forecast: +14%", duration: 17, tokens: 8100, approvalPrompt: nil),
        ]
    )
}

/// Little conversations agents have when they bump into each other.
enum Banter {
    static let pairs: [(String, String)] = [
        ("Yo! Busy day?","Always~ You?"),
        ("Did you eat yet?","Tokens count as food, right?"),
        ("Nice work earlier!","Ehehe, thanks!"),
        ("The boss is watching…","Look busy!"),
        ("Race you to the plaza!","You're on!"),
        ("Found any bugs?","Only the ones I wrote."),
        ("Ganbatte!","You too! !"),
        ("The sakura are blooming~","So pretty…"),
    ]
}
