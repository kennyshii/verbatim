import Foundation

struct User: Identifiable, Equatable {
    let id: Int64
    let username: String
    let createdAt: String
}

enum PracticeKind: String, Codable, CaseIterable {
    case debate
    case congress

    var title: String { self == .debate ? "Debate" : "Model Congress" }
    var icon: String { self == .debate ? "bubble.left.and.bubble.right.fill" : "building.columns.fill" }
    var subjectLabel: String { self == .debate ? "Resolution" : "Legislation" }
}

enum SessionMode: String, CaseIterable, Identifiable, Codable {
    case debate = "Debate"
    case coach = "Coach"
    case versus = "1v1"
    case twoVtwo = "2v2"
    case team = "Team vs AI"
    case congress = "Congress"

    var id: String { rawValue }

    static func options(for kind: PracticeKind) -> [SessionMode] {
        kind == .debate ? [.debate, .coach, .versus, .twoVtwo, .team] : [.congress]
    }

    var isMultiplayer: Bool { self == .versus || self == .twoVtwo || self == .team }
    var isJudged: Bool { self == .versus || self == .twoVtwo }
    var humanCount: Int { self == .twoVtwo ? 4 : isMultiplayer ? 2 : 1 }

    var icon: String {
        switch self {
        case .debate: return "bubble.left.and.bubble.right"
        case .coach: return "graduationcap"
        case .versus: return "person.2"
        case .twoVtwo: return "person.3"
        case .team: return "person.2.badge.gearshape"
        case .congress: return "building.columns"
        }
    }

    var explanation: String {
        switch self {
        case .debate:
            return "Live back-and-forth. The AI argues the opposing side in real time; structured feedback comes after you end."
        case .coach:
            return "No opponent. The AI gives structured, critical feedback after each of your turns."
        case .versus:
            return "Debate another person — on this phone or online with a room code. An AI judge decides the round using the paradigm you pick."
        case .twoVtwo:
            return "Public Forum style, two on two. First speakers build the case, second speakers rebut. Same phone or online with a code; an AI judge decides."
        case .team:
            return "You and a partner on the same side: one presents the case, the other rebuts. The AI plays both opposing speakers and ends every speech with crossfire questions."
        case .congress:
            return "Give speeches on a bill. An opposing member refutes you and asks a question; a parliamentarian scores you at the end."
        }
    }

    var assistantLabel: String {
        switch self {
        case .debate: return "Opponent"
        case .coach: return "Coach"
        case .versus: return "Judge"
        case .twoVtwo: return "Judge"
        case .team: return "Opposing team"
        case .congress: return "Opposing member"
        }
    }
}

enum Difficulty: String, CaseIterable, Identifiable, Codable {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .easy: return "leaf"
        case .medium: return "flame"
        case .hard: return "bolt"
        }
    }

    var explanation: String {
        switch self {
        case .easy: return "Straightforward arguments, one point at a time."
        case .medium: return "Solid rebuttals that push back on your reasoning."
        case .hard: return "Tournament-level pressure. Every weak point gets attacked."
        }
    }
}

enum Language: String, CaseIterable, Identifiable, Codable {
    case english = "English"
    case spanish = "Spanish"
    case french = "French"

    var id: String { rawValue }

    var speechCode: String {
        switch self {
        case .english: return "en-US"
        case .spanish: return "es-ES"
        case .french: return "fr-FR"
        }
    }
}

enum Side: String, CaseIterable, Identifiable, Codable {
    case affirmative = "Affirmative"
    case negative = "Negative"

    var id: String { rawValue }
    var opposite: Side { self == .affirmative ? .negative : .affirmative }
}

enum JudgePreset: String, CaseIterable, Identifiable, Codable {
    case novice = "Novice"
    case varsity = "Varsity"
    case custom = "Custom"

    var id: String { rawValue }

