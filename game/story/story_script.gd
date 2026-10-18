class_name StoryScript
extends RefCounted
## "The Ghost Line", beat by beat, in play order (docs/story/GHOST_LINE_STORYBOARD.md). Each beat
## is one storyboard scene (or a piece of one) on a stage: "pass" (Pass 1), "hub" (the barangay),
## "room" (a small set: StoryRoom.SETS) or "panel" (a paper page: act cards, the group chat,
## memories). StoryDirector plays them.
##
## Beat types:
##   chapter   act card                         act, title, subtitle
##   talk      dialogue                         place, when, lines; night, rain, wet, spot / at / set;
##                                              cabin (from the parked car's seat), glass (drops on it)
##   goto      drive to a hub place             place (HubLayout.PLACES key), prompt
##   race      VS race (finishing order)        course ("pass" | "loop"), field, require_win, trauma
##   practice  A Line Study: recorded passes    passes [{ label, wet, night, note }]
##   attack    run against the Ghost Line       label_clue, night, rain, wet
##   sectors   flying sectors vs the ghost      trials [{ sector, label, wet, night }], notes, connect
##   crash     the last night run               cold_open
##   daylight  the ending drive, no clock
##   evidence  investigation                    cards, question, options, answer, pick, wrong, after
##   end       credits, back to the title
##
## Any beat may carry "comic" (pages before it) and "comic_after" (pages after it): manga pages
## between scenes, a panel per press (StoryComic: art, who, say, cap, fx, side, sfx).
##
## The story is told from after the crash; the months before are memories. The first beat of a
## memory carries "memory": its period label, shown as a stamp until the first beat back in the
## present, which carries "now": the present-day sound the cut lands on. memory_of() walks it.
##
## Lines are [speaker, text]; speaker "" is narration. Specials: ["~sfx", name], ["~cut", ""]
## (a hard black cut), ["~place", caption] (the caption changes mid-scene), ["~wait", seconds],
## ["~set", name] (cut to another room on the room stage).
## Text may use {tokens} filled from the player's own record (StoryDirector.tokens()).
## Field drivers: [name, CarRoster id, paint hex, AI skill].

const NICO := ["NICO", "dalagan_gsr", "e9e7df", 0.97]

