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
    case briefing = "Briefing"
    case versus = "1v1"
    case twoVtwo = "2v2"
    case team = "Team vs AI"
    case congress = "Congress"

    var id: String { rawValue }

    static func options(for kind: PracticeKind) -> [SessionMode] {
        kind == .debate ? [.debate, .coach, .briefing, .versus, .twoVtwo, .team] : [.congress]
    }

    var isMultiplayer: Bool { self == .versus || self == .twoVtwo || self == .team }
    var isJudged: Bool { self == .versus || self == .twoVtwo }
    var humanCount: Int { self == .twoVtwo ? 4 : isMultiplayer ? 2 : 1 }

    var icon: String {
        switch self {
        case .debate: return "bubble.left.and.bubble.right"
        case .coach: return "graduationcap"
        case .briefing: return "doc.text.magnifyingglass"
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
        case .briefing:
            return "Text-to-text. Write out your points and get back a sharpened version with what changed — no live opponent."
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
        case .briefing: return "Editor"
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

enum Chamber: String, CaseIterable, Codable {
    case house = "House of Representatives"
    case senate = "Senate"
}

struct Committee: Identifiable, Hashable {
    let chamber: Chamber
    let name: String
    let jurisdiction: String
    let agencies: [String]
    let sources: [String]
    let bills: [String]
    var id: String { "\(chamber.rawValue) — \(name)" }
    var fullName: String { "\(chamber == .house ? "House" : "Senate") Committee on \(name)" }
}

let committees: [Committee] = [
    Committee(chamber: .house, name: "Agriculture", jurisdiction: "Farm programs, crop insurance, commodity markets, nutrition assistance including SNAP, rural development, forestry, and agricultural research.", agencies: ["USDA", "Commodity Futures Trading Commission", "Farm Credit Administration"], sources: ["USDA Economic Research Service", "USDA National Agricultural Statistics Service", "CBO farm bill baseline", "CRS reports"], bills: ["A Bill to Expand SNAP Eligibility for College Students", "A Bill to Cap Federal Crop Insurance Subsidies for Large Farms"]),
    Committee(chamber: .house, name: "Appropriations", jurisdiction: "Annual discretionary spending bills that fund every federal department and agency.", agencies: ["Office of Management and Budget", "every executive department"], sources: ["Congressional Budget Office", "OMB Historical Tables", "Appropriations committee reports", "GAO"], bills: ["A Bill to Reduce Discretionary Spending by Five Percent Across All Agencies", "A Bill to Fully Fund the Federal Pell Grant Program"]),
    Committee(chamber: .house, name: "Armed Services", jurisdiction: "The Department of Defense, military pay and readiness, weapons procurement, and the annual National Defense Authorization Act.", agencies: ["Department of Defense", "Army, Navy, Air Force, Marine Corps, Space Force"], sources: ["DoD Comptroller budget materials", "CBO defense analyses", "GAO weapon systems assessments", "CRS"], bills: ["A Bill to Raise Base Pay for Junior Enlisted Service Members", "A Bill to Require Congressional Approval for Overseas Troop Deployments Beyond 90 Days"]),
    Committee(chamber: .house, name: "Budget", jurisdiction: "The annual congressional budget resolution, spending and revenue targets, and enforcement of budget rules.", agencies: ["Congressional Budget Office", "Office of Management and Budget"], sources: ["CBO Budget and Economic Outlook", "CBO Long-Term Budget Outlook", "Treasury Monthly Statement"], bills: ["A Bill to Adopt a Balanced Budget Requirement Over Ten Years", "A Bill to Establish an Independent Fiscal Commission"]),
    Committee(chamber: .house, name: "Education and Workforce", jurisdiction: "K-12 and higher education, student loans, job training, labor standards, wages, workplace safety, and pensions.", agencies: ["Department of Education", "Department of Labor", "National Labor Relations Board"], sources: ["National Center for Education Statistics", "Bureau of Labor Statistics", "Federal Student Aid data center", "OSHA statistics"], bills: ["A Bill to Raise the Federal Minimum Wage", "A Bill to Make Community College Tuition-Free"]),
    Committee(chamber: .house, name: "Energy and Commerce", jurisdiction: "Health care, energy, environment, telecommunications, consumer protection, and interstate commerce — the broadest House jurisdiction.", agencies: ["HHS", "Department of Energy", "EPA", "FCC", "FTC", "FDA"], sources: ["Energy Information Administration", "CMS National Health Expenditure data", "CDC National Center for Health Statistics", "FCC broadband maps"], bills: ["A Bill to Allow Medicare to Negotiate All Prescription Drug Prices", "A Bill to Require a Federal Online Data Privacy Standard"]),
    Committee(chamber: .house, name: "Ethics", jurisdiction: "Standards of conduct for House members and staff, financial disclosure, gifts, and travel.", agencies: ["Office of Congressional Conduct"], sources: ["House Ethics Manual", "Financial disclosure database", "Office of Congressional Conduct reports"], bills: ["A Bill to Ban Individual Stock Trading by Members of Congress", "A Bill to Require Public Disclosure of All Privately Funded Congressional Travel"]),
    Committee(chamber: .house, name: "Financial Services", jurisdiction: "Banking, securities, insurance, housing, the Federal Reserve, and international finance.", agencies: ["Federal Reserve", "Treasury", "SEC", "FDIC", "HUD", "CFPB"], sources: ["Federal Reserve FRED database", "FDIC Quarterly Banking Profile", "HUD Annual Homelessness Assessment Report", "SEC data"], bills: ["A Bill to Cap Credit Card Interest Rates", "A Bill to Expand the Low-Income Housing Tax Credit"]),
    Committee(chamber: .house, name: "Foreign Affairs", jurisdiction: "Foreign policy, foreign aid, arms sales, treaties as they touch the House, and international organizations.", agencies: ["Department of State", "USAID", "Peace Corps"], sources: ["State Department Congressional Budget Justification", "CRS foreign assistance reports", "USAspending.gov", "UN and World Bank data"], bills: ["A Bill to Condition Military Aid on Human Rights Benchmarks", "A Bill to Increase Global Health Assistance"]),
    Committee(chamber: .house, name: "Homeland Security", jurisdiction: "The Department of Homeland Security, border security, transportation security, cybersecurity, and emergency management.", agencies: ["DHS", "CBP", "TSA", "FEMA", "CISA", "Coast Guard"], sources: ["DHS Office of Homeland Security Statistics", "CBP monthly encounter data", "FEMA disaster declarations database", "GAO"], bills: ["A Bill to Increase Funding for Border Technology Over Physical Barriers", "A Bill to Create a National Cybersecurity Reserve Corps"]),
    Committee(chamber: .house, name: "House Administration", jurisdiction: "Federal elections, the Library of Congress, the Smithsonian, and House operations and security.", agencies: ["Federal Election Commission", "Election Assistance Commission", "Library of Congress"], sources: ["FEC campaign finance data", "EAC Election Administration and Voting Survey", "Census voting and registration tables"], bills: ["A Bill to Require Paper Ballots in All Federal Elections", "A Bill to Establish Automatic Voter Registration"]),
    Committee(chamber: .house, name: "Judiciary", jurisdiction: "Federal courts, criminal justice, immigration, civil liberties, antitrust, intellectual property, and constitutional amendments.", agencies: ["Department of Justice", "FBI", "Bureau of Prisons", "USCIS", "Federal judiciary"], sources: ["Bureau of Justice Statistics", "FBI crime data explorer", "U.S. Sentencing Commission", "DHS immigration statistics yearbook"], bills: ["A Bill to Eliminate Mandatory Minimum Sentences for Nonviolent Drug Offenses", "A Bill to Create a Pathway to Citizenship for Dreamers"]),
    Committee(chamber: .house, name: "Natural Resources", jurisdiction: "Public lands, national parks, water and power, fisheries and wildlife, mining, tribal affairs, and U.S. territories.", agencies: ["Department of the Interior", "Bureau of Land Management", "National Park Service", "Bureau of Indian Affairs"], sources: ["Interior budget justifications", "USGS mineral commodity summaries", "National Park Service visitation statistics", "CRS public lands reports"], bills: ["A Bill to Ban New Oil and Gas Leasing on Federal Lands", "A Bill to Grant Statehood to Puerto Rico"]),
    Committee(chamber: .house, name: "Oversight and Government Reform", jurisdiction: "Government-wide oversight, the federal workforce, the Postal Service, the census, and the District of Columbia.", agencies: ["Office of Personnel Management", "General Services Administration", "U.S. Postal Service", "Census Bureau"], sources: ["GAO High-Risk List", "OPM FedScope workforce data", "Inspector General reports", "Postal Service financial reports"], bills: ["A Bill to Make Washington, D.C. the Fifty-First State", "A Bill to Reform the Federal Hiring Process"]),
    Committee(chamber: .house, name: "Rules", jurisdiction: "Sets the terms of floor debate for every major bill and governs House procedure.", agencies: ["House Parliamentarian"], sources: ["House Rules and Manual", "CRS legislative process reports"], bills: ["A Bill to Require 72 Hours of Public Notice Before Any Floor Vote", "A Bill to Guarantee an Open Amendment Process for Appropriations Bills"]),
    Committee(chamber: .house, name: "Science, Space, and Technology", jurisdiction: "Non-defense scientific research, NASA, NSF, NIST, NOAA research, energy research, and STEM education.", agencies: ["NASA", "National Science Foundation", "NIST", "NOAA", "DOE Office of Science"], sources: ["NSF National Center for Science and Engineering Statistics", "NASA budget requests", "OSTP reports", "AAAS R&D budget analysis"], bills: ["A Bill to Double Federal Basic Research Funding Over Five Years", "A Bill to Establish a National Artificial Intelligence Safety Institute"]),
    Committee(chamber: .house, name: "Small Business", jurisdiction: "The Small Business Administration, small business lending, contracting, and regulatory burden.", agencies: ["Small Business Administration"], sources: ["SBA Office of Advocacy small business profiles", "Census Bureau Business Dynamics Statistics", "Federal Reserve Small Business Credit Survey"], bills: ["A Bill to Expand SBA Microloans for First-Time Entrepreneurs", "A Bill to Simplify Federal Contracting for Small Businesses"]),
    Committee(chamber: .house, name: "Transportation and Infrastructure", jurisdiction: "Highways, transit, aviation, rail, ports and waterways, pipelines, the Coast Guard, and public buildings.", agencies: ["Department of Transportation", "FAA", "Federal Highway Administration", "Amtrak", "Army Corps of Engineers"], sources: ["Bureau of Transportation Statistics", "FHWA Highway Statistics", "NHTSA traffic safety facts", "ASCE Infrastructure Report Card"], bills: ["A Bill to Fund High-Speed Rail Corridors", "A Bill to Raise the Federal Gas Tax and Index It to Inflation"]),
    Committee(chamber: .house, name: "Veterans' Affairs", jurisdiction: "Veterans' health care, disability compensation, education benefits, and the Department of Veterans Affairs.", agencies: ["Department of Veterans Affairs", "Veterans Health Administration", "Veterans Benefits Administration"], sources: ["VA National Center for Veterans Analysis and Statistics", "VA budget submissions", "VA Office of Inspector General", "GAO"], bills: ["A Bill to Expand Community Care Options for Rural Veterans", "A Bill to Guarantee Mental Health Appointments Within Seven Days"]),
    Committee(chamber: .house, name: "Ways and Means", jurisdiction: "Taxes, tariffs and trade, Social Security, Medicare, and welfare programs.", agencies: ["Treasury", "IRS", "Social Security Administration", "CMS", "U.S. Trade Representative"], sources: ["Joint Committee on Taxation estimates", "IRS Statistics of Income", "Social Security Trustees Report", "Medicare Trustees Report", "Census income and poverty tables"], bills: ["A Bill to Raise the Social Security Payroll Tax Cap", "A Bill to Expand the Child Tax Credit"]),
    Committee(chamber: .house, name: "Permanent Select Committee on Intelligence", jurisdiction: "Oversight of the intelligence community, intelligence budgets, and surveillance authorities.", agencies: ["Office of the Director of National Intelligence", "CIA", "NSA", "FBI intelligence programs"], sources: ["ODNI Annual Threat Assessment", "ODNI statistical transparency reports", "Privacy and Civil Liberties Oversight Board reports"], bills: ["A Bill to Require Warrants for Surveillance of Americans' Communications", "A Bill to Increase Public Reporting on Intelligence Spending"]),
    Committee(chamber: .senate, name: "Agriculture, Nutrition, and Forestry", jurisdiction: "Farm programs, food and nutrition programs, forestry, rural development, and commodity markets.", agencies: ["USDA", "Commodity Futures Trading Commission", "U.S. Forest Service"], sources: ["USDA Economic Research Service", "USDA Food and Nutrition Service program data", "CBO", "CRS"], bills: ["A Bill to Reform Commodity Payment Limits", "A Bill to Expand Universal Free School Meals"]),
    Committee(chamber: .senate, name: "Appropriations", jurisdiction: "Annual discretionary spending bills funding the federal government.", agencies: ["Office of Management and Budget", "every executive department"], sources: ["Congressional Budget Office", "OMB Historical Tables", "Committee reports", "GAO"], bills: ["A Bill to Increase Funding for the National Institutes of Health", "A Bill to Freeze Non-Defense Discretionary Spending"]),
    Committee(chamber: .senate, name: "Armed Services", jurisdiction: "The Department of Defense, military nominations, defense policy, and the National Defense Authorization Act.", agencies: ["Department of Defense", "the military services"], sources: ["DoD Comptroller", "CBO defense analyses", "GAO", "CRS"], bills: ["A Bill to Require Women to Register for Selective Service", "A Bill to Audit the Department of Defense Annually"]),
    Committee(chamber: .senate, name: "Banking, Housing, and Urban Affairs", jurisdiction: "Banks, financial markets, insurance, housing, mass transit, and export controls.", agencies: ["Federal Reserve", "Treasury", "SEC", "FDIC", "HUD", "CFPB"], sources: ["Federal Reserve FRED database", "HUD Annual Homelessness Assessment Report", "FDIC data", "Census housing data"], bills: ["A Bill to Create a National Rental Assistance Guarantee", "A Bill to Establish a Federal Public Banking Option"]),
    Committee(chamber: .senate, name: "Budget", jurisdiction: "The congressional budget resolution and enforcement of budget rules.", agencies: ["Congressional Budget Office", "Office of Management and Budget"], sources: ["CBO Budget and Economic Outlook", "CBO Long-Term Budget Outlook", "Treasury debt data"], bills: ["A Bill to Require CBO Scoring of All Major Executive Actions", "A Bill to Establish Statutory Debt-to-GDP Targets"]),
    Committee(chamber: .senate, name: "Commerce, Science, and Transportation", jurisdiction: "Interstate commerce, transportation, telecommunications, consumer protection, science, oceans, and sports.", agencies: ["Department of Commerce", "Department of Transportation", "FCC", "FTC", "NASA", "NOAA"], sources: ["Bureau of Transportation Statistics", "FCC reports", "NOAA data", "Census economic indicators"], bills: ["A Bill to Require Age Verification for Social Media Platforms", "A Bill to Set Federal Standards for Autonomous Vehicles"]),
    Committee(chamber: .senate, name: "Energy and Natural Resources", jurisdiction: "Energy policy, public lands, national parks, mining, water and power, and the Department of Energy.", agencies: ["Department of Energy", "Department of the Interior", "Federal Energy Regulatory Commission"], sources: ["Energy Information Administration", "USGS mineral commodity summaries", "Interior budget justifications"], bills: ["A Bill to Streamline Permitting for Transmission Lines", "A Bill to Create a Strategic Critical Minerals Reserve"]),
    Committee(chamber: .senate, name: "Environment and Public Works", jurisdiction: "Environmental protection, air and water quality, highways and bridges, water infrastructure, and nuclear safety.", agencies: ["EPA", "Federal Highway Administration", "Army Corps of Engineers", "Nuclear Regulatory Commission"], sources: ["EPA greenhouse gas inventory", "EPA air quality trends", "FHWA bridge condition data", "ASCE Infrastructure Report Card"], bills: ["A Bill to Set a National Standard for PFAS in Drinking Water", "A Bill to Fund Replacement of All Lead Service Lines"]),
    Committee(chamber: .senate, name: "Finance", jurisdiction: "Taxes, trade, Social Security, Medicare, Medicaid, and other health and welfare programs.", agencies: ["Treasury", "IRS", "Social Security Administration", "CMS", "U.S. Trade Representative"], sources: ["Joint Committee on Taxation", "Social Security and Medicare Trustees Reports", "CMS Medicaid enrollment data", "IRS Statistics of Income"], bills: ["A Bill to Raise the Corporate Tax Rate", "A Bill to Lower the Medicare Eligibility Age to 60"]),
    Committee(chamber: .senate, name: "Foreign Relations", jurisdiction: "Treaties, ambassador nominations, foreign aid, arms sales, and overall foreign policy.", agencies: ["Department of State", "USAID"], sources: ["State Department budget justification", "CRS", "UN data", "World Bank and IMF data"], bills: ["A Bill to Ratify the Treaty on the Prohibition of Nuclear Weapons", "A Bill to Repeal Outdated Authorizations for the Use of Military Force"]),
    Committee(chamber: .senate, name: "Health, Education, Labor, and Pensions", jurisdiction: "Public health, education, labor, workplace safety, and retirement plans.", agencies: ["HHS", "Department of Education", "Department of Labor", "FDA", "NIH", "CDC"], sources: ["CDC National Center for Health Statistics", "National Center for Education Statistics", "Bureau of Labor Statistics", "Federal Student Aid data"], bills: ["A Bill to Guarantee Paid Family and Medical Leave", "A Bill to Cap Insulin Prices Nationwide"]),
    Committee(chamber: .senate, name: "Homeland Security and Governmental Affairs", jurisdiction: "The Department of Homeland Security, government operations, the federal workforce, and the Postal Service.", agencies: ["DHS", "FEMA", "OPM", "GSA", "U.S. Postal Service"], sources: ["DHS Office of Homeland Security Statistics", "GAO High-Risk List", "OPM FedScope", "Inspector General reports"], bills: ["A Bill to Reform Federal Disaster Aid Formulas", "A Bill to Require Cybersecurity Standards for Critical Infrastructure"]),
    Committee(chamber: .senate, name: "Judiciary", jurisdiction: "Federal courts and judicial nominations, criminal law, immigration, civil rights, antitrust, and intellectual property.", agencies: ["Department of Justice", "FBI", "Federal judiciary", "USCIS"], sources: ["Bureau of Justice Statistics", "FBI crime data", "U.S. Sentencing Commission", "DHS immigration statistics"], bills: ["A Bill to Establish Term Limits for Supreme Court Justices", "A Bill to Reform Federal Cash Bail"]),
    Committee(chamber: .senate, name: "Rules and Administration", jurisdiction: "Senate rules and procedure, federal elections, and Senate administration.", agencies: ["Federal Election Commission", "Election Assistance Commission", "Senate Parliamentarian"], sources: ["FEC data", "EAC surveys", "Senate Rules and Manual"], bills: ["A Bill to Reform the Senate Filibuster", "A Bill to Make Election Day a Federal Holiday"]),
    Committee(chamber: .senate, name: "Small Business and Entrepreneurship", jurisdiction: "The Small Business Administration and policies affecting small businesses.", agencies: ["Small Business Administration"], sources: ["SBA Office of Advocacy", "Census Business Dynamics Statistics", "Federal Reserve Small Business Credit Survey"], bills: ["A Bill to Create a Startup Visa", "A Bill to Expand Broadband Grants for Rural Small Businesses"]),
    Committee(chamber: .senate, name: "Veterans' Affairs", jurisdiction: "Veterans' benefits, health care, and the Department of Veterans Affairs.", agencies: ["Department of Veterans Affairs"], sources: ["VA National Center for Veterans Analysis and Statistics", "VA OIG", "GAO", "CBO"], bills: ["A Bill to Expand Benefits for Veterans Exposed to Toxic Substances", "A Bill to Fund Veteran Housing Vouchers"]),
    Committee(chamber: .senate, name: "Select Committee on Intelligence", jurisdiction: "Oversight of the intelligence community and intelligence authorizations.", agencies: ["ODNI", "CIA", "NSA"], sources: ["ODNI Annual Threat Assessment", "ODNI statistical transparency reports", "PCLOB reports"], bills: ["A Bill to Reform Section 702 Surveillance Authorities", "A Bill to Strengthen Whistleblower Protections in the Intelligence Community"]),
    Committee(chamber: .senate, name: "Select Committee on Ethics", jurisdiction: "Senate standards of conduct, financial disclosure, and misconduct investigations.", agencies: ["Senate Ethics staff"], sources: ["Senate Ethics Manual", "Senate financial disclosure database"], bills: ["A Bill to Ban Senators From Trading Individual Stocks", "A Bill to Require Disclosure of Foreign Contacts by Senate Staff"]),
    Committee(chamber: .senate, name: "Committee on Indian Affairs", jurisdiction: "Matters affecting Native American tribes, including health, education, land, and economic development.", agencies: ["Bureau of Indian Affairs", "Indian Health Service"], sources: ["Indian Health Service statistics", "Bureau of Indian Affairs reports", "Census American Indian and Alaska Native data", "GAO"], bills: ["A Bill to Fully Fund the Indian Health Service", "A Bill to Expand Tribal Jurisdiction Over Crimes on Tribal Land"]),
    Committee(chamber: .senate, name: "Special Committee on Aging", jurisdiction: "Studies issues affecting older Americans, including retirement, health care, and elder fraud, and reports to the Senate.", agencies: ["Social Security Administration", "CMS", "Administration for Community Living"], sources: ["Social Security Trustees Report", "Census population projections", "FTC elder fraud data", "CMS data"], bills: ["A Bill to Expand Home and Community-Based Care for Seniors", "A Bill to Strengthen Penalties for Scams Targeting Older Adults"]),
]

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
    var lowPressure: Bool = false
    var plainLanguage: Bool = false

    var isJudged: Bool { mode.isJudged }

    func names(on side: Side) -> String {
        let list = participants.filter { $0.side == side }.map(\.name)
        return list.isEmpty ? side.rawValue : list.joined(separator: " & ")
    }
}

enum MessageKind: String, Codable, Hashable {
    case speech
    case crossfireQuestion
    case crossfireAnswer
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