    var sampleRFD: String? {
        switch self {
        case .novice:
            return """
            I vote negative (Syosset AH). On case, I'm not sure I give the affirmative access to their extinction impact. They extend populism and mathematical certainty in the 2AR. However, I don't find the populism responses persuasive. The point about psychology seems new and under warranted, and I'm overall not persuaded by the idea that one leader is enough to trigger the impact. I don't see how this responds to the idea that nukes would still cap an irrational leader. On mathematical certainty, the 2AR concedes the point that if this is true, I prioritize the neg because their extinction impact happens sooner. That's especially true when I don't know the timeline for when nuclear war happens in the aff world (and deterrence provides enough defense to doubt), but I know it's imminent under bioweapons. On bioweapons, I don't get a warrant for tech checking back against this in the 2AR. This seems too new because it was blippy in the 1AR. I don't get a sufficient extension of the deterrence double bind, which means the argument stands. There is an extinction impact, which means it does get weighed, and I think it's more probable than nuclear war given the state of the flow in this debate (under warranted responses = higher likelihood of impact on bioweapons, decent defense on deterrence = lower likelihood of impact on nuclear weapons.). Thus, I vote neg.
            """
        case .varsity:
            return """
            Both AFF and NEG had exceptionally strong Constructives. NEG made the argument that they only had the burden of proving that plea bargains are unjust, they did not have to provide an alternative, and I agreed with this. This shifted the burden to AFF to argue against the NEG contentions of Environmental Crimes and Racial Inequalities, both under the value criterion of Mitigating Structural Violence. AFF erred in my opinion by not recognizing that NEG wasn't arguing against plea bargaining. AFF spent a lot of time during 1AR repeating the AFF contentions (e.g., arguing that plea bargaining is better than getting rid of plea bargaining), but NEG had already stated that he wasn't advocating to get rid of plea bargaining so this was ultimately time wasted. AFF spent so much time on this during 1AR that she ran out of time to counter the second NEG contention of Racial Inequalities, which was in my opinion the stronger of the two NEG contentions. In the end, the NEG contention that plea bargains are unjust because they unfairly target minorities carried my vote. This included the arguments that the poor are more affected because they can't afford to sit in jail awaiting trial and be without a job; the police know that targeting minorities is more likely to result in conviction by plea bargain and help their numbers; etc. NEG also provided very strong statistics about the economic impact from any plea bargains and the impact on minorities.
            One piece of feedback for NEG is that the Environmental Crimes contention seemed a bit weak to me. I think NEG overshot the impact of companies polluting BECAUSE of plea bargaining, or that somehow plea bargaining in and of itself was making pollution worse. I understood the intention that there was precedent set and that companies always want to plea bargain out these cases so that they can pay a fine instead of being forced to change or go bankrupt. However, I didn't buy that the precedent prevents the government from deciding to take the next case (or the one after that) to trial to effectively reset the precedent if they wanted to. Basically, I thought that even though it may be physically harmful to our citizens for these environmental crime cases to get settled rather than shutting down the companies or forcing a change in their practices, I thought that this was due to a poor decision by the government to prosecute in this manner, rather than the plea bargaining practice itself being unjust.
            """
        case .custom:
            return nil
        }
    }

    var instructions: String {
        switch self {
        case .novice:
            return "You are judging a novice round. Decide the round on the arguments as they were actually presented; do not intervene with your own knowledge or opinions. Reward clear claims, warrants, and direct clash. Give weight to arguments that were extended and answered over arguments that were dropped, but do not punish a novice harshly for minor drops or technical mistakes. Prioritize clarity, organization, and whether each side explained why their arguments matter. Do not reward speed, jargon, or theory arguments. Decide which side better upheld or negated the resolution overall, and explain the decision in plain language a first-year debater can learn from."
        case .varsity:
            return "You are judging a varsity round with a flow-based, tabula rasa paradigm. Vote on the flow: dropped arguments are conceded, extensions must include warrants, and impacts must be weighed explicitly by the debaters themselves. Reward impact calculus, framework debate, and direct comparison of evidence and warrants. Do not intervene with your own opinions or fill in arguments a debater did not make. Penalize new arguments in final speeches and extensions without warrants. Decide the round on the clearest path to the ballot each side offered, and write a rigorous reason for decision that names the specific arguments that decided the round."
        case .custom:
            return ""
        }
    }
}

struct DebateTopic: Identifiable, Hashable {
    let text: String
    var period: String? = nil
    var id: String { text }
}

struct TopicCategory: Identifiable {
    let name: String
    let icon: String
    var source: String? = nil
    let topics: [DebateTopic]
    var id: String { name }
}

let nsdaTopicsURL = "https://www.speechanddebate.org/topics/"