const BEATS := [
	# ===================================================================== PROLOGUE
	{ "id": "p_card", "scene": "S00", "stage": "panel", "type": "chapter",
		"act": "PROLOGUE", "title": "THE MISSING SECONDS", "subtitle": "Rain, a corner, and a set of lights." },
	{ "id": "s00", "scene": "S00", "stage": "pass", "type": "crash", "cold_open": true,
		"comic": [
			[
				{ "art": "rain", "cap": "Here's what I know. It was raining like someone was throwing gravel at the glass." },
				{ "art": "wipers", "fx": "SHHK", "sfx": "wiper", "cap": "The wipers were losing." },
				{ "art": "face", "who": "JOLO", "side": "right", "cap": "Jolo had his phone up. Jolo always had his phone up." },
			],
			[
				{ "art": "road", "cap": "The corner. I knew it by the trees, and the white post on the outside." },
				{ "art": "face", "who": "PANG", "side": "right", "cap": "Ghost's line. I could see it." },
			],
		],
		"comic_after": [
			[
				{ "art": "black", "cap": "There's no sound for the hit. I've tried to find one." },
				{ "art": "lights", "cap": "Headlights. Rain going white. Jolo saying something like \"drive the road.\"" },
				{ "art": "black", "cap": "In my head the lights always get to the corner. Then nothing." },
			],
		] },

	# ===================================================================== ACT I  ·  THE RETURN (present) / MEMORY 1 / present
	{ "id": "a1_card", "scene": "S14", "stage": "panel", "type": "chapter",
		"act": "ACT I", "title": "THE RETURN", "subtitle": "A name nobody can place." },
	{ "id": "s14", "scene": "S14", "stage": "room", "type": "talk", "set": "clinic", "place": "THE CLINIC", "when": "AFTER THE CRASH",
		"comic": [[
			{ "art": "white", "cap": "The clinic. I learned the ceiling. The window did weather and nothing else." },
			{ "art": "tone", "cap": "Twenty-three days. Nobody said Jolo's name in there, so it was in there all the time." },
		]],
		"lines": [
		["", "The scar goes from my collar to my shoulder. It itches before rain."],
		["~set", "rented_room"],
		["~place", "A RENTED ROOM  ·  MONTHS LATER"],
		["", "Months later I still wake up for the wipers. There are no wipers in here."],
		["~sfx", "wiper"],
		["", "Bills. Kuya Ben, about his lens, very politely. Nobody else."],
		["", "Official report: SINGLE-VEHICLE ACCIDENT. NO SECOND VEHICLE CONFIRMED."],
		["PANG", "There was a car. There were lights. Beside us."],
		["", "Here's what I know. There were two cars at that corner, and one of them drove away."],
		["~sfx", "phone_buzz"],
		["RUEL", "Car's here. So's the camera card. So's the logger. Come when you come."],
	] },
	{ "id": "s15", "scene": "S15", "stage": "hub", "type": "evidence", "spot": "talyer", "place": "RUEL'S TALYER", "when": "AFTER THE CRASH",
		"comic": [[
			{ "art": "tone", "cap": "Ruel's talyer, the first time back. The car under a tarp. On the bench, in a sandwich bag: Jolo's cracked phone card and the logger." },
		]],
		"before": [
			["PANG", "Did they find the other driver?"],
			["RUEL", "Report says no second car."],
			["PANG", "They weren't there."],
			["RUEL", "No. Neither was I."],
			["RUEL", "A man buying cigarettes saw lights on the lower road. Nobody puts them near you."],
		],
		"cards": [
			{ "kind": "text", "title": "CAMERA CARD (DAMAGED)", "body": "Jolo's phone card, cracked at the contacts.\nRecovered: footage up to {crash_cut} into the run.\nThe last seconds before impact: unreadable." },
			{ "kind": "text", "title": "DATA LOGGER", "body": "The small logger Jolo wired under the dash.\nSpeed · brake · steering · 20 Hz.\nIntact. Nobody has read it yet." },
		],
		"after": [
			["PANG", "I want to know who was beside us."],
			["RUEL", "Twenty hertz. The boy wanted fifty. I said twenty."],
		] },
	{ "id": "s01", "scene": "S01", "stage": "hub", "type": "talk", "spot": "talyer",
		"place": "RUEL'S TALYER", "when": "LATE AFTERNOON", "memory": "MONTHS BEFORE",
		"comic": [[
			{ "art": "black", "fx": "KLANK!", "sfx": "wrench", "cap": "The wrench hit the concrete. Flat, bright. Ruel picked it up like it hadn't happened." },
			{ "art": "face", "who": "PANG", "side": "right", "cap": "I'd heard that before. Same crack, same floor, same car with its hood up." },
			{ "art": "tone", "cap": "MONTHS BEFORE. Oil and hot dust. Jolo on his upside-down pail, eating pan de sal." },
		]],
		"lines": [
		["JOLO", "You're staring at it again."],
		["PANG", "Thinking."],
		["JOLO", "Twenty minutes, boss. Hood's still up."],
		["RUEL", "When the philosophers are done. Ten-millimeter."],
		["RUEL", "Fronts are near the end. And I don't like the pedal."],
		["PANG", "They're not done."],
		["RUEL", "They are not finished becoming dangerous. Different thing."],
		["JOLO", "Tires next week. Sooner if tonight goes good."],
		["RUEL", "What's tonight."],
		["JOLO", "Small meet. Private. Prize covers the parts."],
		["RUEL", "Some of the parts."],
		["JOLO", "\"Some\" is how \"more\" begins."],
		["RUEL", "That is also how debt begins."],
		["RUEL", "Go. Me not stopping you is not me saying yes."],
		["JOLO", "That's almost a blessing."],
		["RUEL", "It's an invoice."],
	],
		"comic_after": [[
			{ "art": "snap", "fx": "KSHK", "sfx": "shutter", "cap": "Jolo took a picture of the three of us anyway. Ruel's frowning in it. Ruel's frowning in all of them." },
		]] },
	{ "id": "s02", "scene": "S02", "stage": "hub", "type": "goto", "place": "gas", "night": true,
		"prompt": "THE MEET  ·  BAHANDI FUELS",
		"comic": [[
			{ "art": "snap", "cap": "THAT NIGHT" },
			{ "art": "face", "who": "JOLO", "side": "left", "say": "Entry's paid. Five hundred. Don't make me explain that to my mother." },
			{ "art": "face", "who": "JOLO", "side": "left", "say": "Bahandi Fuels, then the loop behind the warehouses. My cousin knows a guy." },
		]] },
	{ "id": "s03", "scene": "S03", "stage": "hub", "type": "race", "course": "loop", "night": true,
		"title": "NOTHING TO LOSE", "require_win": true,
		"field": [["KAPITAN", "silak_box", "1f4dbf", 0.84], ["TISOY", "eg_hatch", "17171a", 0.85], ["RJ", "civic_fd", "8c8f94", 0.83]],
		"comic": [[
			{ "art": "snap", "cap": "Nobody called it a race. They called it a meet, like the word would make the cars behave." },
			{ "art": "face", "who": "RUEL", "side": "left", "cap": "A text from Ruel.", "say": "Bring it home in one piece.", "sfx": "phone_buzz" },
			{ "art": "face", "who": "JOLO", "side": "right", "say": "Define home." },
		]],
		"lose": [["JOLO", "Again. Entry's paid. They'll let you run it back if I ask nice."]],
		"after": [
			["JOLO", "You saw that? You see what you did?"],
			["PANG", "I drove."],
			["JOLO", "You made that car look like it owes you money."],
			["DANTE", "You found time where there wasn't supposed to be any."],
			["DANTE", "Come by Kyo, my friend. Meet some people. Coffee's on me."],
		] },
	{ "id": "s04t", "scene": "S04", "stage": "hub", "type": "talk", "spot": "kyo", "night": true,
		"place": "KYO COFFEE", "when": "PAST MIDNIGHT", "lines": [
		["", "Dante's thing wasn't speed. He made you feel the next room had saved you a seat."],
		["DANTE", "Look— people want to watch you. Small car. No budget. You."],
		["PANG", "I just drive."],
		["", "A clean, expensive car rolls onto the apron. Nico gets out and looks at our tires before he looks at me."],
		["NICO", "What are those, two seasons old?"],
		["PANG", "Three."],
		["NICO", "You drove well."],
		["PANG", "But."],
		["NICO", "But you found time you won't find twice. Not on those."],
		["DANTE", "Pang. Nico. Pass 1, Saturday, before the light goes. Settle it there."],
	],
		"comic_after": [[
			{ "art": "face", "who": "NICO", "side": "left", "say": "Saturday, then." },
			{ "art": "face", "who": "PANG", "side": "right", "say": "Saturday." },
			{ "art": "speed", "fx": "VRRMM" },
		]] },
	{ "id": "s05", "scene": "S05", "stage": "pass", "type": "race", "course": "pass", "title": "NICO'S LESSON",
		"field": [NICO], "night_value": 0.2,
		"comic": [[
			{ "art": "road", "cap": "PASS 1 · SATURDAY · BEFORE THE LIGHT GOES" },
			{ "art": "face", "who": "NICO", "side": "right", "say": "One run. Clean. Then we talk." },
		]],
		"win": [
			["NICO", "You took it. Do it again tomorrow on the same tires and I'll believe it."],
			["PANG", "You drive like there's a spreadsheet open in your head."],
			["NICO", "There is. Yours has one row."],
		],
		"lose": [
			["NICO", "You're quick. You take every corner like it's personal."],
			["PANG", "You drive like there's a spreadsheet open in your head."],
			["NICO", "There is. Yours has one row."],
			["PANG", "Must be nice. Ten sets of tires."],
			["NICO", "It is. Tires aren't why you overcorrected at the last bend."],
		],
		"after": [
			["JOLO", "Good race. Really good race. Footage, contacts, all four tires."],
			["JOLO", "Don't tell Ruel about the tires."],
		] },
	{ "id": "s16", "scene": "S16", "stage": "hub", "type": "race", "course": "loop", "title": "THE FIRST RETURN", "trauma": true, "now": "wrench",
		"night_value": 0.0,
		"field": [["KAPITAN", "silak_box", "1f4dbf", 0.86], ["BUKO", "dalagan_gsr", "1a6b3d", 0.86], ["RJ", "civic_fd", "8c8f94", 0.84]],
		"before": [["", "Short route. Faces I know. Dry. I told myself that was controlled."]],
		"after": [
			["", "RJ laughed, kindly. That was worse."],
			["RJ", "You'll get it back, bro."],
			["PANG", "Car's rusty. I'm rusty."],
			["RUEL", "The car did what you asked."],
			["RJ", "Bro. Somebody said there was another car up there that night. Beside you. Ask at Kyo."],
		] },
	{ "id": "s17", "scene": "S17", "stage": "hub", "type": "goto", "place": "kyo", "night": true, "prompt": "KYO COFFEE  ·  ASK AROUND" },
	{ "id": "s17e", "scene": "S17", "stage": "hub", "type": "evidence", "spot": "kyo", "night": true, "place": "KYO COFFEE", "when": "AFTER THE CRASH",
		"before": [
			["KAPITAN", "Ghost? Ex-pro. My cousin says Japan. Came home, left again. That clip's years old."],
			["ATE LIZA", "Years? That's the sign at 8A. They bent it last rainy season. Months."],
			["BUKO", "Ghost was up there the night you crashed. Guarding the time. Dark car, no plates."],
			["KAPITAN", "Says who."],
			["BUKO", "Everybody."],
		],
		"cards": [
			{ "kind": "text", "title": "KAPITAN'S GHOST", "body": "A former pro.\nThe clip is \"years old\".\nNever on Pass 1 since." },
			{ "kind": "text", "title": "ATE LIZA'S GHOST", "body": "Filmed months before the crash.\nShe dates it by the bent sign at 8A.\nDoesn't know who." },
			{ "kind": "text", "title": "BUKO'S GHOST", "body": "On the mountain the night of the crash.\n\"Dark car, no plates.\"\nHeard it from \"everybody\"." },
		],
		"question": "Three people, three Ghosts. What do their stories establish?",
		"options": [
			"Ghost is a former professional who left the country",
			"Ghost was on the mountain the night of the crash",
			"Nothing yet: each story has a detail that cannot fit the others",
			"The clip is years old",
		],
		"answer": [2],
		"wrong": ["RUEL", "That's one version. Put it next to the other two."],
		"after": [
			["NICO", "You kept checking your mirror. On an empty lane."],
			["NICO", "I've chased the Ghost Line more times than I'll admit."],
			["NICO", "The line's good. Some sections are excellent. The total doesn't behave like one run."],
			["NICO", "Drive it with me. Sector by sector. Then tell me it's one run."],
		] },
	{ "id": "s06", "scene": "S06", "stage": "pass", "type": "practice", "title": "A LINE STUDY", "memory": "THE LINE STUDY",
		"comic": [[
			{ "art": "black", "cap": "Buko's phone, face up at Kyo. The clip again. Rain on the lens." },
			{ "art": "tone", "cap": "I looked at the rain until something older came up. A dry Tuesday, months before. THE LINE STUDY." },
			{ "art": "face", "who": "JOLO", "side": "left", "say": "Three passes. I'm rolling the whole time." },
			{ "art": "face", "who": "PANG", "side": "right", "say": "You're always rolling." },
		]],
		"passes": [
			{ "label": "PASS A  ·  TUESDAY 3:40 PM  ·  DRY", "wet": 0.0, "night": 0.0, "sign": "intact",
				"note": ["JOLO", "You're doing the thing. Your mouth goes small. Drive the road, boss. It's right there."] },
			{ "label": "PASS B  ·  THURSDAY 4:15 PM  ·  DAMP PATCHES AFTER A SHOWER", "sheen": 0.45, "night": 0.1,
				"note": ["JOLO", "Inside's still wet from the shower. You feel that?"] },
			{ "label": "PASS C  ·  SATURDAY 5:30 PM  ·  DRY  ·  LOW SUN", "wet": 0.0, "night": 0.3,
				"note": ["JOLO", "There. That's the one."] },
		],
		"comic_after": [
			[
				{ "art": "snap", "cap": "The light went." },
				{ "art": "face", "who": "PANG", "side": "left", "say": "Which one?" },
				{ "art": "face", "who": "JOLO", "side": "right", "say": "The one we'll pretend you meant to do." },
			],
			[
				{ "art": "face", "who": "PANG", "side": "left", "say": "My mouth doesn't go small." },
				{ "art": "face", "who": "JOLO", "side": "right", "say": "I have eleven hours of your mouth going small." },
				{ "art": "face", "who": "PANG", "side": "left", "say": "One more time." },
				{ "art": "face", "who": "JOLO", "side": "right", "say": "You said that three times ago. Light's gone, boss." },
			],
		] },
	{ "id": "s20", "scene": "S20", "stage": "hub", "type": "talk", "spot": "kyo", "night": true, "place": "KYO COFFEE", "when": "DANTE'S TABLE", "now": "phone_buzz", "lines": [
		["PANG", "Who's Ghost?"],
		["DANTE", "If I knew, I'd sell tickets to him. Coffee?"],
		["PANG", "You posted it. You put a time on it. You don't know who drove."],
		["DANTE", "Somebody sends it, I post it. That's the job. Did anybody want me asking?"],
		["PANG", "Did you have a car out there that night? Lower road. Keeping the time safe."],
		["DANTE", "No. I never said a car pushed you. I never sent anyone near you."],
		["DANTE", "Look— you want me to say I made the crash. I made a race. You drove, my friend."],
		["PANG", "You let the rumours run."],
		["DANTE", "Which one should I have stopped? There were twelve."],
		["PANG", "The ones that cost you money."],
		["PANG", "Give me the original file."],
		["DANTE", "There's no original. There's what got posted."],
		["RUEL", "The boy's laptop died before the crash. I backed up his camera folder. It's in a drawer somewhere."],
	] },
	# ===================================================================== ACT II  ·  THE GHOST / MEMORY 3
	{ "id": "a2_card", "scene": "S18", "stage": "panel", "type": "chapter",
		"act": "ACT II", "title": "THE GHOST", "subtitle": "A line nobody can finish, and the one who posted it." },
	{ "id": "s18", "scene": "S18", "stage": "pass", "type": "sectors", "title": "NICO REPEATS THE TEST",
		"comic": [[
			{ "art": "road", "cap": "Pass 1, a weekday morning. Nico's GSR at the top, a notebook on the roof. No crowd. No board." },
		]],
		"before": [["NICO", "Ghost's on every sector. Match him. Then we look at the joins."]],
		"trials": [
			{ "sector": 0, "label": "SECTOR 1", "wet": 0.0, "night": 0.0 },
			{ "sector": 1, "label": "SECTOR 2", "wet": 0.0, "night": 0.0, "note": ["NICO", "You came in with sector one's speed. Ghost didn't. Ghost came in from somewhere else."] },
			{ "sector": 2, "label": "SECTOR 3", "wet": 0.0, "night": 0.0 },
		],
		"after_cards": [{ "kind": "notes", "title": "NICO'S NOTES" }],
		"after": [
			["NICO", "Look at the clock under the video."],
			["PANG", "It's a clock."],
			["NICO", "It resets where the picture doesn't cut. One pass doesn't do that."],
			["PANG", "Could someone have driven it once?"],
			["NICO", "I can't prove they didn't. I need the original. Everything going around is cropped and re-encoded."],
			["PANG", "Why are you helping me?"],
			["NICO", "I don't like losing to something that doesn't exist."],
			["NICO", "And you don't remember that night. You think you do."],
		] },
	{ "id": "s19", "scene": "S19", "stage": "panel", "type": "talk", "place": "RUEL'S TALYER", "when": "TUESDAY · RAIN", "lines": [
		["~sfx", "wrench"],
		["JOLO", "That's not what I meant."],
		["PANG", "Then say what you meant."],
		["~place", "RUEL'S TALYER · SATURDAY · DRY"],
		["JOLO", "I meant we fix the car first. New wheel's on, at least."],
		["~place", "KYO COFFEE · THE SAME NIGHT?"],
		["DANTE", "Nobody cares about the notes."],
		["~place", "RUEL'S TALYER · A WEEK LATER · THE OLD WHEEL"],
		["JOLO", "Same shirt, Pang. I wore it twice. You keep putting me in it."],
		["", "I started writing things down. Dates. Shirts. Which wheel."],
		["~cut", ""],
		["~sfx", "phone_buzz"],
	] },
	{ "id": "s07", "scene": "S07", "stage": "panel", "type": "talk", "style": "phone", "memory": "GHOST GOES PUBLIC",
		"comic": [[
			{ "art": "black", "cap": "Jolo's camera bag, under the bench where he left it. The strap still set to his shoulder." },
			{ "art": "tone", "cap": "THE WEEK GHOST WENT PUBLIC." },
		]],
		"place": "PASS 1 RUNNERS (PRIVATE GROUP)", "when": "THE NEXT AFTERNOON", "lines": [
		["DANTE", "Reference pace from an anonymous driver. Nobody on this island has matched it. GHOST TIME {ghost_time}."],
		["BUKO", "so who's ghost"],
		["KAPITAN", "ex pro. my cousin says japan"],
		["ATE LIZA", "Whoever he is, he lifts before 8A. Nobody lifts before 8A."],
		["~place", "KYO COFFEE · LATER"],
		["JOLO", "Dante took something off it."],
		["PANG", "Off what? It looks good."],
		["JOLO", "Yeah. It looks really good."],
		["", "He watched it twice more and didn't say what."],
		["PANG", "People are into it. Somebody out there can drive."],
		["~sfx", "phone_buzz"],
		["DANTE", "The scene needs a benchmark. Nobody follows a clip called \"study\". They follow a driver nobody can catch."],
		["", "Jolo read it, turned the phone face down, and asked if I wanted more rice."],
	] },
	{ "id": "s08", "scene": "S08", "stage": "pass", "type": "attack", "title": "CHASE THE COMPOSITE", "grip": 0.95,
		"comic": [[
			{ "art": "road", "cap": "I'd watched it so often the line was on the road before the road was." },
			{ "art": "face", "who": "RUEL", "side": "right", "say": "Fronts are near the end. Don't come back and tell me the car changed." },
		]],
		"beaten": [
			["JOLO", "You— beat it."],
			["PANG", "Once. In the dry. The middle felt like a different road."],
			["JOLO", "Boss, about the clip—"],
			["PANG", "Every time. I'll beat it every time."],
			["JOLO", "...Okay."],
		],
		"after": [
			["JOLO", "It's a clip, boss. You don't have to make it nervous."],
			["PANG", "It has a time."],
			["JOLO", "About the clip. There's something I—"],
			["PANG", "I'm close. The middle's close. Tell me after."],
			["JOLO", "...After."],
		] },
	{ "id": "s09", "scene": "S09", "stage": "pass", "type": "attack", "title": "THE COMBINED-SECTOR CHALLENGE",
		"label_clue": true, "posted": true, "night_value": 0.55, "grip": 0.95,
		"comic": [
			[
				{ "art": "tone", "cap": "THE NEXT SATURDAY · A CROWD AT THE TOP OF PASS 1" },
				{ "art": "face", "who": "DANTE", "side": "right", "say": "Ghost Time is on the board. Beat the sectors, beat the legend. Next driver!" },
			],
			[
				{ "art": "face", "who": "TISOY", "side": "left", "say": "Sequential box. Has to be. Nobody shifts that clean." },
				{ "art": "face", "who": "BUKO", "side": "right", "say": "It's a hatch. Listen to it. That's a hatch." },
				{ "art": "face", "who": "TISOY", "side": "left", "say": "Hatches don't sound like that." },
				{ "art": "face", "who": "BUKO", "side": "right", "say": "You've only heard yours." },
			],
			[
				{ "art": "face", "who": "ATE LIZA", "side": "left", "say": "He's got you there." },
				{ "art": "face", "who": "KAPITAN", "side": "right", "say": "My cousin says it's a Japanese guy. Flew in, one run, flew home." },
				{ "art": "face", "who": "BUKO", "side": "left", "say": "Your cousin said the moon landing was fake." },
				{ "art": "face", "who": "KAPITAN", "side": "right", "say": "He said it was filmed in Manila. That's different." },
			],
		],
		"after_cards": [{ "kind": "board", "title": "GHOST LINE CHALLENGE · SECTOR BOARD" }],
		"beaten": [
			["DANTE", "Unofficial, my friend. Nobody timing it but your own cameraman. Ghost Time stands."],
			["PANG", "Everybody up here watched me beat it."],
			["~sfx", "phone_buzz"],
			["NICO", "Look at the board."],
			["", "A new number under GHOST TIME. Three tenths under mine. Caption: Ghost responded."],
			["PANG", "Nobody was on the mountain. Nobody passed me."],
			["DANTE", "Then you'll want the bigger night. Bigger prize. Beat it when it counts."],
			["NICO", "That number went up a minute ago. Nobody was on the road a minute ago."],
		],
		"ahead": [
			["PANG", "I was ahead of it. At the bottom I was ahead."],
			["NICO", "You were. The board says you weren't."],
			["DANTE", "The board is the time. The car in the clip is a car in a clip."],
			["NICO", "Sector one wants one entry. The middle was a different surface. I can drive every piece. They don't add up."],
		],
		"after": [
			["NICO", "Sector one wants one entry. The middle was recorded on a different surface. The exit's from a pass with a different rhythm."],
			["NICO", "I can drive every piece. They don't add up."],
			["PANG", "Then make them add up."],
			["NICO", "What do you think I've been doing."],
		] },
	{ "id": "s10", "scene": "S10", "stage": "hub", "type": "talk", "spot": "home", "cabin": true, "glass": 0.35,
		"place": "THE CAR, PARKED", "when": "AFTER MIDNIGHT", "night": true,
		"comic": [[
			{ "art": "rain", "cap": "AFTER MIDNIGHT · THE CAR, PARKED OUTSIDE MY PLACE" },
			{ "art": "face", "who": "JOLO", "side": "right", "cap": "Jolo in the passenger seat, phone open. Notes on the screen." },
		]],
		"lines": [
		["JOLO", "There is something about the clip I should've—"],
		["PANG", "I know. I know it's hard. If I get the middle clean, the rest follows."],
		["~wait", 1.4],
		["JOLO", "You remember the batchoy place in La Paz? By the school?"],
		["PANG", "It closed."],
		["JOLO", "It didn't close. I just never went back. I knew it wouldn't taste like that again, so I kept it how it was."],
		["PANG", "You're tired."],
		["", "He looked at something on his phone for a long time. Then he locked it."],
		["JOLO", "Fronts are done, by the way. And it's raining Friday. Ruel's right. I hate when Ruel's right."],
		["PANG", "I almost had the middle tonight."],
		["JOLO", "I know."],
		["", "He was tired. I remember that."],
	] },
	{ "id": "s21", "scene": "S21", "stage": "hub", "type": "evidence", "spot": "talyer", "place": "RUEL'S TALYER", "when": "THE COMPUTER BENCH", "now": "phone_buzz",
		"before": [["RUEL", "Half these files are damaged. Don't get excited."]],
		"cards": [
			{ "kind": "text", "title": "BACKUP DRIVE · FOLDERS", "body": "/lift_day/  (car on the lift)\n/audio_test/\n/rattle_lol/\n/nico_race_unfinished/\n/GHOST_LINE/  v1 · v2 · v3_FINAL\n/raw_tuesday/ /raw_thursday/ /raw_saturday/" },
			{ "kind": "text", "title": "GHOST_LINE / v1", "body": "Earliest edit. Title card still on.\nJolo talking about the camera mount.\nPassenger-side angle, low on the glass." },
			{ "kind": "text", "title": "RAW CLIPS", "body": "Metadata partial; two files re-encoded.\nSame passenger-side angle.\nA dashboard reflection in the windshield.\nBefore the 8A bend: a small lift, a quick correction, the car settles." },
		],
		"question": "Which detail ties the clip to a car you know, more than a filename could?",
		"options": [
			"The folder is named GHOST_LINE",
			"The dashboard reflection and the small correction before 8A",
			"The dates in the raw folder names",
			"Comments in the racing group",
		],
		"answer": [1],
		"wrong": ["RUEL", "Anyone can name a folder. Look at the picture."],
		"after": [["RUEL", "Watch the driver's hands."]] },
	{ "id": "s22", "scene": "S22", "stage": "hub", "type": "evidence", "spot": "talyer", "place": "RUEL'S TALYER", "when": "TWO CLIPS, SYNCED",
		"cards": [{ "kind": "match", "title": "GHOST LINE vs RAW CLIP · STEERING" }],
		"question": "Ghost's steering trace sits exactly on top of the raw clip. Whose hands are on the wheel?",
		"options": [
			"Someone else who drives the same model",
			"Mine. The clip was filmed from my passenger seat. Jolo was recording.",
			"Nico, from his notes",
			"Can't tell from a steering trace",
		],
		"answer": [1],
		"wrong": ["RUEL", "Same lift, same correction, same reflection, same engine note. Look again."],
		"after": [
			["JOLO", "(on the clip) Mount's loose, hold on— okay, okay, rolling."],
			["PANG", "(on the clip) That bend again. One more. Let me try it one more time."],
			["JOLO", "(on the clip, laughing) You said that three times ago."],
			["PANG", "...Those are my hands."],
			["", "Here's what I know. I drove it once."],
			["PANG", "He posted it. No name. He wanted people to see it."],
			["RUEL", "It looks that way."],
		] },

	# ===================================================================== ACT III  ·  THE GHOST IS YOU
	{ "id": "a3_card", "scene": "S23", "stage": "panel", "type": "chapter",
		"act": "ACT III", "title": "THE GHOST IS YOU", "subtitle": "The clip is yours. Then: it never happened." },
	{ "id": "s23", "scene": "S23", "stage": "hub", "type": "talk", "spot": "talyer", "night": true, "place": "RUEL'S TALYER", "when": "AFTER CLOSING",
		"comic": [[
			{ "art": "black", "cap": "After closing. Ruel's laptop on the bench, the backup drive beside it. GHOST_LINE/v1, title card still on." },
			{ "art": "tone", "cap": "Jolo's voice came out of the little speaker like he was in the next bay." },
		]],
		"lines": [
		["JOLO", "(on the clip) Say something for the people."],
		["PANG", "(on the clip) What people."],
		["JOLO", "(on the clip) Future people. Say hi to the future people."],
		["PANG", "(on the clip) Hi. The front left's making a noise."],
		["JOLO", "(on the clip) He's very charming in the future."],
		["", "The clip kept playing. Neither of us reached to stop it."],
		["~wait", 1.6],
		["PANG", "I drove that once. I can do it again."],
		["~wait", 1.0],
		["RUEL", "Clock's wrong."],
		["PANG", "What?"],
		["RUEL", "Under the picture. It skips."],
	] },
	{ "id": "s24", "scene": "S24", "stage": "hub", "type": "talk", "spot": "home", "cabin": true, "glass": 0.35,
		"place": "THE CAR, PARKED", "when": "AFTER THE CHALLENGE · ANOTHER ANGLE", "night": true,
		"comic": [[
			{ "art": "rain", "cap": "I drove home and didn't go in. Phone on the passenger seat. The other folder open: the same night, from the dash." },
		]],
		"lines": [
		["", "On Jolo's phone, readable now: COMPOSITE LINE STUDY — BEST SECTORS / NOT ONE RUN."],
		["JOLO", "There is something about the clip I should've—"],
		["PANG", "I know. I know it's hard. If I get the middle clean, the rest follows."],
		["", "He looks at me for a long time. Then he locks the screen."],
		["", "He wasn't tired."],
		["~wait", 1.2],
		["PANG", "He could have told me."],
		["RUEL", "Yes."],
		["PANG", "He knew what it had become."],
		["RUEL", "Yes."],
	] },
	{ "id": "s25", "scene": "S25", "stage": "hub", "type": "evidence", "spot": "talyer", "place": "RUEL'S TALYER", "when": "THE PROJECT TIMELINE",
		"comic": [[
			{ "art": "tone", "cap": "Nico brought a projector. v3_FINAL went up on the shutter, every cut marked in tape." },
			{ "art": "face", "who": "NICO", "side": "right", "say": "Don't watch the car. Watch the numbers under it." },
		]],
		"before": [
			["NICO", "Clouds. The light changed."],
			["PANG", "Look at the sign."],
			["NICO", "Somebody hit it between takes."],
			["PANG", "Between takes."],
			["~wait", 1.4],
			["NICO", "Play it again."],
		],
		"cards": [
			{ "kind": "clip", "title": "GHOST_LINE_COMPOSITE · TIMELINE" },
			{ "kind": "text", "title": "THE SIGN AT 8A", "body": "intact in /raw_tuesday\nbent in /raw_thursday\n\nOne road. Two different weeks." },
		],
		"question": "Pick two things that a single, uninterrupted run could not do.",
		"options": [
			"The logger clock resets where the picture looks continuous",
			"The speed trace steps at a join",
			"One section was recorded on a damp road, the others dry; the 8A sign is bent in one and straight in another",
			"The ghost car is the same model as mine",
			"Dante's caption calls it GHOST TIME",
		],
		"answer": [0, 1, 2], "pick": 2,
		"wrong": ["NICO", "One run could do that too. Find a join."],
		"after": [
			["NICO", "Two runs. Maybe."],
			["PANG", "Look at the clock at the second join."],
			["NICO", "...Three."],
			["", "Best entry. Cleanest middle. Fastest exit. Three different days. Every piece of it was me."],
			["NICO", "Cut's {cut_time}. Poster says {ghost_time}."],
			["PANG", "Somebody rounded."],
			["NICO", "Down."],
			["PANG", "Then why couldn't I beat myself?"],
			["NICO", "Yourself? You were racing an edit. With a number even the edit never did."],
			["PANG", "The one we'll pretend you meant to do."],
			["", "Nico peeled the tape off the shutter."],
		] },
	{ "id": "s26", "scene": "S26", "stage": "pass", "type": "sectors", "title": "THE SECTOR TRIALS", "connect": true,
		"comic": [[
			{ "art": "road", "cap": "Pass 1, dry, new fronts. Nico's sheet clipped to the dash." },
		]],
		"before": [["NICO", "Each piece under its own conditions, like the source passes. Then the whole road. One go. Today."]],
		"trials": [
			{ "sector": 0, "label": "SECTOR 1  ·  DRY (PASS A)", "wet": 0.0, "night": 0.0 },
			{ "sector": 1, "label": "SECTOR 2  ·  DAMP (PASS B)", "wet": 0.45, "night": 0.1 },
			{ "sector": 3, "label": "SECTOR 4  ·  DRY, LOW SUN (PASS C)", "wet": 0.0, "night": 0.3 },
		],
		"after_cards": [{ "kind": "trials", "title": "CONTROLLED TEST · NICO'S SHEET" }],
		"beaten": [
			["NICO", "It still never happened as one run. Not on the days it says."],
			["NICO", "You did the middle. You did the exit. Different days."],
			["NICO", "One road. One go. ...Write that down."],
		],
		"after": [
			["NICO", "Every sector, you're close. The number skips the road between them. You can't."],
			["PANG", "So it was impossible."],
			["NICO", "As advertised. The middle was yours. The exit was yours. Write that down."],
		] },

	# ===================================================================== ACT IV  ·  WHAT HAPPENED ON THE MOUNTAIN / MEMORY 4
	{ "id": "a4_card", "scene": "S11", "stage": "panel", "type": "chapter",
		"act": "ACT IV", "title": "WHAT HAPPENED ON THE MOUNTAIN", "subtitle": "Friday. Rain since noon." },
	{ "id": "s11", "scene": "S11", "stage": "hub", "type": "evidence", "spot": "talyer", "place": "RUEL'S TALYER", "when": "THE WEEK OF THE NIGHT RUN", "memory": "THE WEEK OF THE NIGHT RUN",
		"comic": [[
			{ "art": "tone", "cap": "The sign at 8A, bent since the rainy season. I stood under it in daylight and couldn't make the corner look dangerous." },
			{ "art": "tone", "cap": "The last week came back whole. THE WEEK OF THE NIGHT RUN." },
			{ "art": "face", "who": "DANTE", "side": "right", "sfx": "phone_buzz", "say": "Night run, Pass 1. Beat Ghost Time, it's yours. One hundred fifty thousand. Sponsors want the footage. Friday." },
		]],
		"cards": [
			{ "kind": "text", "title": "RUEL'S ESTIMATE", "body": "Front tires, pair .......... ₱9,600\nBrake pads + fluid ........ ₱3,100\nRear shocks (leaking) ..... ₱7,800\nAlignment ................. ₱900\n\nTOTAL ..................... ₱21,400\n\n\"Not optional.\"  — R." },
			{ "kind": "text", "title": "THE EVENT", "body": "GHOST LINE NIGHT RUN\nPass 1 · downhill · after dark\nBeat GHOST TIME: ₱150,000\n\nEntry ₱2,000\nSponsors · crowd · side bets\n\"Someone finally beats Ghost.\"" },
			{ "kind": "text", "title": "JOLO'S NOTES APP", "body": "owe Kuya Ben (lens) ₱18,000\nshop bill (Ruel) ₱11,500\nentry fees x3 ₱6,000\n\nif we win: pay all, tires, START THE GARAGE\nif we don't: ???" },
		],
		"after": [
			["", "Dante needed a night. Jolo needed eighteen thousand for a lens. I needed the number."],
			["JOLO", "Prize covers all of it."],
			["RUEL", "Some of it."],
			["JOLO", "\"Some\" is how \"more\"—"],
			["", "Ruel didn't say the rest. Neither did he."],
			["RUEL", "Bring the car in before you say yes to anything. I want those tires."],
		] },
	{ "id": "s12", "scene": "S12", "stage": "hub", "type": "talk", "spot": "talyer", "night_value": 0.6, "rain": 0.6, "wet": 0.9,
		"place": "RUEL'S TALYER", "when": "THE NIGHT RUN · DUSK",
		"comic": [[
			{ "art": "rain", "cap": "FRIDAY · DUSK · RAIN SINCE NOON" },
			{ "art": "face", "who": "RUEL", "side": "right", "say": "You can say no to Dante. You can't say no to standing water." },
		]],
		"lines": [
		["PANG", "We've driven there before."],
		["RUEL", "Dry. Slower. Different week."],
		["JOLO", "We should pull out."],
		["PANG", "You got us in."],
		["JOLO", "I got us an invitation. I didn't order the rain."],
		["PANG", "Money changes things."],
		["JOLO", "Money doesn't change grip."],
		["PANG", "I'm close."],
		["JOLO", "Boss, the clip isn't—"],
		["~sfx", "phone_buzz"],
		["", "Dante's name on the screen. Jolo watched it until it stopped. Then he didn't finish."],
		["PANG", "We take the first section easy. Feel the road."],
		["RUEL", "You don't get to feel a wet road after you've committed to the corner."],
		["JOLO", "Eat. Pan de sal. You brake angry when you're hungry."],
		["RUEL", "Bring it home."],
		["JOLO", "Okay."],
	],
		"comic_after": [[
			{ "art": "wipers", "sfx": "wiper", "cap": "PASS 1 · THE NIGHT RUN" },
			{ "art": "face", "who": "PANG", "side": "left", "say": "Do you want to go?" },
			{ "art": "face", "who": "JOLO", "side": "right", "say": "We're here." },
		]] },
	{ "id": "s13", "scene": "S13", "stage": "pass", "type": "crash", "title": "THE LAST NIGHT RUN", "posted": true, "grip": 0.95 },
	{ "id": "s27", "scene": "S27", "stage": "pass", "type": "evidence", "at": "overlook", "place": "PASS 1 · ABOVE 8A", "when": "DAYLIGHT", "now": "wiper", "night_value": 0.0, "wet": 0.0,
		"before": [
			["NICO", "Lower road's behind that ridge. A car down there is hidden most of the bend. Then its lights come through the gap."],
			["WITNESS", "I was leaving the sari-sari store. Two cigarettes and a Coke. A car went up the lower road."],
			["WITNESS", "Lights in the trees. I didn't see it reach the top bend."],
			["WITNESS", "Sorry. I thought the police knew more than me."],
		],
		"cards": [
			{ "kind": "map", "title": "PASS 1 · 8A AND THE LOWER SWITCHBACK" },
			{ "kind": "text", "title": "DASH CAMERA · LAST FRAMES", "body": "Lights cross the windshield between trees, left of the car.\nHillside between them and the road the whole time.\nThey never enter your lane.\nThe file breaks off before impact." },
		],
		"question": "Where were the headlights?",
		"options": [
			"Beside us, in our lane",
			"On the lower switchback, behind the ridge",
			"Following us down from the start",
			"There were no lights",
		],
		"answer": [1],
		"wrong": ["NICO", "The lights were real. Where does the map put them?"],
		"after": [
			["", "Here's what I know. There were two cars at that corner. One of them was on a different road."],
			["NICO", "8A. Here."],
			["RUEL", "Then we read the logger."],
		] },
	{ "id": "s28", "scene": "S28", "stage": "hub", "type": "evidence", "spot": "talyer", "place": "RUEL'S TALYER", "when": "THE LOGGER",
		"comic": [[
			{ "art": "tone", "cap": "Back down the mountain in daylight. Ruel wired the logger to the bench and the last 160 metres came up as four lines." },
			{ "art": "face", "who": "RUEL", "side": "right", "say": "Read it like a road. Left to right." },
		]],
		"cards": [{ "kind": "logger", "title": "LOGGER · THE NIGHT RUN · THE LAST 160 M" }],
		"question": "What does the logger show going into 8A?",
		"options": [
			"A swerve to avoid a car entering our lane",
			"Faster than the dry practice, braking later, then a sharp correction as the grip went",
			"The brakes failed",
			"Contact from the side",
		],
		"answer": [1],
		"wrong": ["RUEL", "Read the traces, not the memory. Where does the steering move, and why?"],
		"after": [
			["JOLO", "(the camera's last audio) Pang, it's wet. It's wet."],
			["", "Then noise. The logger goes on a little farther. The camera doesn't."],
			["", "Nothing in it swerves for a car. The car leaves the road after my correction. Not before."],
			["RUEL", "Thirty years, every man who brings a car in here tells me what's wrong with it before I open the hood."],
			["RUEL", "Almost always wrong. Not lying. They just tell me the version where it's the car's fault."],
			["RUEL", "I kept that box because the box doesn't do that. Not for you. Not for the family."],
			["RUEL", "I wanted one thing in all this that couldn't tell itself a story."],
			["PANG", "And now?"],
			["RUEL", "Now you know what it says."],
			["", "He picked up a rag."],
		] },
	{ "id": "s29", "scene": "S29", "stage": "hub", "type": "evidence", "spot": "talyer", "place": "RUEL'S TALYER", "when": "LATE · THE WORKBENCH",
		"before": [["", "I wiped UNKNOWN DRIVER off the board. Under it I wrote: WHAT THE EVIDENCE SUPPORTS."]],
		"cards": [{ "kind": "text", "title": "THE BOARD", "body": "Raw footage · the circulating clip · Jolo's notes · Nico's sectors\nDash camera (partial) · logger · map of 8A · witness statement\n\nPick the four the evidence supports." }],
		"question": "What does the evidence support?",
		"options": [
			"The Ghost footage came from my car; Jolo was filming",
			"Ghost is a stranger nobody in Iloilo knows",
			"The benchmark was cut together from separate passes",
			"Dante arranged a car to run us off the road",
			"The lights were a car on the lower switchback, not beside us",
			"Another car forced us off at 8A",
			"I went into the wet corner too fast and lost it after a sharp correction",
			"The logger proves every second of what happened",
		],
		"answer": [0, 2, 4, 6], "pick": 4,
		"wrong": ["RUEL", "Not that one. What did we actually see?"],
		"after": [
			["", "I didn't write that I knew every second."],
			["RUEL", "What now?"],
			["PANG", "I post the files. All of them."],
			["NICO", "Half of them won't believe it. I'm being generous."],
			["PANG", "I know."],
		] },
	{ "id": "s30", "scene": "S30", "stage": "hub", "type": "talk", "spot": "kyo", "place": "KYO COFFEE", "when": "LATE SUN", "night_value": 0.3, "wet": 0.0,
		"comic": [[
			{ "art": "tone", "cap": "Kyo Coffee, late sun. Dante's table. The folder went down on it before anyone said hello." },
		]],
		"lines": [
		["DANTE", "Coffee? I'm getting coffee."],
		["", "The folder open between us: v1, title card and all. He didn't pretend not to know it."],
		["PANG", "The notes say {cut_time}. Your poster says {ghost_time}."],
		["DANTE", "Posters round."],
		["PANG", "Down?"],
		["DANTE", "Nobody drives down a mountain at night to chase {cut_time}, my friend."],
		["DANTE", "A record, somebody takes it, everybody goes home. A ghost sells this Saturday. And the one after."],
		["PANG", "You found time where there wasn't supposed to be any."],
		["DANTE", "I said that. To you. Behind the warehouses."],
		["DANTE", "I didn't put you in the car. I didn't tell you to ignore the rain. I didn't cause the crash."],
		["PANG", "No. You didn't."],
		["~wait", 1.2],
		["PANG", "I'm posting the files."],
		["DANTE", "Post them. I won't stop it."],
		["DANTE", "Then they'll ask who was driving that night, and you'll tell them that too. I'm only asking if you've thought about which part they'll remember."],
		["PANG", "I've thought about it."],
		["DANTE", "Then you're braver than me. Sugar?"],
	] },
	{ "id": "s31", "scene": "S31", "stage": "panel", "type": "talk", "style": "phone", "place": "PASS 1 RUNNERS (PRIVATE GROUP)", "when": "A WEEK LATER", "lines": [
		["NICO", "Sector notes, repeat tests, source files. The Ghost Line is a composite of separate passes. Every sector is real. It was never one run, and the posted time is shorter than even the cut. That is all the evidence supports."],
		["ATE LIZA", "I told you that sign was bent."],
		["KAPITAN", "fake notes. legend is legend"],
		["BUKO", "so who's ghost"],
		["TISOY", "read the post"],
		["DANTE", "(left the group)"],
		["DANTE", "(rejoined the group)"],
		["", "Forty-one people read it. Buko asked again on Thursday."],
	] },

	# ===================================================================== ACT V
	{ "id": "a5_card", "scene": "S32", "stage": "panel", "type": "chapter",
		"act": "ACT V", "title": "THE ROAD IS NOT A RECORDING", "subtitle": "Two barangays over." },
	{ "id": "s32", "scene": "S32", "stage": "room", "type": "talk", "set": "jolo_home", "place": "JOLO'S FAMILY HOME", "when": "AFTERNOON",
		"comic": [[
			{ "art": "tone", "cap": "Jolo's family home, two barangays over. Concrete and dogs. The files on a drive, the notes on paper." },
			{ "art": "black", "cap": "I knocked once and waited." },
		]],
		"lines": [
		["", "His mother opened the door and looked at me for a long time before she stepped aside."],
		["", "Rice and laundry soap. A fan clicking. On the shelf, the picture from the talyer. Ruel frowning."],
		["PANG", "I brought the original files."],
		["PANG", "The Ghost Line was cut from three of my runs. He labelled it a study. Dante took a number off it and posted it."],
		["PANG", "The lights were a car on the lower road. Not beside us."],
		["PANG", "It was raining. Ruel said the tires were done. I went into the corner too fast. Jolo told me it was wet. I heard him."],
		["", "Nobody answered. His sister got up and left the room."],
		["JOLO'S FATHER", "So he made it up. The video."],
		["PANG", "He made the video. I drove."],
		["JOLO'S MOTHER", "Why did you think there was another car?"],
		["PANG", "I saw lights. I needed them to be someone."],
		["JOLO'S MOTHER", "Needed?"],
		["PANG", "If it was someone, I could go and find him."],
		["~wait", 1.6],
		["JOLO'S MOTHER", "Leave a copy of everything."],
		["JOLO'S MOTHER", "A man came about a lens."],
		["PANG", "Kuya Ben. I'll pay him."],
		["JOLO'S MOTHER", "Did he eat? That night."],
		["PANG", "Pan de sal. In the car."],
		["JOLO'S MOTHER", "That's not dinner."],
		["", "She went into the kitchen. The rice cooker clicked. I didn't get up."],
		["PANG", "I won't ask you to forgive me."],
		["JOLO'S FATHER", "Good."],
	] },
	{ "id": "s33", "scene": "S33", "stage": "hub", "type": "goto", "place": "kyo", "prompt": "THE BARANGAY  ·  WEEKS LATER" },
	{ "id": "s33t", "scene": "S33", "stage": "hub", "type": "talk", "spot": "kyo", "place": "KYO COFFEE", "when": "WEEKS LATER", "lines": [
		["KAPITAN", "Still a legend, Pang. I don't care about your notes."],
		["ATE LIZA", "Good that you said it. Sit. Eat first."],
		["BUKO", "So who's Ghost."],
		["TISOY", "Bro. Dante's still running Saturdays. Fewer people."],
		["NICO", "Drive the mountain with me. Daylight. No event, no timer, no crowd."],
		["PANG", "Why?"],
		["NICO", "I want to see what it looks like at forty."],
	] },
	{ "id": "s34", "scene": "S34", "stage": "pass", "type": "daylight", "title": "THE DAYLIGHT ROAD",
		"comic": [[
			{ "art": "face", "who": "NICO", "side": "left", "say": "No timer." },
			{ "art": "face", "who": "PANG", "side": "right", "say": "No timer." },
		]],
		"before": [["", "A weekday morning. A delivery truck uphill. A family of four on one motorcycle. Patches in the asphalt I'd never seen at speed."]],
		"after": [
			["NICO", "That's it?"],
			["PANG", "That's it."],
			["", "Here's what I know. I was driving."],
		] },
	{ "id": "s35", "scene": "S35", "stage": "hub", "type": "talk", "spot": "talyer", "night": true, "rain": 0.4, "wet": 0.6,
		"place": "RUEL'S TALYER", "when": "EPILOGUE · THE RAINS RETURN",
		"comic": [[
			{ "art": "rain", "cap": "The rains came back the way they always do. Afternoon, all at once." },
		]],
		"lines": [
		["", "Somebody wanted a used sensor. Somebody else was wrong about coilovers."],
		["KID", "Has anyone beaten the Ghost Line yet?"],
		["", "Someone said a guy got within a tenth. Someone said it was fake. Ate Liza said it wasn't, exactly. That took a while."],
		["KID", "So nobody ever beat it?"],
		["PANG", "Who does your tires?"],
		["KID", "They're fine."],
		["PANG", "They're not finished becoming dangerous."],
		["KID", "What?"],
		["", "At the bench, Ruel didn't look up."],
		["RUEL", "Different thing."],
		["~sfx", "wrench"],
		["", "The engine caught on the second turn. The trim tapped the dash."],
	] },
	{ "id": "end", "scene": "END", "stage": "panel", "type": "end" },

]


## The first beat of each act, for the story page's chapter list: [[label, beat index], ...].
static func acts() -> Array:
	var out := []
	for i in BEATS.size():
		var b: Dictionary = BEATS[i]
		if b["type"] == "chapter":
			out.append(["%s  ·  %s" % [b["act"], b["title"]], i])
	return out


## The period label of the memory beat `index` is inside, "" in the present.
static func memory_of(index: int) -> String:
	var open := ""
	for i in mini(index + 1, BEATS.size()):
		var b: Dictionary = BEATS[i]
		if b.has("memory"):
			open = b["memory"]
		if b.has("now"):
			open = ""
	return open


static func index_of(id: String) -> int:
	for i in BEATS.size():
		if BEATS[i]["id"] == id:
			return i
	return -1
