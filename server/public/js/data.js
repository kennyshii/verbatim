export const MODES = {
  debate: {
    id: "Debate", icon: "debate",
    explanation: "Live back-and-forth. The AI argues the opposing side in real time; structured feedback comes after you end.",
    assistantLabel: "Opponent",
  },
  coach: {
    id: "Coach", icon: "coach",
    explanation: "No opponent. The AI gives structured, critical feedback after each of your turns.",
    assistantLabel: "Coach",
  },
  versus: {
    id: "1v1", icon: "versus",
    explanation: "Debate another person — on this device or online with a room code. An AI judge decides the round using the paradigm you pick.",
    assistantLabel: "Judge",
  },
  twoVtwo: {
    id: "2v2", icon: "twoVtwo",
    explanation: "Public Forum style, two on two. First speakers build the case, second speakers rebut. Same device or online with a code; an AI judge decides.",
    assistantLabel: "Judge",
  },
  team: {
    id: "Team vs AI", icon: "team",
    explanation: "You and a partner on the same side: one presents the case, the other rebuts. The AI plays both opposing speakers and ends every speech with crossfire questions.",
    assistantLabel: "Opposing team",
  },
  congress: {
    id: "Congress", icon: "congress",
    explanation: "Give speeches on a bill. An opposing member refutes you and asks a question; a parliamentarian scores you at the end.",
    assistantLabel: "Opposing member",
  },
};

export const DEBATE_MODES = ["Debate", "Coach", "1v1", "2v2", "Team vs AI"];

export function modeInfo(id) {
  return Object.values(MODES).find((m) => m.id === id) || MODES.debate;
}

export const isMultiplayer = (mode) => mode === "1v1" || mode === "2v2" || mode === "Team vs AI";
export const isJudged = (mode) => mode === "1v1" || mode === "2v2";
export const humanCount = (mode) => (mode === "2v2" ? 4 : isMultiplayer(mode) ? 2 : 1);

export const DIFFICULTIES = [
  { id: "Easy", icon: "leaf", explanation: "Straightforward arguments, one point at a time." },
  { id: "Medium", icon: "flame", explanation: "Solid rebuttals that push back on your reasoning." },
  { id: "Hard", icon: "bolt", explanation: "Tournament-level pressure. Every weak point gets attacked." },
];

export const LANGUAGES = [
  { id: "English", speechCode: "en-US" },
  { id: "Spanish", speechCode: "es-ES" },
  { id: "French", speechCode: "fr-FR" },
];

export const speechCode = (language) => (LANGUAGES.find((l) => l.id === language) || LANGUAGES[0]).speechCode;

export const SIDES = ["Affirmative", "Negative"];
export const opposite = (side) => (side === "Affirmative" ? "Negative" : "Affirmative");