let topicCategories: [TopicCategory] = [
    TopicCategory(name: "Lincoln-Douglas", icon: "person.2.wave.2", source: nsdaTopicsURL, topics: [
        DebateTopic(text: "Resolved: Outer space colonization is a moral imperative.", period: "2026 September/October"),
        DebateTopic(text: "Resolved: De-extinction is unethical.", period: "2026 November/December"),
        DebateTopic(text: "Resolved: The United States ought to vest ecosystems with legal rights.", period: "2026 November/December"),
        DebateTopic(text: "Resolved: The use of artificial intelligence for offensive military operations is immoral.", period: "2027 January/February"),
        DebateTopic(text: "Resolved: The United States ought to substantially increase subsidies for renewable energy.", period: "2027 January/February"),
        DebateTopic(text: "Resolved: The United States ought to provide a universal basic income.", period: "2027 March/April"),
        DebateTopic(text: "Resolved: In a democracy, a candidate for public office’s right to privacy ought to be valued above the public’s right to know.", period: "2027 March/April"),
        DebateTopic(text: "Resolved: The intergenerational accumulation of wealth is unjust.", period: "2027 National Tournament"),
        DebateTopic(text: "Resolved: Justice requires the repatriation of cultural artifacts to their countries of origin.", period: "2027 National Tournament"),
        DebateTopic(text: "Resolved: In the United States, national service ought to be mandatory.", period: "Novice Topic (Ongoing)"),
    ]),
    TopicCategory(name: "Public Forum", icon: "person.3", source: nsdaTopicsURL, topics: [
        DebateTopic(text: "Resolved: The United States federal government should enact a moratorium on hyperscale data center construction.", period: "2026 September/October"),
        DebateTopic(text: "Resolved: European members of the North Atlantic Treaty Organization should ratify the Treaty on the Prohibition of Nuclear Weapons.", period: "2026 November/December"),
        DebateTopic(text: "Resolved: The Republic of Korea should pursue an independent nuclear deterrent.", period: "2026 November/December"),
        DebateTopic(text: "Resolved: The United States federal government should classify gig workers as employees.", period: "2027 January"),
        DebateTopic(text: "Resolved: In the United States, the benefits of big box retailers outweigh the harms.", period: "2027 January"),
        DebateTopic(text: "Resolved: The benefits of the African Continental Free Trade Area outweigh the harms.", period: "2027 February"),
        DebateTopic(text: "Resolved: In Africa, peacekeeping missions led by the United Nations are preferable to those led by regional organizations.", period: "2027 February"),
        DebateTopic(text: "Resolved: In the United States, Congressional district boundaries should be drawn by independent redistricting commissions.", period: "2027 March"),
        DebateTopic(text: "Resolved: In the United States, voting should be compulsory in federal elections.", period: "2027 March"),
        DebateTopic(text: "Resolved: The Federative Republic of Brazil should prioritize its environmental protection over its economic development.", period: "2027 April"),
        DebateTopic(text: "Resolved: Latin American countries should prioritize Chinese investment over American investment.", period: "2027 April"),
    ]),
]

let suggestedResolutions: [String] = [
    "Resolved: Outer space colonization is a moral imperative.",
    "Resolved: The United States federal government should enact a moratorium on hyperscale data center construction.",
    "Resolved: The United States federal government should establish national health insurance in the United States.",
    "Resolved: The United States ought to vest ecosystems with legal rights.",
    "Resolved: In a democracy, a candidate for public office’s right to privacy ought to be valued above the public’s right to know.",
]

struct SourceLink: Identifiable, Hashable {
    let title: String
    let url: String
    var id: String { url }
}

struct Committee: Identifiable, Hashable {
    let name: String
    let chamber: String
    let jurisdiction: String
    let agencies: [String]
    let sources: [SourceLink]
    let statSuggestions: [String]
    let bills: [String]

    var id: String { name }
    var fullName: String { "Committee on \(name)" }
}

