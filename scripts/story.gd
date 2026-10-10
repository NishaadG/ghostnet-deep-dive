class_name Story
extends RefCounted
# Every cutscene and radio line in one file, written as plain data so the story can be read
# (and edited) without touching any code. The Cutscene screen plays these beats in order.
#
# A beat is a Dictionary. Every key is optional:
#   "set": "reef"            switch to a stage set (see CutsceneStage.SETS)
#   "cam": [x, y, zoom]      move the camera over "t" seconds (default 1.2)
#   "act": "nova_in"         a stage action, or an array of them (see CutsceneStage.act)
#   "sfx": "cut"             play a sound
#   "cap": "..."             narration in a yellow comic caption box
#   "who": "pip", "say": ""  a line of dialogue from a character
#   "wait": 1.5              no text: move on by itself after this many seconds
#
# When each scene plays (main.gd and run.gd decide this):
#   intro         a new game starts
#   wallN_meet    the dive pauses the first time wall N comes into view
#   wallN_torn    after the dive that tore wall N open (walls 0 to 2)
#   ending        after the dive that frees the Lumen (wall 3)
#   net_return    the first dive after buying Net Return

const SPEAKERS := {
	"nova": {"name": "NOVA", "color": Color("ff6fb8")},
	"pip": {"name": "PIP", "color": Color("46f2e8")},
	"captain": {"name": "CAPTAIN VALE", "color": Color("ffb84a")},
	"radio": {"name": "CAPTAIN VALE  ·  RADIO", "color": Color("ffb84a")},
	"ilo": {"name": "ILO, DECKHAND", "color": Color("ffe14a")},
	"harbour": {"name": "HARBOURMASTER", "color": Color("b48cff")},
}

# The order of scenes in the Story gallery on the title screen.
const ORDER := ["intro", "wall0_meet", "wall0_torn", "net_return", "wall1_meet", "wall1_torn",
		"wall2_meet", "wall2_torn", "wall3_meet", "ending"]