export const JUDGE_PRESETS = {
  Novice: {
    sampleRFD: "I vote negative (Syosset AH). On case, I'm not sure I give the affirmative access to their extinction impact. They extend populism and mathematical certainty in the 2AR. However, I don't find the populism responses persuasive. The point about psychology seems new and under warranted, and I'm overall not persuaded by the idea that one leader is enough to trigger the impact. I don't see how this responds to the idea that nukes would still cap an irrational leader. On mathematical certainty, the 2AR concedes the point that if this is true, I prioritize the neg because their extinction impact happens sooner. That's especially true when I don't know the timeline for when nuclear war happens in the aff world (and deterrence provides enough defense to doubt), but I know it's imminent under bioweapons. On bioweapons, I don't get a warrant for tech checking back against this in the 2AR. This seems too new because it was blippy in the 1AR. I don't get a sufficient extension of the deterrence double bind, which means the argument stands. There is an extinction impact, which means it does get weighed, and I think it's more probable than nuclear war given the state of the flow in this debate (under warranted responses = higher likelihood of impact on bioweapons, decent defense on deterrence = lower likelihood of impact on nuclear weapons.). Thus, I vote neg.",
    instructions: "You are judging a novice round. Decide the round on the arguments as they were actually presented; do not intervene with your own knowledge or opinions. Reward clear claims, warrants, and direct clash. Give weight to arguments that were extended and answered over arguments that were dropped, but do not punish a novice harshly for minor drops or technical mistakes. Prioritize clarity, organization, and whether each side explained why their arguments matter. Do not reward speed, jargon, or theory arguments. Decide which side better upheld or negated the resolution overall, and explain the decision in plain language a first-year debater can learn from.",
  },
  Varsity: {
    sampleRFD: "Both AFF and NEG had exceptionally strong Constructives. NEG made the argument that they only had the burden of proving that plea bargains are unjust, they did not have to provide an alternative, and I agreed with this. This shifted the burden to AFF to argue against the NEG contentions of Environmental Crimes and Racial Inequalities, both under the value criterion of Mitigating Structural Violence. AFF erred in my opinion by not recognizing that NEG wasn't arguing against plea bargaining. AFF spent a lot of time during 1AR repeating the AFF contentions (e.g., arguing that plea bargaining is better than getting rid of plea bargaining), but NEG had already stated that he wasn't advocating to get rid of plea bargaining so this was ultimately time wasted. AFF spent so much time on this during 1AR that she ran out of time to counter the second NEG contention of Racial Inequalities, which was in my opinion the stronger of the two NEG contentions. In the end, the NEG contention that plea bargains are unjust because they unfairly target minorities carried my vote. This included the arguments that the poor are more affected because they can't afford to sit in jail awaiting trial and be without a job; the police know that targeting minorities is more likely to result in conviction by plea bargain and help their numbers; etc. NEG also provided very strong statistics about the economic impact from any plea bargains and the impact on minorities.\nOne piece of feedback for NEG is that the Environmental Crimes contention seemed a bit weak to me. I think NEG overshot the impact of companies polluting BECAUSE of plea bargaining, or that somehow plea bargaining in and of itself was making pollution worse. I understood the intention that there was precedent set and that companies always want to plea bargain out these cases so that they can pay a fine instead of being forced to change or go bankrupt. However, I didn't buy that the precedent prevents the government from deciding to take the next case (or the one after that) to trial to effectively reset the precedent if they wanted to. Basically, I thought that even though it may be physically harmful to our citizens for these environmental crime cases to get settled rather than shutting down the companies or forcing a change in their practices, I thought that this was due to a poor decision by the government to prosecute in this manner, rather than the plea bargaining practice itself being unjust.",
    instructions: "You are judging a varsity round with a flow-based, tabula rasa paradigm. Vote on the flow: dropped arguments are conceded, extensions must include warrants, and impacts must be weighed explicitly by the debaters themselves. Reward impact calculus, framework debate, and direct comparison of evidence and warrants. Do not intervene with your own opinions or fill in arguments a debater did not make. Penalize new arguments in final speeches and extensions without warrants. Decide the round on the clearest path to the ballot each side offered, and write a rigorous reason for decision that names the specific arguments that decided the round.",
  },
};

export const NSDA_TOPICS_URL = "https://www.speechanddebate.org/topics/";