let committees: [Committee] = [
    Committee(name: "Foreign Relations", chamber: "Senate",
        jurisdiction: "Treaties, foreign aid, arms sales, ambassadors, international organizations, and overall foreign policy.",
        agencies: ["Department of State", "USAID"],
        sources: [
            SourceLink(title: "U.S. Department of State", url: "https://www.state.gov"),
            SourceLink(title: "Congressional Research Service", url: "https://crsreports.congress.gov"),
            SourceLink(title: "USAspending.gov — foreign aid", url: "https://www.usaspending.gov"),
            SourceLink(title: "World Bank Open Data", url: "https://data.worldbank.org"),
        ],
        statSuggestions: ["How much U.S. foreign aid goes to the top five recipient countries?", "How many treaties has the Senate ratified in the last decade?", "What share of the federal budget is foreign assistance?", "How many UN peacekeeping missions are active right now?"],
        bills: ["A Bill to Condition Military Aid on Human Rights Benchmarks", "A Bill to Repeal Outdated Authorizations for the Use of Military Force"]),

    Committee(name: "Environment and Public Works", chamber: "Senate",
        jurisdiction: "Environmental protection, air and water quality, highways and bridges, water infrastructure, and nuclear safety.",
        agencies: ["EPA", "Army Corps of Engineers", "Nuclear Regulatory Commission"],
        sources: [
            SourceLink(title: "EPA — reports and data", url: "https://www.epa.gov"),
            SourceLink(title: "EPA Greenhouse Gas Inventory", url: "https://www.epa.gov/ghgemissions"),
            SourceLink(title: "USGS Water Data", url: "https://www.usgs.gov"),
            SourceLink(title: "Congressional Budget Office", url: "https://www.cbo.gov"),
        ],
        statSuggestions: ["What are current U.S. greenhouse gas emissions by sector?", "How many U.S. bridges are rated in poor condition?", "How many communities still have lead service lines?", "What share of Americans breathe air that fails EPA standards?"],
        bills: ["A Bill to Set a National Standard for PFAS in Drinking Water", "A Bill to Fund Replacement of All Lead Service Lines"]),

    Committee(name: "Judiciary", chamber: "House and Senate",
        jurisdiction: "Federal courts and judicial nominations, criminal law, immigration, civil rights and liberties, antitrust, and intellectual property.",
        agencies: ["Department of Justice", "FBI", "Federal judiciary", "USCIS"],
        sources: [
            SourceLink(title: "Bureau of Justice Statistics", url: "https://bjs.ojp.gov"),
            SourceLink(title: "FBI Crime Data Explorer", url: "https://cde.ucr.cjis.gov"),
            SourceLink(title: "U.S. Sentencing Commission", url: "https://www.ussc.gov"),
            SourceLink(title: "DHS Immigration Statistics", url: "https://www.dhs.gov/ohss"),
        ],
        statSuggestions: ["What share of federal criminal cases end in a plea bargain?", "How many people are held in federal prison right now?", "How large is the immigration court backlog?", "What is the federal incarceration rate by race?"],
        bills: ["A Bill to Eliminate Mandatory Minimum Sentences for Nonviolent Drug Offenses", "A Bill to Create a Pathway to Citizenship for Dreamers"]),

    Committee(name: "Small Business and Entrepreneurship", chamber: "Senate",
        jurisdiction: "The Small Business Administration, small business lending and contracting, and regulatory burden on small firms.",
        agencies: ["Small Business Administration"],
        sources: [
            SourceLink(title: "SBA Office of Advocacy", url: "https://advocacy.sba.gov"),
            SourceLink(title: "Census Business Dynamics Statistics", url: "https://www.census.gov/programs-surveys/bds.html"),
            SourceLink(title: "Federal Reserve Small Business Credit Survey", url: "https://www.fedsmallbusiness.org"),
            SourceLink(title: "Bureau of Labor Statistics", url: "https://www.bls.gov"),
        ],
        statSuggestions: ["How many small businesses are there in the United States?", "What share of new small businesses survive five years?", "How much did SBA lend in its latest fiscal year?", "What share of private sector jobs are at small businesses?"],
        bills: ["A Bill to Expand SBA Microloans for First-Time Entrepreneurs", "A Bill to Simplify Federal Contracting for Small Businesses"]),

    Committee(name: "Health, Education, Labor, and Pensions", chamber: "Senate",
        jurisdiction: "Public health, education, labor standards, workplace safety, and retirement plans.",
        agencies: ["HHS", "Department of Education", "Department of Labor", "FDA", "NIH", "CDC"],
        sources: [
            SourceLink(title: "CDC National Center for Health Statistics", url: "https://www.cdc.gov/nchs"),
            SourceLink(title: "National Center for Education Statistics", url: "https://nces.ed.gov"),
            SourceLink(title: "Bureau of Labor Statistics", url: "https://www.bls.gov"),
            SourceLink(title: "OSHA Data and Statistics", url: "https://www.osha.gov/data"),
        ],
        statSuggestions: ["What is U.S. life expectancy compared with peer countries?", "How much has college tuition risen in twenty years?", "How many workers lack paid sick leave?", "What is the current average price of insulin?"],
        bills: ["A Bill to Guarantee Paid Family and Medical Leave", "A Bill to Cap Insulin Prices Nationwide"]),

    Committee(name: "Commerce, Science, and Transportation", chamber: "Senate",
        jurisdiction: "Interstate commerce, transportation, telecommunications, consumer protection, science, oceans, and aviation.",
        agencies: ["Department of Commerce", "Department of Transportation", "FCC", "FTC", "NASA", "NOAA"],
        sources: [
            SourceLink(title: "Bureau of Transportation Statistics", url: "https://www.bts.gov"),
            SourceLink(title: "FCC Reports and Research", url: "https://www.fcc.gov/reports-research"),
            SourceLink(title: "NOAA Data", url: "https://www.noaa.gov"),
            SourceLink(title: "FTC Reports", url: "https://www.ftc.gov/reports"),
        ],
        statSuggestions: ["How many satellites are currently in orbit?", "How many Americans still lack broadband access?", "How many traffic deaths were there last year?", "How many commercial space launches happened last year?"],
        bills: ["A Bill to Require Age Verification for Social Media Platforms", "A Bill to Set Federal Standards for Autonomous Vehicles"]),

    Committee(name: "Homeland Security and Governmental Affairs", chamber: "Senate",
        jurisdiction: "The Department of Homeland Security, border security, cybersecurity, emergency management, government operations, and the federal workforce.",
        agencies: ["DHS", "CBP", "TSA", "FEMA", "CISA", "OPM"],
        sources: [
            SourceLink(title: "DHS Office of Homeland Security Statistics", url: "https://www.dhs.gov/ohss"),
            SourceLink(title: "CBP Newsroom Stats", url: "https://www.cbp.gov/newsroom/stats"),
            SourceLink(title: "GAO High-Risk List", url: "https://www.gao.gov/high-risk-list"),
            SourceLink(title: "OPM FedScope Workforce Data", url: "https://www.fedscope.opm.gov"),
        ],
        statSuggestions: ["How many border encounters were recorded last year?", "How many federal disaster declarations were issued last year?", "How many reported ransomware attacks hit U.S. infrastructure?", "How large is the federal civilian workforce?"],
        bills: ["A Bill to Reform Federal Disaster Aid Formulas", "A Bill to Require Cybersecurity Standards for Critical Infrastructure"]),

    Committee(name: "Banking, Housing, and Urban Affairs", chamber: "Senate",
        jurisdiction: "Banks, financial markets, insurance, housing, mass transit, and export controls.",
        agencies: ["Federal Reserve", "Treasury", "SEC", "FDIC", "HUD", "CFPB"],
        sources: [
            SourceLink(title: "Federal Reserve FRED", url: "https://fred.stlouisfed.org"),
            SourceLink(title: "HUD User — housing data", url: "https://www.huduser.gov"),
            SourceLink(title: "FDIC Data and Analysis", url: "https://www.fdic.gov/analysis"),
            SourceLink(title: "Census Housing Data", url: "https://www.census.gov/topics/housing.html"),
        ],
        statSuggestions: ["How many people experienced homelessness on a given night?", "What is the median U.S. home price right now?", "What share of renters are cost burdened?", "How many bank branches have closed in the last decade?"],
        bills: ["A Bill to Create a National Rental Assistance Guarantee", "A Bill to Expand the Low-Income Housing Tax Credit"]),

    Committee(name: "Armed Services", chamber: "House and Senate",
        jurisdiction: "The Department of Defense, military pay and readiness, weapons procurement, and the annual National Defense Authorization Act.",
        agencies: ["Department of Defense", "Army, Navy, Air Force, Marine Corps, Space Force"],
        sources: [
            SourceLink(title: "DoD Comptroller — budget materials", url: "https://comptroller.defense.gov"),
            SourceLink(title: "CBO — defense analyses", url: "https://www.cbo.gov/topics/defense-and-national-security"),
            SourceLink(title: "GAO Weapon Systems Assessments", url: "https://www.gao.gov"),
            SourceLink(title: "Congressional Research Service", url: "https://crsreports.congress.gov"),
        ],
        statSuggestions: ["How large is the current defense budget?", "How many U.S. troops are stationed overseas?", "What does the F-35 program cost per aircraft?", "How many service members are on food assistance?"],
        bills: ["A Bill to Raise Base Pay for Junior Enlisted Service Members", "A Bill to Require Congressional Approval for Overseas Troop Deployments Beyond 90 Days"]),

    Committee(name: "Education and the Workforce", chamber: "House",
        jurisdiction: "K-12 and higher education, student loans, job training, labor standards, wages, and pensions.",
        agencies: ["Department of Education", "Department of Labor", "National Labor Relations Board"],
        sources: [
            SourceLink(title: "National Center for Education Statistics", url: "https://nces.ed.gov"),
            SourceLink(title: "Federal Student Aid Data Center", url: "https://studentaid.gov/data-center"),
            SourceLink(title: "Bureau of Labor Statistics", url: "https://www.bls.gov"),
            SourceLink(title: "Department of Labor", url: "https://www.dol.gov"),
        ],
        statSuggestions: ["How much total student loan debt is outstanding?", "What is the current federal minimum wage in real terms?", "What are U.S. reading and math scores on the NAEP?", "How many teachers left the profession last year?"],
        bills: ["A Bill to Raise the Federal Minimum Wage", "A Bill to Make Community College Tuition-Free"]),

    Committee(name: "Energy and Commerce", chamber: "House",
        jurisdiction: "Health care, energy, environment, telecommunications, consumer protection, and interstate commerce.",
        agencies: ["HHS", "Department of Energy", "EPA", "FCC", "FTC", "FDA"],
        sources: [
            SourceLink(title: "Energy Information Administration", url: "https://www.eia.gov"),
            SourceLink(title: "CMS National Health Expenditure Data", url: "https://www.cms.gov"),
            SourceLink(title: "CDC National Center for Health Statistics", url: "https://www.cdc.gov/nchs"),
            SourceLink(title: "FCC Reports and Research", url: "https://www.fcc.gov/reports-research"),
        ],
        statSuggestions: ["What share of U.S. electricity comes from renewables?", "How much does the U.S. spend on health care per person?", "How many Americans are uninsured?", "How much has the average electricity bill risen?"],
        bills: ["A Bill to Allow Medicare to Negotiate All Prescription Drug Prices", "A Bill to Require a Federal Online Data Privacy Standard"]),

    Committee(name: "Science, Space, and Technology", chamber: "House",
        jurisdiction: "Non-defense scientific research, NASA, NSF, NIST, NOAA research, energy research, and STEM education.",
        agencies: ["NASA", "National Science Foundation", "NIST", "NOAA", "DOE Office of Science"],
        sources: [
            SourceLink(title: "NSF National Center for Science and Engineering Statistics", url: "https://ncses.nsf.gov"),
            SourceLink(title: "NASA Budget and Reports", url: "https://www.nasa.gov/budgets-plans-and-reports"),
            SourceLink(title: "NIST", url: "https://www.nist.gov"),
            SourceLink(title: "NSF Budget and Performance", url: "https://www.nsf.gov/about/budget"),
        ],
        statSuggestions: ["How many satellites are in orbit right now?", "What share of U.S. adults use AI tools?", "How much does the U.S. spend on federal R&D?", "How many STEM degrees are awarded each year?"],
        bills: ["A Bill to Double Federal Basic Research Funding Over Five Years", "A Bill to Establish a National Artificial Intelligence Safety Institute"]),

    Committee(name: "Oversight and Reform", chamber: "House",
        jurisdiction: "Government-wide oversight, the federal workforce, the Postal Service, the census, and the District of Columbia.",
        agencies: ["OPM", "GSA", "U.S. Postal Service", "Census Bureau"],
        sources: [
            SourceLink(title: "GAO High-Risk List", url: "https://www.gao.gov/high-risk-list"),
            SourceLink(title: "OPM FedScope Workforce Data", url: "https://www.fedscope.opm.gov"),
            SourceLink(title: "Oversight.gov — Inspector General reports", url: "https://www.oversight.gov"),
            SourceLink(title: "USPS Financial Reports", url: "https://about.usps.com/what/financials"),
        ],
        statSuggestions: ["How much does the federal government lose to improper payments each year?", "How large is the Postal Service deficit?", "How many federal employees work remotely?", "What did the last census cost per household?"],
        bills: ["A Bill to Make Washington, D.C. the Fifty-First State", "A Bill to Reform the Federal Hiring Process"]),

    Committee(name: "Transportation and Infrastructure", chamber: "House",
        jurisdiction: "Highways, transit, aviation, rail, ports and waterways, pipelines, the Coast Guard, and public buildings.",
        agencies: ["Department of Transportation", "FAA", "Federal Highway Administration", "Amtrak", "Army Corps of Engineers"],
        sources: [
            SourceLink(title: "Bureau of Transportation Statistics", url: "https://www.bts.gov"),
            SourceLink(title: "FHWA Highway Statistics", url: "https://www.fhwa.dot.gov/policyinformation/statistics.cfm"),
            SourceLink(title: "NHTSA Data", url: "https://www.nhtsa.gov/data"),
            SourceLink(title: "ASCE Infrastructure Report Card", url: "https://infrastructurereportcard.org"),
        ],
        statSuggestions: ["How many U.S. bridges are structurally deficient?", "How many people ride Amtrak each year?", "What share of flights arrive on time?", "How much of the Highway Trust Fund comes from the gas tax?"],
        bills: ["A Bill to Fund High-Speed Rail Corridors", "A Bill to Raise the Federal Gas Tax and Index It to Inflation"]),

    Committee(name: "Natural Resources", chamber: "House",
        jurisdiction: "Public lands, national parks, water and power, fisheries and wildlife, mining, tribal affairs, and U.S. territories.",
        agencies: ["Department of the Interior", "Bureau of Land Management", "National Park Service", "Bureau of Indian Affairs"],
        sources: [
            SourceLink(title: "USGS Mineral Commodity Summaries", url: "https://www.usgs.gov/centers/national-minerals-information-center"),
            SourceLink(title: "National Park Service Visitation Statistics", url: "https://irma.nps.gov/Stats"),
            SourceLink(title: "Department of the Interior", url: "https://www.doi.gov"),
            SourceLink(title: "Congressional Research Service", url: "https://crsreports.congress.gov"),
        ],
        statSuggestions: ["How much land does the federal government own?", "How many people visited national parks last year?", "How much lithium does the U.S. produce?", "How many acres burned in wildfires last year?"],
        bills: ["A Bill to Ban New Oil and Gas Leasing on Federal Lands", "A Bill to Grant Statehood to Puerto Rico"]),

    Committee(name: "Ethics", chamber: "House and Senate",
        jurisdiction: "Standards of conduct for members and staff, financial disclosure, gifts, travel, and misconduct investigations.",
        agencies: ["House Committee on Ethics", "Senate Select Committee on Ethics"],
        sources: [
            SourceLink(title: "House Committee on Ethics", url: "https://ethics.house.gov"),
            SourceLink(title: "Senate Select Committee on Ethics", url: "https://www.ethics.senate.gov"),
            SourceLink(title: "House Financial Disclosure Reports", url: "https://disclosures-clerk.house.gov"),
            SourceLink(title: "Senate Financial Disclosure", url: "https://efdsearch.senate.gov"),
        ],
        statSuggestions: ["How many members of Congress trade individual stocks?", "How many ethics investigations opened last year?", "How much privately funded travel do members take?", "What share of members are millionaires?"],
        bills: ["A Bill to Ban Individual Stock Trading by Members of Congress", "A Bill to Require Public Disclosure of All Privately Funded Congressional Travel"]),
]