const SCENES := {
	"intro": {"title": "Cut It Loose", "beats": [
		{"set": "dock", "cap": "2190. Port Halo."},
		{"cap": "A floating city, fed by fleets that never dock."},
		{"act": "shake", "sfx": "net_hit", "who": "ilo", "say": "Net's snagged on the old wrecks again, Captain!"},
		{"cam": [560, 250, 1.5], "who": "captain", "say": "Cut it loose."},
		{"who": "captain", "say": "A new net costs less than an hour of hauling."},
		{"set": "under_boat", "act": "snip", "sfx": "cut", "cap": "It happens a hundred times a day. Up there, the net is forgotten in a minute."},
		{"act": "net_sink", "cap": "Down here, it keeps fishing. No boat. No crew. No end."},
		{"cap": "Divers call them ghost nets."},
		{"set": "reef", "act": "nova_in", "cap": "Nova Vale, 16. Reef warden. Also the captain's daughter."},
		{"who": "pip", "say": "That is ghost net 212 this month."},
		{"who": "nova", "say": "Easy, little one. Almost free."},
		{"act": "nova_cut", "sfx": "cut", "wait": 1.6},
		{"act": "whale_pass", "cap": "Lumen Reef. The last living reef under Port Halo."},
		{"cap": "It glows because of her. Where the Lumen sings, coral wakes."},
		{"who": "nova", "say": "Every night I count the lights she keeps on."},
		{"act": ["lights_out", "pip_alarm"], "sfx": "alarm", "who": "pip", "say": "Nova. The song just stopped."},
		{"set": "signal", "cap": "41 lights went dark in one minute."},
		{"who": "pip", "say": "Her last signal came from the Abyss. 3,600 metres out, past four walls of net."},
		{"who": "nova", "say": "Then we cut through them."},
		{"who": "pip", "say": "With a kickboard and a pair of wire snips?"},
		{"who": "nova", "say": "We start small. The harbourmaster pays a bounty for every fleet tag. Tags buy gear."},
		{"set": "dock", "cam": [860, 260, 1.4], "who": "pip", "say": "And the launch ramp? It is bolted to your mother's boat."},
		{"who": "nova", "say": "Mom won't notice. She never looks down."},
	]},

	"wall0_meet": {"title": "The Reef Gate", "beats": [
		{"set": "gate", "cap": "400 metres out. The Reef Gate."},
		{"who": "pip", "say": "Scanning. Sixty nets, knotted into one. The current piled them against the old harbour arch."},
		{"who": "nova", "say": "It's a wall. A wall made of nets."},
		{"who": "pip", "say": "Anything that swims into it stays."},
		{"who": "nova", "say": "Then it doesn't stay up."},
		{"who": "pip", "say": "Hit it fast and hit it heavy. It does not heal. Every hit counts, even the ones that bounce."},
		{"who": "nova", "say": "Then we keep coming back."},
	]},

	"wall0_torn": {"title": "Boat 11", "beats": [
		{"set": "gate_torn", "act": "fish_burst", "cap": "The Reef Gate tears open."},
		{"who": "pip", "say": "Two hundred fish just swam home."},
		{"set": "tag_11", "cap": "Knotted into the wall: a fleet tag."},
		{"who": "nova", "say": "Boat 11. Orla's crew. They buy Mom's coffee every morning."},
		{"who": "pip", "say": "Every net in that wall had a tag. I logged all sixty."},
		{"set": "dock_harbour", "who": "harbour", "say": "Sixty fleet tags. That's a fat bounty, kid."},
		{"who": "nova", "say": "That's sixty nets."},
		{"who": "harbour", "say": "I pay for tags. I don't ask where they've been."},
		{"who": "nova", "say": "Maybe you should."},
		{"cap": "Next: the City Seal, 1,500 metres out, in the Drowned City."},
	]},

	"net_return": {"title": "The Return Bin", "beats": [
		{"set": "dock_harbour", "cap": "Port Halo. A new bin on the dock, painted bright orange."},
		{"who": "harbour", "say": "First net ever hauled back on purpose. Boat 03. Took them an hour and ten minutes."},
		{"who": "nova", "say": "And the sea got one less ghost."},
		{"who": "harbour", "say": "One boat. Eleven to go. The others say it's a waste of fuel."},
		{"who": "nova", "say": "Then I'll keep paying for it. Every tag I bring up."},
		{"cap": "Every net that comes home is one Nova never has to cut."},
	]},

	"wall1_meet": {"title": "The Drowned City", "beats": [
		{"set": "city", "cap": "1,500 metres. The Drowned City."},
		{"cap": "Old Halo. The sea rose over it in 2131. The people built a new city on top, and kept fishing."},
		{"who": "nova", "say": "Grandma's school is down here somewhere."},
		{"who": "pip", "say": "The City Seal. Nets wrapped street to street. Three times thicker than the Reef Gate."},
		{"act": "radio", "sfx": "click", "who": "radio", "say": "Nova. Pip's beacon puts you past the reef. Come up. Now."},
		{"who": "nova", "say": "Not yet, Mom."},
		{"who": "radio", "say": "That city drowned once. I am not losing you to it."},
		{"who": "pip", "say": "She sounds scared."},
		{"who": "nova", "say": "She sounds like the captain."},
	]},

	"wall1_torn": {"title": "We Knew", "beats": [
		{"set": "city_torn", "act": "fish_burst", "cap": "The City Seal gives way."},
		{"set": "sign", "cap": "Behind it, an old sign, still bolted to the street."},
		{"who": "pip", "say": "This was a protected reef. Before the water came up."},
		{"who": "nova", "say": "So we knew. Sixty years ago, we already knew."},
		{"set": "tag_scratched", "cap": "Another tag. The boat number is scraped off."},
		{"who": "pip", "say": "Boat zero-something. Nine boats in the fleet have a number under ten."},
		{"who": "nova", "say": "...Keep logging, Pip."},
		{"set": "night_dock", "who": "captain", "say": "You're bringing up a lot of tags, Nova."},
		{"who": "nova", "say": "They're your fleet's tags, Mom."},
		{"who": "captain", "say": "Hauling a snag back costs an hour. An hour is fuel. Fuel is wages. Twelve crews eat because we don't stop."},
		{"who": "nova", "say": "The reef doesn't eat at all any more."},
		{"cap": "Neither of them slept that night."},
		{"cap": "Next: the Slope Curtain, 2,800 metres out, where the light ends."},
	]},

	"wall2_meet": {"title": "Where the Light Ends", "beats": [
		{"set": "slope", "cap": "2,800 metres. Where the Slope drops into the Trench."},
		{"who": "pip", "say": "Light ends here. I'll be your torch."},
		{"act": "faint_song", "who": "pip", "say": "Wait. Listen."},
		{"who": "nova", "say": "That's her. She's still singing."},
		{"who": "pip", "say": "Barely. Something is pressing on her chest."},
		{"set": "drift", "cap": "The Drift. Everything the surface cuts loose ends up here."},
		{"who": "nova", "say": "I cut one, three more fall."},
		{"set": "slope", "who": "pip", "say": "The Slope Curtain. Old nets, heavy with plastic. We will need real speed."},
		{"who": "nova", "say": "Then give me the dark. I'll bring the speed."},
	]},

	"wall2_torn": {"title": "Ours, Not Mine", "beats": [
		{"set": "slope_torn", "act": "fish_burst", "cap": "The Slope Curtain falls away into the dark."},
		{"who": "pip", "say": "The Trench is open. The Abyss is past it. So is she."},
		{"set": "dock_all", "who": "harbour", "say": "Three hundred tags, Captain. Every single one of them is ours."},
		{"who": "captain", "say": "Ours. Not mine."},
		{"who": "nova", "say": "The Lumen is under all of it, Mom. She went quiet the night the fleet cut forty nets."},
		{"who": "captain", "say": "The Lumen is a bedtime story. A whale your grandmother made up."},
		{"who": "nova", "say": "Pip heard her. Three days ago."},
		{"who": "captain", "say": "..."},
		{"who": "harbour", "say": "The return bin is on the dock. Can't make anyone use it."},
		{"who": "nova", "say": "Then make it worth using. Put the bounty on nets that come home, not just on tags."},
		{"cap": "Next: the Lumen's Net, 3,600 metres out, in the Abyss."},
	]},

	"wall3_meet": {"title": "Forty-One", "beats": [
		{"set": "abyss", "cap": "3,600 metres. The Abyss."},
		{"cap": "And that is where they found her."},
		{"cap": "The Lumen. Older than the fleets. Held down by what they cut loose."},
		{"cam": [520, 330, 1.5], "who": "nova", "say": "She's still breathing."},
		{"who": "pip", "say": "Barely. I count 41 nets on her."},
		{"who": "nova", "say": "Forty-one. One for every light that went out."},
		{"cam": [640, 360, 1.0], "who": "pip", "say": "Her net is the heaviest of all. One clean run, with everything we have."},
		{"who": "nova", "say": "Hold on, big girl. We're coming through."},
	]},

	"ending": {"title": "Every Net Comes Home", "beats": [
		{"set": "abyss", "act": "cut_sparks", "sfx": "cut", "cap": "So she cut. One net at a time."},
		{"act": ["cut_sparks", "pip_alarm"], "sfx": "alarm", "who": "pip", "say": "O2 at 12%. We have to surface."},
		{"who": "nova", "say": "Not without her."},
		{"set": "tag_07", "cap": "Then she saw the tag."},
		{"who": "nova", "say": "Boat 07... that's Mom's boat."},
		{"cap": "All 41 nets on the Lumen came from Port Halo."},
		{"set": "abyss", "act": "whale_free", "sfx": "whale_song", "cap": "The last net fell away."},
		{"set": "reef_dark", "act": ["lights_on", "whale_pass"], "cap": "One song. A thousand lights came back."},
		{"who": "pip", "say": "The reef is safe. Where are we going?"},
		{"who": "nova", "say": "Up. To where the nets come from."},
		{"set": "dock_family", "act": "thud", "sfx": "net_hit", "who": "nova", "say": "Forty-one nets, Mom. Every one has our name on it."},
		{"cam": [680, 250, 1.5], "who": "captain", "say": "Boat 07. That one is mine."},
		{"who": "captain", "say": "I gave that order a hundred times. I never once looked down."},
		{"cam": [640, 360, 1.0], "who": "captain", "say": "Ilo. Signal the fleet. From tonight, nothing gets cut loose."},
		{"who": "ilo", "say": "Aye, Captain. Every net comes home."},
		{"cap": "Port Halo's new rule: every net that goes down comes back up."},
		{"set": "reef", "cap": "But a century of nets is still down there."},
		{"who": "nova", "say": "Then we keep diving."},
		{"cap": "The dive continues. This time, you hold the cutter."},
	]},
}