export const TOPIC_CATEGORIES = [
  {
    name: "Lincoln-Douglas", icon: "versus", source: NSDA_TOPICS_URL,
    topics: [
      ["Resolved: Outer space colonization is a moral imperative.", "2026 September/October"],
      ["Resolved: De-extinction is unethical.", "2026 November/December"],
      ["Resolved: The United States ought to vest ecosystems with legal rights.", "2026 November/December"],
      ["Resolved: The use of artificial intelligence for offensive military operations is immoral.", "2027 January/February"],
      ["Resolved: The United States ought to substantially increase subsidies for renewable energy.", "2027 January/February"],
      ["Resolved: The United States ought to provide a universal basic income.", "2027 March/April"],
      ["Resolved: In a democracy, a candidate for public office’s right to privacy ought to be valued above the public’s right to know.", "2027 March/April"],
      ["Resolved: The intergenerational accumulation of wealth is unjust.", "2027 National Tournament"],
      ["Resolved: Justice requires the repatriation of cultural artifacts to their countries of origin.", "2027 National Tournament"],
      ["Resolved: In the United States, national service ought to be mandatory.", "Novice Topic (Ongoing)"],
    ].map(([text, period]) => ({ text, period })),
  },
  {
    name: "Public Forum", icon: "twoVtwo", source: NSDA_TOPICS_URL,
    topics: [
      ["Resolved: The United States federal government should enact a moratorium on hyperscale data center construction.", "2026 September/October"],
      ["Resolved: European members of the North Atlantic Treaty Organization should ratify the Treaty on the Prohibition of Nuclear Weapons.", "2026 November/December"],
      ["Resolved: The Republic of Korea should pursue an independent nuclear deterrent.", "2026 November/December"],
      ["Resolved: The United States federal government should classify gig workers as employees.", "2027 January"],
      ["Resolved: In the United States, the benefits of big box retailers outweigh the harms.", "2027 January"],
      ["Resolved: The benefits of the African Continental Free Trade Area outweigh the harms.", "2027 February"],
      ["Resolved: In Africa, peacekeeping missions led by the United Nations are preferable to those led by regional organizations.", "2027 February"],
      ["Resolved: In the United States, Congressional district boundaries should be drawn by independent redistricting commissions.", "2027 March"],
      ["Resolved: In the United States, voting should be compulsory in federal elections.", "2027 March"],
      ["Resolved: The Federative Republic of Brazil should prioritize its environmental protection over its economic development.", "2027 April"],
      ["Resolved: Latin American countries should prioritize Chinese investment over American investment.", "2027 April"],
    ].map(([text, period]) => ({ text, period })),
  },
];

export const FEATURED_RESOLUTION = {
  text: "The United States ought to require that workers receive a living wage.",
  label: "Lincoln-Douglas · September/October 2024",
};

export const SUGGESTED_RESOLUTIONS = [
  "Resolved: Outer space colonization is a moral imperative.",
  "Resolved: The United States federal government should enact a moratorium on hyperscale data center construction.",
  "Resolved: The United States federal government should establish national health insurance in the United States.",
  "Resolved: The United States ought to vest ecosystems with legal rights.",
  "Resolved: In a democracy, a candidate for public office’s right to privacy ought to be valued above the public’s right to know.",
];

const src = (title, url) => ({ title, url });