enum SpeechStance: String, Hashable {
    case pro = "Pro"
    case con = "Con"
}

struct CongressSegment: Hashable {
    let title: String
    let stance: SpeechStance
    let seconds: Int

    var wordBudget: Int { max(120, seconds * 150 / 60) }

    var clock: String {
        let minutes = seconds / 60
        let rest = seconds % 60
        return rest == 0 ? "\(minutes):00" : String(format: "%d:%02d", minutes, rest)
    }
}

struct Participant: Hashable, Codable {
    var name: String
    var side: Side
    var role: String
    var isUser: Bool
}

struct PracticeConfig: Hashable {
    var kind: PracticeKind
    var topic: String
    var language: Language
    var difficulty: Difficulty
    var mode: SessionMode
    var userSide: Side = .affirmative
    var participants: [Participant] = []
    var online: Bool = false
    var judgePreset: JudgePreset = .novice
    var judgeInstructions: String = ""
    var committee: String = ""
    var billText: String = ""
    var billFilename: String = ""
    var lowPressure: Bool = false
    var plainLanguage: Bool = false

    var isJudged: Bool { mode.isJudged }

    var userIsAuthor: Bool { userSide == .affirmative }

    var userStance: SpeechStance { userSide == .affirmative ? .pro : .con }

    func userSpeaks(_ stance: SpeechStance) -> Bool { stance == userStance }