static func title_of(id: String) -> String:
	return String(SCENES[id]["title"])


static func beats_of(id: String) -> Array:
	return SCENES[id]["beats"]


# ---- Radio: short lines over the HUD during a dive (they never pause the game) ----

# Pip at the start of a dive, picked by which wall is next (index 4 = story finished).
const DIVE_START := [
	"Reef Gate is 400 metres out. Build speed before you reach it.",
	"City Seal at 1,500 metres. Stay low between the towers.",
	"The Slope Curtain is at 2,800 metres. It gets dark past the Slope.",
	"She's out there. 3,600 metres. Let's bring her home.",
	"No walls left. Just nets. Let's see how far we get.",
]

# Captain Vale on the radio now and then, softening as the story goes on (index = walls torn).
const MOM_LINES := [
	"Nova, the ramp on Boat 07 is not a toy. Back before dark.",
	"Pip's beacon says you're past the reef again. Your grandmother did this too, you know.",
	"I logged every one of your tags myself. ...Be careful down there.",
	"The whole dock is listening to your beacon tonight. Bring her home, Nova.",
	"The fleet is hauling every net back. Dive safe, kiddo.",
]

# Pip, the first time a dive enters each zone (index = zone).
const ZONE_LINES := [
	"",
	"The Drowned City. Watch the rooftops.",
	"The Slope. The ceiling closes in from here.",
	"The Trench. Stay close to my light.",
	"The Abyss. She's close. I can hear her.",
]

# Pip, the first time a save meets each creature (saved in Game.seen_scenes as "tip_<kind>").
const HAZARD_LINES := {
	"puffer": "Puffer fish. Don't spook it: puffed up, it's all spikes. Go round, or go past before it puffs.",
	"piranha": "Piranhas? Out here? The nets drag them down from the river mouth. Keep your speed up and they can't bite.",
	"ray": "Electric ray. Watch it glow: when it flashes bright, stay out of the ring.",
}

const ANIMAL_LINES := ["Go on. Swim.", "There you go.", "You're free. Stay away from the nets.", "One more home."]
const LOW_O2_LINE := "O2 low. Find a canister or I'm towing you up."