export const COMMITTEES = [
  {
    name: "Foreign Relations", chamber: "Senate",
    jurisdiction: "Treaties, foreign aid, arms sales, ambassadors, international organizations, and overall foreign policy.",
    agencies: ["Department of State", "USAID"],
    sources: [src("U.S. Department of State", "https://www.state.gov"), src("Congressional Research Service", "https://crsreports.congress.gov"), src("USAspending.gov — foreign aid", "https://www.usaspending.gov"), src("World Bank Open Data", "https://data.worldbank.org")],
    statSuggestions: ["How much U.S. foreign aid goes to the top five recipient countries?", "How many treaties has the Senate ratified in the last decade?", "What share of the federal budget is foreign assistance?", "How many UN peacekeeping missions are active right now?"],
    bills: ["A Bill to Condition Military Aid on Human Rights Benchmarks", "A Bill to Repeal Outdated Authorizations for the Use of Military Force"],
  },
  {
    name: "Environment and Public Works", chamber: "Senate",
    jurisdiction: "Environmental protection, air and water quality, highways and bridges, water infrastructure, and nuclear safety.",
    agencies: ["EPA", "Army Corps of Engineers", "Nuclear Regulatory Commission"],
    sources: [src("EPA — reports and data", "https://www.epa.gov"), src("EPA Greenhouse Gas Inventory", "https://www.epa.gov/ghgemissions"), src("USGS Water Data", "https://www.usgs.gov"), src("Congressional Budget Office", "https://www.cbo.gov")],
    statSuggestions: ["What are current U.S. greenhouse gas emissions by sector?", "How many U.S. bridges are rated in poor condition?", "How many communities still have lead service lines?", "What share of Americans breathe air that fails EPA standards?"],
    bills: ["A Bill to Set a National Standard for PFAS in Drinking Water", "A Bill to Fund Replacement of All Lead Service Lines"],
  },
  {
    name: "Judiciary", chamber: "House and Senate",
    jurisdiction: "Federal courts and judicial nominations, criminal law, immigration, civil rights and liberties, antitrust, and intellectual property.",
    agencies: ["Department of Justice", "FBI", "Federal judiciary", "USCIS"],
    sources: [src("Bureau of Justice Statistics", "https://bjs.ojp.gov"), src("FBI Crime Data Explorer", "https://cde.ucr.cjis.gov"), src("U.S. Sentencing Commission", "https://www.ussc.gov"), src("DHS Immigration Statistics", "https://www.dhs.gov/ohss")],
    statSuggestions: ["What share of federal criminal cases end in a plea bargain?", "How many people are held in federal prison right now?", "How large is the immigration court backlog?", "What is the federal incarceration rate by race?"],
    bills: ["A Bill to Eliminate Mandatory Minimum Sentences for Nonviolent Drug Offenses", "A Bill to Create a Pathway to Citizenship for Dreamers"],
  },
  {
    name: "Small Business and Entrepreneurship", chamber: "Senate",
    jurisdiction: "The Small Business Administration, small business lending and contracting, and regulatory burden on small firms.",
    agencies: ["Small Business Administration"],
    sources: [src("SBA Office of Advocacy", "https://advocacy.sba.gov"), src("Census Business Dynamics Statistics", "https://www.census.gov/programs-surveys/bds.html"), src("Federal Reserve Small Business Credit Survey", "https://www.fedsmallbusiness.org"), src("Bureau of Labor Statistics", "https://www.bls.gov")],
    statSuggestions: ["How many small businesses are there in the United States?", "What share of new small businesses survive five years?", "How much did SBA lend in its latest fiscal year?", "What share of private sector jobs are at small businesses?"],
    bills: ["A Bill to Expand SBA Microloans for First-Time Entrepreneurs", "A Bill to Simplify Federal Contracting for Small Businesses"],
  },
  {
    name: "Health, Education, Labor, and Pensions", chamber: "Senate",
    jurisdiction: "Public health, education, labor standards, workplace safety, and retirement plans.",
    agencies: ["HHS", "Department of Education", "Department of Labor", "FDA", "NIH", "CDC"],
    sources: [src("CDC National Center for Health Statistics", "https://www.cdc.gov/nchs"), src("National Center for Education Statistics", "https://nces.ed.gov"), src("Bureau of Labor Statistics", "https://www.bls.gov"), src("OSHA Data and Statistics", "https://www.osha.gov/data")],
    statSuggestions: ["What is U.S. life expectancy compared with peer countries?", "How much has college tuition risen in twenty years?", "How many workers lack paid sick leave?", "What is the current average price of insulin?"],
    bills: ["A Bill to Guarantee Paid Family and Medical Leave", "A Bill to Cap Insulin Prices Nationwide"],
  },
  {
    name: "Commerce, Science, and Transportation", chamber: "Senate",
    jurisdiction: "Interstate commerce, transportation, telecommunications, consumer protection, science, oceans, and aviation.",
    agencies: ["Department of Commerce", "Department of Transportation", "FCC", "FTC", "NASA", "NOAA"],
    sources: [src("Bureau of Transportation Statistics", "https://www.bts.gov"), src("FCC Reports and Research", "https://www.fcc.gov/reports-research"), src("NOAA Data", "https://www.noaa.gov"), src("FTC Reports", "https://www.ftc.gov/reports")],
    statSuggestions: ["How many satellites are currently in orbit?", "How many Americans still lack broadband access?", "How many traffic deaths were there last year?", "How many commercial space launches happened last year?"],
    bills: ["A Bill to Require Age Verification for Social Media Platforms", "A Bill to Set Federal Standards for Autonomous Vehicles"],
  },
  {
    name: "Homeland Security and Governmental Affairs", chamber: "Senate",
    jurisdiction: "The Department of Homeland Security, border security, cybersecurity, emergency management, government operations, and the federal workforce.",
    agencies: ["DHS", "CBP", "TSA", "FEMA", "CISA", "OPM"],
    sources: [src("DHS Office of Homeland Security Statistics", "https://www.dhs.gov/ohss"), src("CBP Newsroom Stats", "https://www.cbp.gov/newsroom/stats"), src("GAO High-Risk List", "https://www.gao.gov/high-risk-list"), src("OPM FedScope Workforce Data", "https://www.fedscope.opm.gov")],
    statSuggestions: ["How many border encounters were recorded last year?", "How many federal disaster declarations were issued last year?", "How many reported ransomware attacks hit U.S. infrastructure?", "How large is the federal civilian workforce?"],
    bills: ["A Bill to Reform Federal Disaster Aid Formulas", "A Bill to Require Cybersecurity Standards for Critical Infrastructure"],
  },
  {
    name: "Banking, Housing, and Urban Affairs", chamber: "Senate",
    jurisdiction: "Banks, financial markets, insurance, housing, mass transit, and export controls.",
    agencies: ["Federal Reserve", "Treasury", "SEC", "FDIC", "HUD", "CFPB"],
    sources: [src("Federal Reserve FRED", "https://fred.stlouisfed.org"), src("HUD User — housing data", "https://www.huduser.gov"), src("FDIC Data and Analysis", "https://www.fdic.gov/analysis"), src("Census Housing Data", "https://www.census.gov/topics/housing.html")],
    statSuggestions: ["How many people experienced homelessness on a given night?", "What is the median U.S. home price right now?", "What share of renters are cost burdened?", "How many bank branches have closed in the last decade?"],
    bills: ["A Bill to Create a National Rental Assistance Guarantee", "A Bill to Expand the Low-Income Housing Tax Credit"],
  },
  {
    name: "Armed Services", chamber: "House and Senate",
    jurisdiction: "The Department of Defense, military pay and readiness, weapons procurement, and the annual National Defense Authorization Act.",
    agencies: ["Department of Defense", "Army, Navy, Air Force, Marine Corps, Space Force"],
    sources: [src("DoD Comptroller — budget materials", "https://comptroller.defense.gov"), src("CBO — defense analyses", "https://www.cbo.gov/topics/defense-and-national-security"), src("GAO Weapon Systems Assessments", "https://www.gao.gov"), src("Congressional Research Service", "https://crsreports.congress.gov")],
    statSuggestions: ["How large is the current defense budget?", "How many U.S. troops are stationed overseas?", "What does the F-35 program cost per aircraft?", "How many service members are on food assistance?"],
    bills: ["A Bill to Raise Base Pay for Junior Enlisted Service Members", "A Bill to Require Congressional Approval for Overseas Troop Deployments Beyond 90 Days"],
  },
  {
    name: "Education and the Workforce", chamber: "House",
    jurisdiction: "K-12 and higher education, student loans, job training, labor standards, wages, and pensions.",
    agencies: ["Department of Education", "Department of Labor", "National Labor Relations Board"],
    sources: [src("National Center for Education Statistics", "https://nces.ed.gov"), src("Federal Student Aid Data Center", "https://studentaid.gov/data-center"), src("Bureau of Labor Statistics", "https://www.bls.gov"), src("Department of Labor", "https://www.dol.gov")],
    statSuggestions: ["How much total student loan debt is outstanding?", "What is the current federal minimum wage in real terms?", "What are U.S. reading and math scores on the NAEP?", "How many teachers left the profession last year?"],
    bills: ["A Bill to Raise the Federal Minimum Wage", "A Bill to Make Community College Tuition-Free"],
  },
  {
    name: "Energy and Commerce", chamber: "House",
    jurisdiction: "Health care, energy, environment, telecommunications, consumer protection, and interstate commerce.",
    agencies: ["HHS", "Department of Energy", "EPA", "FCC", "FTC", "FDA"],
    sources: [src("Energy Information Administration", "https://www.eia.gov"), src("CMS National Health Expenditure Data", "https://www.cms.gov"), src("CDC National Center for Health Statistics", "https://www.cdc.gov/nchs"), src("FCC Reports and Research", "https://www.fcc.gov/reports-research")],
    statSuggestions: ["What share of U.S. electricity comes from renewables?", "How much does the U.S. spend on health care per person?", "How many Americans are uninsured?", "How much has the average electricity bill risen?"],
    bills: ["A Bill to Allow Medicare to Negotiate All Prescription Drug Prices", "A Bill to Require a Federal Online Data Privacy Standard"],
  },
  {
    name: "Science, Space, and Technology", chamber: "House",
    jurisdiction: "Non-defense scientific research, NASA, NSF, NIST, NOAA research, energy research, and STEM education.",
    agencies: ["NASA", "National Science Foundation", "NIST", "NOAA", "DOE Office of Science"],
    sources: [src("NSF National Center for Science and Engineering Statistics", "https://ncses.nsf.gov"), src("NASA Budget and Reports", "https://www.nasa.gov/budgets-plans-and-reports"), src("NIST", "https://www.nist.gov"), src("NSF Budget and Performance", "https://www.nsf.gov/about/budget")],
    statSuggestions: ["How many satellites are in orbit right now?", "What share of U.S. adults use AI tools?", "How much does the U.S. spend on federal R&D?", "How many STEM degrees are awarded each year?"],
    bills: ["A Bill to Double Federal Basic Research Funding Over Five Years", "A Bill to Establish a National Artificial Intelligence Safety Institute"],
  },
  {
    name: "Oversight and Reform", chamber: "House",
    jurisdiction: "Government-wide oversight, the federal workforce, the Postal Service, the census, and the District of Columbia.",
    agencies: ["OPM", "GSA", "U.S. Postal Service", "Census Bureau"],
    sources: [src("GAO High-Risk List", "https://www.gao.gov/high-risk-list"), src("OPM FedScope Workforce Data", "https://www.fedscope.opm.gov"), src("Oversight.gov — Inspector General reports", "https://www.oversight.gov"), src("USPS Financial Reports", "https://about.usps.com/what/financials")],
    statSuggestions: ["How much does the federal government lose to improper payments each year?", "How large is the Postal Service deficit?", "How many federal employees work remotely?", "What did the last census cost per household?"],
    bills: ["A Bill to Make Washington, D.C. the Fifty-First State", "A Bill to Reform the Federal Hiring Process"],
  },
  {
    name: "Transportation and Infrastructure", chamber: "House",
    jurisdiction: "Highways, transit, aviation, rail, ports and waterways, pipelines, the Coast Guard, and public buildings.",
    agencies: ["Department of Transportation", "FAA", "Federal Highway Administration", "Amtrak", "Army Corps of Engineers"],
    sources: [src("Bureau of Transportation Statistics", "https://www.bts.gov"), src("FHWA Highway Statistics", "https://www.fhwa.dot.gov/policyinformation/statistics.cfm"), src("NHTSA Data", "https://www.nhtsa.gov/data"), src("ASCE Infrastructure Report Card", "https://infrastructurereportcard.org")],
    statSuggestions: ["How many U.S. bridges are structurally deficient?", "How many people ride Amtrak each year?", "What share of flights arrive on time?", "How much of the Highway Trust Fund comes from the gas tax?"],
    bills: ["A Bill to Fund High-Speed Rail Corridors", "A Bill to Raise the Federal Gas Tax and Index It to Inflation"],
  },
  {
    name: "Natural Resources", chamber: "House",
    jurisdiction: "Public lands, national parks, water and power, fisheries and wildlife, mining, tribal affairs, and U.S. territories.",
    agencies: ["Department of the Interior", "Bureau of Land Management", "National Park Service", "Bureau of Indian Affairs"],
    sources: [src("USGS Mineral Commodity Summaries", "https://www.usgs.gov/centers/national-minerals-information-center"), src("National Park Service Visitation Statistics", "https://irma.nps.gov/Stats"), src("Department of the Interior", "https://www.doi.gov"), src("Congressional Research Service", "https://crsreports.congress.gov")],
    statSuggestions: ["How much land does the federal government own?", "How many people visited national parks last year?", "How much lithium does the U.S. produce?", "How many acres burned in wildfires last year?"],
    bills: ["A Bill to Ban New Oil and Gas Leasing on Federal Lands", "A Bill to Grant Statehood to Puerto Rico"],
  },
  {
    name: "Ethics", chamber: "House and Senate",
    jurisdiction: "Standards of conduct for members and staff, financial disclosure, gifts, travel, and misconduct investigations.",
    agencies: ["House Committee on Ethics", "Senate Select Committee on Ethics"],
    sources: [src("House Committee on Ethics", "https://ethics.house.gov"), src("Senate Select Committee on Ethics", "https://www.ethics.senate.gov"), src("House Financial Disclosure Reports", "https://disclosures-clerk.house.gov"), src("Senate Financial Disclosure", "https://efdsearch.senate.gov")],
    statSuggestions: ["How many members of Congress trade individual stocks?", "How many ethics investigations opened last year?", "How much privately funded travel do members take?", "What share of members are millionaires?"],
    bills: ["A Bill to Ban Individual Stock Trading by Members of Congress", "A Bill to Require Public Disclosure of All Privately Funded Congressional Travel"],
  },
].map((c) => ({ ...c, fullName: `Committee on ${c.name}`, slug: c.name.toLowerCase().replace(/[^a-z]+/g, "-").replace(/^-|-$/g, "") }));

