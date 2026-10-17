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
		"act": "PROLOGUE", "title": "THE MISSING SECONDS", "subtitle": "The road will not be the same twice." },
	{ "id": "s00", "scene": "S00", "stage": "pass", "type": "crash", "cold_open": true,
		"comic": [
			[
				{ "art": "rain", "cap": "The first thing Pang remembered was the sound of rain striking the windshield, as if someone were throwing handfuls of gravel at it." },
				{ "art": "wipers", "fx": "SHHK", "sfx": "wiper", "cap": "The wipers dragged water from side to side." },
				{ "art": "face", "who": "JOLO", "side": "right", "cap": "Jolo had his phone raised. He was still recording. He recorded everything." },
			],
			[
				{ "art": "road", "cap": "The corner appeared. Pang knew it by the shape of the trees and the pale concrete post on the outside." },
				{ "art": "face", "who": "PANG", "side": "right", "cap": "Ghost's line. The perfect line." },
			],
		],
		"comic_after": [
			[
				{ "art": "black", "cap": "Afterward, he would remember the impact as silence." },
				{ "art": "lights", "cap": "He would remember the headlights, Jolo's voice, the white smear of rain." },
				{ "art": "face", "who": "PANG", "side": "right", "cap": "He would not remember exactly what he saw." },
				{ "art": "black", "cap": "In his mind, the headlights would always arrive at the corner. The rest would be missing." },
			],
		] },

	# ===================================================================== ACT I  ·  THE RETURN (present) / MEMORY 1 / present
	{ "id": "a1_card", "scene": "S14", "stage": "panel", "type": "chapter",
		"act": "ACT I", "title": "THE RETURN", "subtitle": "Grief, rumours, and a name nobody can place." },
	{ "id": "s14", "scene": "S14", "stage": "room", "type": "talk", "set": "clinic", "place": "THE CLINIC", "when": "AFTER THE CRASH",
		"lines": [
		["", "His body had healed in uneven patches. A scar climbed from his collar toward his shoulder."],
		["~set", "rented_room"],
		["~place", "A RENTED ROOM  ·  MONTHS LATER"],
		["", "He still woke at sounds that had no place in the room: rain against a window, a wiper dragging over glass."],
		["~sfx", "wiper"],
		["", "Bills. Messages from people asking questions. Silence where Jolo should be."],
		["", "Official report: SINGLE-VEHICLE ACCIDENT. NO SECOND VEHICLE CONFIRMED."],
		["PANG", "There was a car. There were lights. Beside us."],
		["", "He remembered that another car had been there. He could not say what it did."],
		["~sfx", "phone_buzz"],
		["RUEL", "The car's at the shop. So is the camera card. And the logger. Come when you're ready."],
	] },
	{ "id": "s15", "scene": "S15", "stage": "hub", "type": "evidence", "spot": "talyer", "place": "RUEL'S TALYER", "when": "AFTER THE CRASH",
		"before": [
			["RUEL", "I thought you might want them when you were ready."],
			["PANG", "Did they find the other driver?"],
			["RUEL", "There was no confirmed second car in their report."],
			["PANG", "They weren't there."],
			["RUEL", "No. I wasn't there either. A witness saw lights on the lower road. No one could say they were near you."],
		],
		"cards": [
			{ "kind": "text", "title": "CAMERA CARD (DAMAGED)", "body": "Jolo's phone card, cracked at the contacts.\nRecovered: footage up to {crash_cut} into the run.\nThe last seconds before impact: unreadable." },
			{ "kind": "text", "title": "DATA LOGGER", "body": "The small logger Jolo wired under the dash.\nSpeed · brake · steering · 20 Hz.\nIntact. Nobody has read it yet." },
		],
		"after": [
			["RUEL", "The car can tell us some things. Not everything."],
			["PANG", "I want to know who was beside us."],
			["RUEL", "You can ask what happened. Just don't decide the answer before you find it."],
		] },
	{ "id": "s01", "scene": "S01", "stage": "hub", "type": "talk", "spot": "talyer",
		"place": "RUEL'S TALYER", "when": "LATE AFTERNOON", "memory": "MONTHS BEFORE",
		"comic": [[
			{ "art": "black", "fx": "KLANK!", "sfx": "wrench", "cap": "The wrench hit the concrete with a flat, bright crack. Ruel bent to pick it up as if nothing had happened." },
			{ "art": "face", "who": "PANG", "side": "right", "cap": "Pang had heard that sound before. The same flat crack, the same concrete, the hood open on the same car." },
			{ "art": "tone", "cap": "MONTHS BEFORE. The smell of oil and hot dust. Jolo was still alive." },
		]],
		"lines": [
		["JOLO", "You're staring at it again."],
		["PANG", "I'm thinking."],
		["JOLO", "You've been thinking for twenty minutes. The hood's still open."],
		["PANG", "I'm deciding what to do."],
		["JOLO", "That's thinking with extra steps."],
		["RUEL", "If you two are finished becoming philosophers, one of you can hand me the ten-millimeter."],
		["RUEL", "Your front tires are near the end. And I don't like the feel of the brake pedal."],
		["PANG", "They're not done yet."],
		["RUEL", "They are not finished becoming dangerous. Different thing."],
		["JOLO", "We can do the tires next week. Maybe sooner if tonight goes well."],
		["RUEL", "What happens tonight?"],
		["JOLO", "Small meet. Private. The prize will cover the parts."],
		["RUEL", "The prize will cover some of the parts."],
		["JOLO", "\"Some\" is how \"more\" begins."],
		["RUEL", "That is also how debt begins."],
		["RUEL", "You can go. But you do not confuse me not stopping you, with me approving."],
		["JOLO", "That's almost a blessing."],
		["RUEL", "It's a bill waiting to happen."],
	],
		"comic_after": [[
			{ "art": "face", "who": "JOLO", "side": "left", "say": "Tonight goes well, we do the tires. Promise." },
			{ "art": "face", "who": "RUEL", "side": "right", "say": "Promises don't stop a car." },
			{ "art": "snap", "fx": "KSHK", "sfx": "shutter", "cap": "Jolo took a picture of the three of them anyway." },
		]] },
	{ "id": "s02", "scene": "S02", "stage": "hub", "type": "goto", "place": "gas", "night": true,
		"prompt": "THE MEET  ·  BAHANDI FUELS",
		"comic": [[
			{ "art": "snap", "cap": "THAT NIGHT" },
			{ "art": "face", "who": "JOLO", "side": "left", "say": "Entry fee's paid. Five hundred, Pang. Don't make me explain that to my mother." },
			{ "art": "face", "who": "PANG", "side": "right", "say": "Where?" },
			{ "art": "face", "who": "JOLO", "side": "left", "say": "Bahandi Fuels, then the loop behind the warehouses. They're waiting." },
		]] },
	{ "id": "s03", "scene": "S03", "stage": "hub", "type": "race", "course": "loop", "night": true,
		"title": "NOTHING TO LOSE", "require_win": true,
		"field": [["KAPITAN", "silak_box", "1f4dbf", 0.84], ["TISOY", "eg_hatch", "17171a", 0.85], ["RJ", "civic_fd", "8c8f94", 0.83]],
		"comic": [[
			{ "art": "snap", "cap": "No one called it a street race. They called it a meet, as though a different word could make the risks behave differently." },
			{ "art": "face", "who": "RUEL", "side": "left", "cap": "A text from Ruel.", "say": "Just bring it home in one piece.", "sfx": "phone_buzz" },
			{ "art": "face", "who": "JOLO", "side": "right", "say": "Define home." },
		]],
		"lose": [["JOLO", "Again. The entry's already paid, and they'll let you run it back if I ask nice."]],
		"after": [
			["JOLO", "You saw that? You saw what you did?"],
			["PANG", "I drove."],
			["JOLO", "You made that car look like it owes you money."],
			["DANTE", "You found time where there wasn't supposed to be any."],
			["DANTE", "There are better events than this. Come by Kyo next week. I'll introduce you around."],
		] },
	{ "id": "s04t", "scene": "S04", "stage": "hub", "type": "talk", "spot": "kyo", "night": true,
		"place": "KYO COFFEE", "when": "PAST MIDNIGHT", "lines": [
		["", "Dante's gift was not speed. It was making people feel that the next room had been waiting for them."],
		["DANTE", "You have something people want to watch. Not just pace. A story. Small car, limited budget, driver who makes it work."],
		["PANG", "I just drive."],
		["DANTE", "Everybody says that. The ones who last learn that people don't follow numbers alone."],
		["", "A clean, expensive car rolls onto the apron. Nico steps out and looks over the hatch."],
		["NICO", "What tires are you running?"],
		["PANG", "Whatever I can afford."],
		["NICO", "You drove well."],
		["PANG", "Something else you want to say?"],
		["NICO", "I think you found a few seconds you won't find again on the same setup. That's still driving well. It isn't the same as being ready."],
		["DANTE", "Gentlemen. Pass 1, Saturday, before the light goes. Settle it there."],
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
			["PANG", "And you drive like you have a spreadsheet open in your head."],
			["NICO", "I do compare the runs. One good corner tells you what you can do. A repeatable run tells you what the car and the driver can actually do."],
		],
		"lose": [
			["NICO", "You're fast. But you drive every corner like the next one owes you something."],
			["PANG", "And you drive like you have a spreadsheet open in your head."],
			["NICO", "I do compare the runs. One good corner tells you what you can do. A repeatable run tells you what the car and the driver can actually do."],
			["PANG", "Must be nice to afford enough tires to find out."],
			["NICO", "It is. I won't pretend otherwise. But money isn't why you overcorrected at the last bend."],
		],
		"after": [
			["JOLO", "Good race. Really good race. We got footage. We got contacts. Nobody's funeral today."],
			["", "The joke died in the air before it reached the three of them."],
		] },
	{ "id": "s16", "scene": "S16", "stage": "hub", "type": "race", "course": "loop", "title": "THE FIRST RETURN", "trauma": true, "now": "wrench",
		"night_value": 0.0,
		"field": [["KAPITAN", "silak_box", "1f4dbf", 0.86], ["BUKO", "dalagan_gsr", "1a6b3d", 0.86], ["RJ", "civic_fd", "8c8f94", 0.84]],
		"before": [["", "The route was short, the other drivers familiar, the weather clear. He told himself the conditions were controlled."]],
		"after": [
			["", "A younger driver laughed kindly."],
			["RJ", "You'll get it back."],
			["RUEL", "It's not the setup."],
			["PANG", "The car's rusty. I'm rusty."],
			["RUEL", "The car did exactly what you asked."],
			["RJ", "Someone said there was another car up there that night. Beside you. Ask around at Kyo."],
		] },
	{ "id": "s17", "scene": "S17", "stage": "hub", "type": "goto", "place": "kyo", "night": true, "prompt": "KYO COFFEE  ·  ASK AROUND" },
	{ "id": "s17e", "scene": "S17", "stage": "hub", "type": "evidence", "spot": "kyo", "night": true, "place": "KYO COFFEE", "when": "AFTER THE CRASH",
		"before": [
			["KAPITAN", "Ghost? Former pro, I'm telling you. Raced in Japan, came home, left again. That clip's years old."],
			["ATE LIZA", "Years? No. That was filmed months before your crash. I know the sign at 8A, they bent it last rainy season."],
			["BUKO", "Ghost was on the mountain that night. Protecting the time. Dark car, no plates. Everybody knows."],
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
		"wrong": ["RUEL", "That's one person's version. What does it do to the other two?"],
		"after": [
			["NICO", "You looked like you were waiting for someone to appear beside you."],
			["PANG", "You saw something?"],
			["NICO", "No. I saw you checking an empty lane. I tried the Ghost Line more times than I want to admit."],
			["NICO", "The line itself is good. Some of the sections are excellent. But the total doesn't behave like a continuous run."],
			["NICO", "Drive it with me. Sector by sector. Then tell me it's one run."],
		] },
	{ "id": "s06", "scene": "S06", "stage": "pass", "type": "practice", "title": "A LINE STUDY", "memory": "THE LINE STUDY",
		"comic": [[
			{ "art": "black", "cap": "Buko's phone, face up on the table at Kyo. The clip again. A passenger-side angle, low on the glass, the road coming up through the rain on the lens." },
			{ "art": "tone", "cap": "Rain on glass. Pang looked at it until something older came up instead: a Tuesday in the dry, months before. THE LINE STUDY. It began with a joke." },
			{ "art": "face", "who": "JOLO", "side": "left", "say": "Three passes. I'm rolling the whole time. Drive it like nobody's watching." },
			{ "art": "face", "who": "PANG", "side": "right", "say": "You're literally watching." },
		]],
		"passes": [
			{ "label": "PASS A  ·  TUESDAY 3:40 PM  ·  DRY", "wet": 0.0, "night": 0.0, "sign": "intact",
				"note": ["JOLO", "Good entry. That first sweeper? Keep that one."] },
			{ "label": "PASS B  ·  THURSDAY 4:15 PM  ·  DAMP PATCHES AFTER A SHOWER", "sheen": 0.45, "night": 0.1,
				"note": ["JOLO", "Middle was clean. Road's still wet on the inside, did you feel that?"] },
			{ "label": "PASS C  ·  SATURDAY 5:30 PM  ·  DRY  ·  LOW SUN", "wet": 0.0, "night": 0.3,
				"note": ["JOLO", "There. That's the one."] },
		],
		"comic_after": [[
			{ "art": "snap", "cap": "The light went." },
			{ "art": "face", "who": "PANG", "side": "left", "say": "Which one?" },
			{ "art": "face", "who": "JOLO", "side": "right", "say": "The one we'll pretend you meant to do." },
		]] },
	{ "id": "s20", "scene": "S20", "stage": "hub", "type": "talk", "spot": "kyo", "night": true, "place": "KYO COFFEE", "when": "DANTE'S TABLE", "now": "phone_buzz", "lines": [
		["PANG", "Who is Ghost?"],
		["DANTE", "If I knew, I'd have sold tickets to him."],
		["PANG", "You posted the clip. You put a time on it. You ran an event off it. And you don't know who was driving."],
		["DANTE", "It came to me the way everything does. Somebody sends it, I post it. I never asked. Nobody wanted me to ask."],
		["PANG", "Did you have a driver out there that night? Somebody on the lower road, keeping the time safe?"],
		["DANTE", "No. I never told anyone another car forced you off the road, and I never arranged for anyone to go near your car."],
		["DANTE", "You want me to tell you I made the crash happen? I didn't. I arranged a race. People came to watch a run, not an accident. You chose to drive."],
		["PANG", "What did you do after?"],
		["DANTE", "I kept it from turning into a scandal built on rumours. I said it was a tragedy. That was true."],
		["PANG", "You let the rumours run."],
		["DANTE", "I didn't correct every version of every story. No one can."],
		["PANG", "No. But you corrected the ones that cost you money."],
		["PANG", "Then give me the original file."],
		["DANTE", "There is no original. There's what got posted."],
		["RUEL", "Jolo's laptop died before the crash. I backed up his camera folder. It's in a drawer somewhere."],
	] },

	# ===================================================================== ACT II  ·  THE GHOST / MEMORY 3
	{ "id": "a2_card", "scene": "S18", "stage": "panel", "type": "chapter",
		"act": "ACT II", "title": "THE GHOST", "subtitle": "A line nobody can finish, and the one who posted it." },
	{ "id": "s18", "scene": "S18", "stage": "pass", "type": "sectors", "title": "NICO REPEATS THE TEST",
		"before": [["NICO", "Flying sectors. I'll put the ghost on each one. Match it, then we look at the joins."]],
		"trials": [
			{ "sector": 0, "label": "SECTOR 1", "wet": 0.0, "night": 0.0, "note": ["NICO", "Close. That's the easy part. Now the middle."] },
			{ "sector": 1, "label": "SECTOR 2", "wet": 0.0, "night": 0.0, "note": ["NICO", "Same entry as sector one and it bites you. The ghost didn't come in with that speed. It came in from somewhere else."] },
			{ "sector": 2, "label": "SECTOR 3", "wet": 0.0, "night": 0.0, "note": ["NICO", "One more."] },
		],
		"after_cards": [{ "kind": "notes", "title": "NICO'S NOTES" }],
		"after": [
			["NICO", "It's not horsepower and it's not a secret technique. Look at the clock under the video."],
			["NICO", "The clip's logger resets where the picture looks continuous. A single pass doesn't do that."],
			["PANG", "Could someone have driven it once?"],
			["NICO", "I can't prove they didn't. We need the original footage. The versions going around have been cropped and re-encoded."],
			["PANG", "Why are you helping me?"],
			["NICO", "Because I don't like being beaten by something that doesn't exist. And because I don't think you remember that night clearly."],
		] },
	{ "id": "s19", "scene": "S19", "stage": "panel", "type": "talk", "place": "RUEL'S TALYER", "when": "TUESDAY · RAIN", "lines": [
		["~sfx", "wrench"],
		["JOLO", "That's not what I meant."],
		["PANG", "Then say what you meant."],
		["~place", "RUEL'S TALYER · SATURDAY · DRY"],
		["JOLO", "I meant we fix the car before we chase anything. The new wheel's on, at least."],
		["~place", "KYO COFFEE · THE SAME NIGHT?"],
		["DANTE", "Nobody cares about the notes."],
		["~place", "RUEL'S TALYER · A WEEK LATER · THE OLD WHEEL"],
		["JOLO", "Same shirt, Pang. I wore it twice. You keep putting me in it."],
		["", "Each memory arrived with the confidence of a thing that had just occurred. Each one carried a detail that did not fit."],
		["", "Separate true moments, joined into one continuous night. He began to write things down."],
		["~cut", ""],
		["~sfx", "phone_buzz"],
	] },
	{ "id": "s07", "scene": "S07", "stage": "panel", "type": "talk", "style": "phone", "memory": "GHOST GOES PUBLIC",
		"comic": [[
			{ "art": "black", "cap": "Jolo's camera bag, where he left it under the bench. The strap still set to his shoulder." },
			{ "art": "tone", "cap": "By the next afternoon Dante had posted a clip: a reference pace, an anonymous driver. Someone in the comments called him Ghost." },
			{ "art": "tone", "cap": "THE WEEK GHOST WENT PUBLIC." },
		]],
		"place": "PASS 1 RUNNERS (PRIVATE GROUP)", "when": "THE NEXT AFTERNOON", "lines": [
		["DANTE", "Reference pace from an anonymous driver. Nobody on this island has matched it. GHOST TIME {ghost_time}."],
		["BUKO", "who is this"],
		["KAPITAN", "former pro. moved to Japan, apparently"],
		["ATE LIZA", "Somebody said he crashed and disappeared. What car is that?"],
		["TISOY", "ghost lol"],
		["BUKO", "Ghost. Okay. Anyone trying to beat it?"],
		["DANTE", "Saturday. Pass 1. Sector targets on the board. Bring your best."],
		["~place", "KYO COFFEE · LATER"],
		["JOLO", "Dante took something off it."],
		["PANG", "Off what? It looks good."],
		["JOLO", "That's not the point."],
		["PANG", "Then what is?"],
		["", "Jolo watched the clip a second time and did not answer."],
		["PANG", "People are interested. Somebody out there can drive."],
		["~sfx", "phone_buzz"],
		["DANTE", "The scene needs a benchmark. Nobody cares about a clip labeled \"study\". They care about a driver nobody can catch."],
		["", "Jolo read it, turned the phone face down, and said nothing. Whatever the point was, he kept it."],
	] },
	{ "id": "s08", "scene": "S08", "stage": "pass", "type": "attack", "title": "CHASE THE COMPOSITE", "grip": 0.95,
		"comic": [[
			{ "art": "road", "cap": "He had watched the clip so often that the line seemed to occupy the road before the road itself appeared." },
			{ "art": "face", "who": "RUEL", "side": "right", "say": "Fronts are near the end. You'll feel it on the brakes. Don't come back and tell me the car changed." },
		]],
		"beaten": [
			["JOLO", "You... beat it."],
			["PANG", "Once. Today, in the dry. Watch the middle again, it doesn't feel like I drove the same road."],
			["JOLO", "Pang, about the clip—"],
			["PANG", "I'll beat it every time. Whoever he is."],
			["JOLO", "...Okay."],
		],
		"after": [
			["JOLO", "That's better than last time."],
			["PANG", "Still not enough."],
			["JOLO", "It's not a person, Pang. You don't have to make it nervous."],
			["PANG", "It has a time."],
			["JOLO", "Pang, about the clip. There's something I—"],
			["PANG", "I'm close. I can feel it in the middle section. Tell me after."],
			["JOLO", "...Okay. After."],
		] },
	{ "id": "s09", "scene": "S09", "stage": "pass", "type": "attack", "title": "THE COMBINED-SECTOR CHALLENGE",
		"label_clue": true, "night_value": 0.55, "grip": 0.95,
		"comic": [[
			{ "art": "tone", "cap": "THE NEXT SATURDAY · A CROWD AT THE TOP OF PASS 1" },
			{ "art": "face", "who": "DANTE", "side": "right", "say": "Ghost Time is on the board. Beat the sectors, beat the legend. Next driver!" },
		]],
		"after_cards": [{ "kind": "board", "title": "GHOST LINE CHALLENGE · SECTOR BOARD" }],
		"beaten": [
			["DANTE", "Unofficial. A practice night, nobody timing the sectors but your own friend. Ghost Time stands."],
			["PANG", "I beat it."],
			["DANTE", "Then do it again in front of everyone. Bigger night. Bigger prize."],
			["NICO", "The target isn't behaving like one run. I can reproduce each piece. I can't make the whole thing add up, and neither did you, not the way the clip does it."],
		],
		"after": [
			["PANG", "What's wrong?"],
			["NICO", "The target isn't behaving like one run."],
			["PANG", "What does that mean?"],
			["NICO", "The first sector rewards one kind of entry. The middle was recorded on a different surface, and the exit comes from a pass with a different rhythm. I can reproduce each piece. I can't make the whole thing add up."],
			["PANG", "Then make it add up."],
			["NICO", "That's what I've been doing."],
		] },
	{ "id": "s10", "scene": "S10", "stage": "hub", "type": "talk", "spot": "home", "cabin": true, "glass": 0.35,
		"place": "THE CAR, PARKED", "when": "AFTER MIDNIGHT", "night": true,
		"comic": [[
			{ "art": "rain", "cap": "AFTER MIDNIGHT · THE CAR, PARKED OUTSIDE PANG'S" },
			{ "art": "face", "who": "JOLO", "side": "right", "cap": "Jolo sat in the passenger seat with his phone open. The project notes were on the screen." },
		]],
		"lines": [
		["JOLO", "There is something about the clip I should've—"],
		["PANG", "I know. I know it's hard. But I can do it. If I get the middle clean, the rest will follow."],
		["~wait", 1.4],
		["JOLO", "We need to look at the car. And the weather. The next run's going to be different."],
		["", "Pang heard caution. He did not hear a confession."],
	] },
	{ "id": "s21", "scene": "S21", "stage": "hub", "type": "evidence", "spot": "talyer", "place": "RUEL'S TALYER", "when": "THE COMPUTER BENCH", "now": "phone_buzz",
		"before": [["RUEL", "Don't expect a miracle. Half the files may be damaged."]],
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
			["JOLO", "(on the clip, laughing) You said that four runs ago."],
			["PANG", "That's me."],
			["", "The driver he had spent months trying to find was himself."],
			["PANG", "Jolo uploaded it anonymously. He wanted people to see it."],
			["RUEL", "It appears that way."],
		] },

	# ===================================================================== ACT III  ·  THE GHOST IS YOU
	{ "id": "a3_card", "scene": "S23", "stage": "panel", "type": "chapter",
		"act": "ACT III", "title": "THE GHOST IS YOU", "subtitle": "The clip is yours. Then: it never happened." },
	{ "id": "s23", "scene": "S23", "stage": "hub", "type": "talk", "spot": "talyer", "night": true, "place": "RUEL'S TALYER", "when": "AFTER CLOSING", "lines": [
		["JOLO", "(on the clip) Pang. Pang. Don't lift there. Okay, lift there."],
		["PANG", "(on the clip) Make up your mind."],
		["JOLO", "(on the clip) I'm the camera. The camera doesn't have a mind."],
		["~wait", 1.6],
		["PANG", "I was better than I remember. There was one real run. I can get it back. I can beat it."],
		["~wait", 1.0],
		["RUEL", "This timestamp is wrong."],
		["PANG", "What?"],
		["RUEL", "The clock under the video. It doesn't count like one run."],
	] },
	{ "id": "s24", "scene": "S24", "stage": "hub", "type": "talk", "spot": "home", "cabin": true, "glass": 0.35,
		"place": "THE CAR, PARKED", "when": "AFTER THE CHALLENGE · ANOTHER ANGLE", "night": true, "lines": [
		["", "Ruel found it in a separate folder: the same night in the car, filmed from the dash."],
		["", "On Jolo's phone, readable now: COMPOSITE LINE STUDY — BEST SECTORS / NOT ONE RUN."],
		["JOLO", "There is something about the clip I should've—"],
		["PANG", "I know. I know it's hard. But I can do it. If I get the middle clean, the rest will follow."],
		["", "Jolo looked at him. He saw not arrogance but hope, the same hope he had spent months trying to feed. He locked the screen."],
		["~wait", 1.2],
		["PANG", "He could have told me."],
		["RUEL", "Yes."],
		["PANG", "He knew what it had become."],
		["RUEL", "Yes."],
		["", "Ruel did not defend Jolo. He did not accuse him either."],
	] },
	{ "id": "s25", "scene": "S25", "stage": "hub", "type": "evidence", "spot": "talyer", "place": "RUEL'S TALYER", "when": "THE PROJECT TIMELINE",
		"before": [["NICO", "Play it through. Watch the numbers, not the car."]],
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
		"wrong": ["NICO", "That could be true of one run too. Find a join."],
		"after": [
			["", "Jolo's notes, under the first version of the edit: COMPOSITE LINE STUDY — BEST SECTORS / NOT ONE RUN."],
			["", "The best entry, the cleanest middle, the fastest exit, gathered from separate attempts. Every piece was real. The completed performance was not."],
			["PANG", "Why couldn't I beat myself?"],
			["NICO", "Because you weren't trying to beat yourself. You were trying to beat an edit."],
		] },
	{ "id": "s26", "scene": "S26", "stage": "pass", "type": "sectors", "title": "THE SECTOR TRIALS", "connect": true,
		"before": [["NICO", "Each piece under its own conditions, like the source passes. Then all of it, in one go, on today's road."]],
		"trials": [
			{ "sector": 0, "label": "SECTOR 1  ·  DRY (PASS A)", "wet": 0.0, "night": 0.0 },
			{ "sector": 1, "label": "SECTOR 2  ·  DAMP (PASS B)", "wet": 0.45, "night": 0.1 },
			{ "sector": 3, "label": "SECTOR 4  ·  DRY, LOW SUN (PASS C)", "wet": 0.0, "night": 0.3 },
		],
		"after_cards": [{ "kind": "trials", "title": "CONTROLLED TEST · NICO'S SHEET" }],
		"beaten": [
			["NICO", "You beat the number. Today, on new tires, on one road. Good. It still never happened as one run on the days it claims."],
			["NICO", "Every piece was real. You did this. You did the middle. You did the exit. The claim that they happened together was false."],
		],
		"after": [
			["NICO", "You can get close in each section. You can improve each one. But the combined number isn't a completed drive. It assumes there are no costs between the best moments."],
			["PANG", "So it was impossible."],
			["NICO", "It was impossible as advertised. That's not the same as saying the driving was fake. You did this. You did the middle. You did the exit. The skill was real."],
		] },

	# ===================================================================== ACT IV  ·  WHAT HAPPENED ON THE MOUNTAIN / MEMORY 4
	{ "id": "a4_card", "scene": "S11", "stage": "panel", "type": "chapter",
		"act": "ACT IV", "title": "WHAT HAPPENED ON THE MOUNTAIN", "subtitle": "The evidence rules out the story he wanted." },
	{ "id": "s11", "scene": "S11", "stage": "hub", "type": "evidence", "spot": "talyer", "place": "RUEL'S TALYER", "when": "THE WEEK OF THE NIGHT RUN", "memory": "THE WEEK OF THE NIGHT RUN",
		"comic": [[
			{ "art": "rain", "cap": "The sign at 8A, bent since the rainy season. Pang stood under it in the daylight and could not make the corner look dangerous." },
			{ "art": "tone", "cap": "The last week came back whole. THE WEEK OF THE NIGHT RUN." },
			{ "art": "face", "who": "DANTE", "side": "right", "sfx": "phone_buzz", "say": "Night run, Pass 1. Beat Ghost Time and it's yours. One hundred fifty thousand. Sponsors want the footage. Friday." },
		]],
		"cards": [
			{ "kind": "text", "title": "RUEL'S ESTIMATE", "body": "Front tires, pair .......... ₱9,600\nBrake pads + fluid ........ ₱3,100\nRear shocks (leaking) ..... ₱7,800\nAlignment ................. ₱900\n\nTOTAL ..................... ₱21,400\n\n\"Not optional.\"  — R." },
			{ "kind": "text", "title": "THE EVENT", "body": "GHOST LINE NIGHT RUN\nPass 1 · downhill · after dark\nBeat GHOST TIME: ₱150,000\n\nEntry ₱2,000\nSponsors · crowd · side bets\n\"Someone finally beats Ghost.\"" },
			{ "kind": "text", "title": "JOLO'S NOTES APP", "body": "owe Kuya Ben (lens) ₱18,000\nshop bill (Ruel) ₱11,500\nentry fees x3 ₱6,000\n\nif we win: pay all, tires, START THE GARAGE\nif we don't: ???" },
		],
		"after": [
			["", "Dante needs a headline event. Jolo needs money and momentum. Pang needs to prove the benchmark is within reach."],
			["RUEL", "Before you commit to anything, bring the car in. I want to look at those tires."],
		] },
	{ "id": "s12", "scene": "S12", "stage": "hub", "type": "talk", "spot": "talyer", "night_value": 0.6, "rain": 0.6, "wet": 0.9,
		"place": "RUEL'S TALYER", "when": "THE NIGHT RUN · DUSK",
		"comic": [[
			{ "art": "rain", "cap": "FRIDAY · DUSK · IT HAD RAINED SINCE NOON" },
			{ "art": "face", "who": "RUEL", "side": "right", "say": "You can say no to the event. You can't negotiate with standing water." },
		]],
		"lines": [
		["PANG", "We've driven there before."],
		["RUEL", "On a different surface. At a different speed. In different weather."],
		["PANG", "That's why we're testing ourselves."],
		["RUEL", "No. That's why you're trying to make the road keep a promise it never made."],
		["JOLO", "We should pull out."],
		["PANG", "You got us into this."],
		["JOLO", "I got us the invitation. I didn't make the weather."],
		["PANG", "The money changes things."],
		["JOLO", "Money doesn't change grip."],
		["PANG", "I'm close."],
		["JOLO", "Pang, the clip isn't—"],
		["~sfx", "phone_buzz"],
		["", "Dante's name on the screen. Jolo stared at it until the vibration stopped. He had another chance. He did not take it."],
		["PANG", "We'll take it easy on the first section. See how the road feels."],
		["RUEL", "You don't get to know how a wet road feels after you've committed to the corner."],
	],
		"comic_after": [[
			{ "art": "wipers", "sfx": "wiper", "cap": "PASS 1 · THE NIGHT RUN" },
			{ "art": "face", "who": "PANG", "side": "left", "say": "Do you want to go?" },
			{ "art": "face", "who": "JOLO", "side": "right", "say": "We're here." },
		]] },
	{ "id": "s13", "scene": "S13", "stage": "pass", "type": "crash", "title": "THE LAST NIGHT RUN", "grip": 0.95 },
	{ "id": "s27", "scene": "S27", "stage": "pass", "type": "evidence", "at": "overlook", "place": "PASS 1 · ABOVE 8A", "when": "DAYLIGHT", "now": "wiper", "night_value": 0.0, "wet": 0.0,
		"before": [
			["NICO", "From here, the lower section runs behind that ridge. A car on it would be hidden for most of the bend, then its lights would show through the gap."],
			["WITNESS", "I was leaving the sari-sari store. A car went up the lower road. I saw the lights in the trees. I didn't see it come up to the top bend."],
			["WITNESS", "I'm sorry. I thought the police would know more than I did."],
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
			["", "The headlights were real. The threat he had given them was not supported by the evidence."],
			["NICO", "8A. Here."],
			["RUEL", "Then we read the logger."],
		] },
	{ "id": "s28", "scene": "S28", "stage": "hub", "type": "evidence", "spot": "talyer", "place": "RUEL'S TALYER", "when": "THE LOGGER",
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
			["JOLO", "(the camera's last audio) Drive the road!"],
			["", "Then the file ended in a burst of noise. The logger continued a little farther. The camera did not."],
			["", "There was no input consistent with avoiding a car. The car left the road after the correction, not before it."],
		] },
	{ "id": "s29", "scene": "S29", "stage": "hub", "type": "evidence", "spot": "talyer", "place": "RUEL'S TALYER", "when": "LATE · THE WORKBENCH",
		"before": [["", "He erased UNKNOWN DRIVER from the board. Beneath it he wrote: WHAT THE EVIDENCE SUPPORTS."]],
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
			["", "He did not write that he knew every second. The data could tell them enough to stop treating a rumour as a fact."],
			["RUEL", "What now?"],
			["PANG", "Now I tell the truth."],
			["NICO", "That won't make everyone believe it."],
			["PANG", "I know."],
			["NICO", "It may cost you more than the races did."],
			["PANG", "I know that too."],
		] },
	{ "id": "s30", "scene": "S30", "stage": "hub", "type": "talk", "spot": "kyo", "place": "KYO COFFEE", "when": "LATE SUN", "night_value": 0.3, "wet": 0.0, "lines": [
		["", "The folder was open on the table between them: v1, with its title card. Dante did not pretend not to recognise it."],
		["PANG", "A target no one could complete."],
		["DANTE", "People wanted something impossible. A driver who could not be found, a number nobody could touch. I gave the scene what it was asking for."],
		["PANG", "You gave it what you could sell."],
		["DANTE", "A verified record can be broken. A legend sells the next event. I didn't put you in the car. I didn't tell you to ignore the weather. I didn't cause the crash."],
		["PANG", "No. You didn't."],
		["DANTE", "What are you going to do?"],
		["PANG", "Release the files."],
		["DANTE", "Some will say the notes are fake. You won't control the story any more than I do."],
		["PANG", "I know."],
		["~wait", 1.2],
		["DANTE", "I'll let the original context circulate. I won't stop it."],
		["PANG", "That isn't the same as telling the truth."],
		["DANTE", "No. It isn't."],
	] },
	{ "id": "s31", "scene": "S31", "stage": "panel", "type": "talk", "style": "phone", "place": "PASS 1 RUNNERS (PRIVATE GROUP)", "when": "A WEEK LATER", "lines": [
		["NICO", "Sector notes, repeated tests, and the source files for the Ghost Line. It is a composite of separate passes. Each sector is real. The total was never one run. That is all the evidence supports."],
		["ATE LIZA", "I knew that sign was bent."],
		["KAPITAN", "fake notes. legend is legend"],
		["BUKO", "so who's ghost"],
		["TISOY", "read the post"],
		["KAPITAN", "every racing legend is exaggerated. still a good challenge"],
		["DANTE", "(left the group)"],
		["DANTE", "(rejoined the group)"],
		["", "Some drivers accepted it. Others did not. Truth could be offered, but not made compulsory."],
	] },

	# ===================================================================== ACT V
	{ "id": "a5_card", "scene": "S32", "stage": "panel", "type": "chapter",
		"act": "ACT V", "title": "THE ROAD IS NOT A RECORDING", "subtitle": "Responsibility without absolution." },
	{ "id": "s32", "scene": "S32", "stage": "room", "type": "talk", "set": "jolo_home", "place": "JOLO'S FAMILY HOME", "when": "AFTERNOON", "lines": [
		["", "Jolo's mother opened the door and looked at him for a long time before stepping aside."],
		["", "The house smelled of rice and laundry soap. A fan clicked in the corner. A photograph of Jolo smiled toward a camera he had probably set up himself."],
		["PANG", "I brought the original files."],
		["PANG", "The Ghost Line was put together from different runs. Jolo labelled it a composite line study. Dante put it out as an anonymous benchmark. People treated the total like a run someone had finished."],
		["PANG", "I tried to beat it. On the night, it was raining. The tires were wrong. Ruel told me. Jolo told me. I chose to go."],
		["PANG", "The lights were a car on the lower road. The logger shows I came into the corner too fast, braked late and overcorrected. The camera's last seconds are gone. That's what the evidence shows."],
		["JOLO'S FATHER", "Are you telling us our son made the lie that killed him?"],
		["PANG", "No. Jolo made the edit. He didn't make me drive that night. He tried to warn me. He should have told me the truth about the clip sooner, but I chose to go. I ignored him when it mattered."],
		["JOLO'S MOTHER", "Why did you think there was another car?"],
		["PANG", "I saw lights. I thought they were beside us. I needed them to mean something."],
		["JOLO'S MOTHER", "Needed?"],
		["PANG", "If another driver caused it, then I could find him. I could be angry at someone who wasn't me."],
		["~wait", 1.6],
		["JOLO'S MOTHER", "Leave a copy of everything. We'll look at it when we're ready."],
		["PANG", "I won't ask you to forgive me."],
		["JOLO'S FATHER", "Good."],
		["", "The word hurt because it was fair."],
	] },
	{ "id": "s33", "scene": "S33", "stage": "hub", "type": "goto", "place": "kyo", "prompt": "THE BARANGAY  ·  WEEKS LATER",
		"lines": [["", "Weeks later. The garage, the coffee shop, the gas station. The scene carried on."]] },
	{ "id": "s33t", "scene": "S33", "stage": "hub", "type": "talk", "spot": "kyo", "place": "KYO COFFEE", "when": "WEEKS LATER", "lines": [
		["KAPITAN", "Still a legend, Pang. I don't care about your notes."],
		["ATE LIZA", "Good that you said it. Not easy."],
		["BUKO", "..."],
		["TISOY", "Dante's still running Saturdays. Fewer people."],
		["NICO", "Drive the mountain with me. Daylight. No event, no timer, no crowd."],
		["PANG", "Why?"],
		["NICO", "Because we've both spent too long turning every drive into a measurement."],
	] },
	{ "id": "s34", "scene": "S34", "stage": "pass", "type": "daylight", "title": "THE DAYLIGHT ROAD",
		"before": [["", "A weekday morning. A delivery truck uphill. A family on a motorcycle. The asphalt changed texture where repairs had been made. Nothing was the same as it had been."]],
		"after": [
			["NICO", "That's it?"],
			["PANG", "That's it."],
			["", "He had not defeated the corner. He had not undone the night. He had simply made a different decision when the road asked him to."],
		] },
	{ "id": "s35", "scene": "S35", "stage": "hub", "type": "talk", "spot": "talyer", "night": true, "rain": 0.4, "wet": 0.6,
		"place": "RUEL'S TALYER", "when": "EPILOGUE · THE RAINS RETURN", "lines": [
		["", "The garage was full again. Someone was looking for a used sensor. Someone else was arguing about coilovers on Philippine roads."],
		["KID", "Has anyone beaten the Ghost Line yet?"],
		["", "A few people laughed. Someone said a driver came within a tenth. Someone said the whole thing was fake, which started a familiar argument about what fake meant when every part of the footage had been real."],
		["PANG", "You check the tires and brakes?"],
		["KID", "I mean, yeah. Mostly. I'm more worried about the time."],
		["PANG", "A recording can teach you something. But it can't drive your car for you. The road won't be the same twice."],
		["", "The kid nodded politely, the way people did when they heard advice they had not yet needed."],
		["~sfx", "wrench"],
		["", "The engine started on the second turn. Its idle was uneven; the trim tapped lightly against the dash. The sound belonged to the car, not to a promise."],
		["", "The road continued ahead, imperfect and unrepeatable. For once, that was enough."],
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