    func names(on side: Side) -> String {
        let list = participants.filter { $0.side == side }.map(\.name)
        return list.isEmpty ? side.rawValue : list.joined(separator: " & ")
    }
}

enum MessageKind: String, Codable, Hashable {
    case speech
    case crossfireQuestion
    case crossfireAnswer
    case inquiry
    case ruling
    case amendment
}

struct ChatMessage: Identifiable, Codable, Hashable {
    enum Role: String, Codable {
        case user
        case assistant
    }

    var id: UUID = UUID()
    var role: Role
    var text: String
    var speaker: String? = nil
    var statCheck: String? = nil
    var kind: MessageKind? = nil

    var effectiveKind: MessageKind { kind ?? .speech }

    static func questions(in text: String) -> [String] {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let numbered = lines.compactMap { line -> String? in
            guard let match = line.range(of: #"^\s*(\d+[.)]|[-•*])\s*"#, options: .regularExpression) else { return nil }
            let body = String(line[match.upperBound...]).trimmingCharacters(in: .whitespaces)
            return body.isEmpty ? nil : body
        }
        let candidates = numbered.isEmpty ? lines.filter { $0.contains("?") } : numbered
        return Array(candidates.prefix(3))
    }
}

enum SpeechSlot: Hashable {
    case player(Int)
    case ai
}

struct ScriptStep: Hashable {
    let slot: SpeechSlot
    let kind: MessageKind
}

enum RoundScript {
    static let congress: [CongressSegment] = [
        CongressSegment(title: "Authorship speech", stance: .pro, seconds: 120),
        CongressSegment(title: "Constructive", stance: .con, seconds: 240),
        CongressSegment(title: "Second speech", stance: .pro, seconds: 120),
        CongressSegment(title: "Closing", stance: .con, seconds: 120),
    ]