export const committeeByFullName = (fullName) => COMMITTEES.find((c) => c.fullName === fullName);

export function segment(title, stance, seconds) {
  const minutes = Math.floor(seconds / 60);
  const rest = seconds % 60;
  return {
    title, stance, seconds,
    wordBudget: Math.max(120, Math.floor((seconds * 150) / 60)),
    clock: `${minutes}:${String(rest).padStart(2, "0")}`,
  };
}

export const CONGRESS_SCRIPT = [
  segment("Authorship speech", "Pro", 120),
  segment("Constructive", "Con", 240),
  segment("Second speech", "Pro", 120),
  segment("Closing", "Con", 120),
];

export const FLOOR_SPEECH = segment("Floor speech", "Pro", 120);

export const congressSegment = (n) => (n < CONGRESS_SCRIPT.length ? CONGRESS_SCRIPT[n] : null);
export const congressIsOpenFloor = (n) => n >= CONGRESS_SCRIPT.length;

const TEAM_SCRIPT = [
  { slot: 0, kind: "speech" },
  { slot: "ai", kind: "speech" },
  { slot: "ai", kind: "crossfireQuestion" },
  { slot: 0, kind: "crossfireAnswer" },
  { slot: 1, kind: "crossfireAnswer" },
  { slot: 0, kind: "crossfireAnswer" },
  { slot: 1, kind: "speech" },
];