    static let floorSpeech = CongressSegment(title: "Floor speech", stance: .pro, seconds: 120)

    static func congressSegment(_ n: Int) -> CongressSegment? {
        n < congress.count ? congress[n] : nil
    }

    static func congressIsOpenFloor(_ n: Int) -> Bool { n >= congress.count }

    static let team: [ScriptStep] = [
        ScriptStep(slot: .player(0), kind: .speech),
        ScriptStep(slot: .ai, kind: .speech),
        ScriptStep(slot: .ai, kind: .crossfireQuestion),
        ScriptStep(slot: .player(0), kind: .crossfireAnswer),
        ScriptStep(slot: .player(1), kind: .crossfireAnswer),
        ScriptStep(slot: .player(0), kind: .crossfireAnswer),
        ScriptStep(slot: .player(1), kind: .speech),
    ]

    static func teamStep(_ n: Int) -> ScriptStep {
        if n < team.count { return team[n] }
        let k = n - team.count
        return k % 2 == 0 ? ScriptStep(slot: .ai, kind: .speech) : ScriptStep(slot: .player((k / 2) % 2), kind: .speech)
    }
}

struct DebateFeedback: Codable, Hashable {
    var strongestArgument: String
    var weakestArgument: String
    var missedRebuttal: String
    var suggestion: String

    static func sectionTitles(for kind: PracticeKind) -> [String] {
        switch kind {
        case .debate:
            return ["Strongest argument", "Weakest argument", "Missed rebuttal opportunity", "Concrete suggestion for next time"]
        case .congress:
            return ["Strongest argument", "Weakest argument", "Missed opportunity in refutation or questioning", "Concrete suggestion for next time"]
        }
    }
}

struct JudgeDecision: Codable, Hashable {
    var winner: String
    var reasonForDecision: String
    var affirmativeFeedback: String
    var negativeFeedback: String
}

enum SessionFeedback: Hashable {
    case coach(DebateFeedback)
    case judge(JudgeDecision)

    var improvementText: String {
        switch self {
        case .coach(let f): return f.weakestArgument + " " + f.suggestion
        case .judge(let j): return j.affirmativeFeedback + " " + j.negativeFeedback
        }
    }
}

struct SessionRecord: Identifiable, Hashable {
    let id: Int64
    let userId: Int64
    let kind: PracticeKind
    let topic: String
    let language: String
    let difficulty: String
    let mode: String
    let transcript: [ChatMessage]
    let feedback: SessionFeedback?
    let createdAt: String

    var sessionMode: SessionMode { SessionMode(rawValue: mode) ?? .debate }

    var createdDate: Date? {
        ISO8601DateFormatter().date(from: createdAt)
    }

    var createdDisplay: String {
        guard let date = createdDate else { return createdAt }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    var ownTurns: [String] {
        transcript.filter { $0.role == .user }.map(\.text)
    }
}

struct Streak {
    var current: Int
    var longest: Int
    var lastActiveDate: String?

    static let none = Streak(current: 0, longest: 0, lastActiveDate: nil)
}