export function teamStep(n) {
  if (n < TEAM_SCRIPT.length) return TEAM_SCRIPT[n];
  const k = n - TEAM_SCRIPT.length;
  return k % 2 === 0 ? { slot: "ai", kind: "speech" } : { slot: Math.floor(k / 2) % 2, kind: "speech" };
}

export function sectionTitles(kind) {
  return kind === "congress"
    ? ["Strongest argument", "Weakest argument", "Missed opportunity in refutation or questioning", "Concrete suggestion for next time"]
    : ["Strongest argument", "Weakest argument", "Missed rebuttal opportunity", "Concrete suggestion for next time"];
}

export const effectiveKind = (message) => message.kind || "speech";

export function questionsIn(text) {
  const lines = String(text).split(/\r?\n/).map((l) => l.trim()).filter(Boolean);
  const numbered = lines
    .map((line) => {
      const m = line.match(/^\s*(\d+[.)]|[-•*])\s*/);
      if (!m) return null;
      const body = line.slice(m[0].length).trim();
      return body || null;
    })
    .filter(Boolean);
  const candidates = numbered.length ? numbered : lines.filter((l) => l.includes("?"));
  return candidates.slice(0, 3);
}

export function namesOn(config, side) {
  const list = (config.participants || []).filter((p) => p.side === side).map((p) => p.name);
  return list.length ? list.join(" & ") : side;
}
