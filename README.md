# Godot Response System

GRS lets NPCs and other entities in your game respond (speak, animate, do actions, etc) based on what happens in the game and what others do/say. Writers can easily add, remove, or edit responses in your game's GRS spreadsheet, which is exported and then loaded by the system, which tells the entities in your game what to do in response to inputs.

## Overview

GRS is designed after Valve's response system used in the Source engine, and described in their GDC talk ["Rule Databases for Contextual Dialog and Game Logic"](https://youtu.be/tAbBID3N64A). It also borrows heavily from the [Response System docs](https://developer.valvesoftware.com/wiki/Response_System) on the Valve Developer Wiki. I recommend watching that talk and reading that page, as it'll give you a good idea of why and how this system works.

Basically:

- The system is designed to make contextual dialog, actions, sounds, and more easy to manage.
- It's designed with **writers** in mind, and tries to make it as easy as possible for them to create and edit responses.

To do so:

- Your game runs the Godot Response System (GRS).
- Each entity that can respond (NPCs, etc) is an 'actor'.
- Your actors send queries to GRS whenever **something they may need to respond to** happens.
- GRS searches the rule database you've loaded, and if there's a matching rule GRS sends the response to the actor.
- The actor emits a signal containing the response info. e.g. the name of the animation to play or the text to display.

## Response system nodes

- `GRS`:
	- A `GRS` singleton is added to your game by the plugin.
- `GrsActor`:
	- You add one of these to each entity (NPC, etc) that `GRS` sends responses to.
	- When created, it automatically adds itself to `GRS`. This lets that actor get responses from `GRS`, which the actor then emits as signals.
	- When removed from the node tree, it removes itself from `GRS`.
- `GrsFactDictionary`:
	- Contains context about the world, actor, and more, which inform response choices.
	- GRS sees game context by looking at the values in fact dictionaries.
- `GrsQuery` (submitted for each event/etc to be evaluated).
	- One of these is created for each event to be evaluated by `GRS`.
	- Queries are **dispatched** to `GRS`.
	- Contains:
		- `concept`: tells `GRS` what kind of event it's receiving (idle, question, answer, just hit, etc).
		- `actor`: which actor originated this query.
		- fact dictionary: contains context related to the query itself.
	- By default, facts are searched for in this order:
		- `GrsQuery`'s fact dictionary (most specific, contains concept, etc).
		- `GrsActor`'s fact dictionary (contains any information set on the actor).
		- `GRS` root fact dictionary (contains any game-wide info).
	- But you can also supply extra fact dictionaries. For example, maybe you want to supply a 'map' fact dictionary, a fact dictionary about the actor's faction or guild, or something different.

-----

Here's a high-level example of how `GRS` and `GrsActor`s interact. Dashed lines are queries sent to GRS and solid lines are signals emitted from the given `GrsActor`:

```mermaid
sequenceDiagram
	participant GRS
	participant NPC Alice
	participant NPC Trixie

	rect rgb(190,100,180,0.08)
		Note left of GRS: NPC Talk Idle
		NPC Alice -->>+ GRS: Can I say a line?
		GRS ->>- NPC Alice: say "Let's get a move on"
	end

	rect rgb(190,180,100,0.08)
		Note left of GRS: Game event<br>with answer
		NPC Trixie -->>+ GRS: An explosion happened near me
		GRS ->>- NPC Trixie: say "That was close!"
		NPC Trixie ->> NPC Alice: I said "That was close!"
		NPC Alice -->>+ GRS: I heard 'That was close!'
		GRS ->>- NPC Alice: say "No kidding..."
	end
```

## Response system data

Here's a description of the different types of files the response system loads. Our default importer takes a JSON file, created based on the contents of [base.yaml](./base.yaml).

Here's how the types of data are related:

```mermaid
flowchart LR
	subgraph Query
		direction LR
		subgraph Facts
			direction LR
			ConceptFact(concept: 'idle')
			WhoFact(who: 'em')
			RadioDistanceFact(radioDistance: 4.6)
		end
	end
	Query -->|tests| FoundRadioRule
	subgraph GRS
		direction LR
		subgraph FoundRadioRule
			direction LR
			Criterion1(is character 'Em'<br>criterion) ---|checks| Fact1(who == 'em')
			Criterion2(is near 'radio'<br>criterion) ---|checks| Fact2(radioDistance < 10)
		end
		subgraph FoundRadioResponses
			direction LR
			Response1(point at 'radio')
			Response2(say 'Look, a radio!')
		end

		FoundRadioRule ---|sends| FoundRadioResponses
	end
```

## Using the response system

Here's what happens when a query is evaluated by GRS:

```mermaid
flowchart LR
	subgraph GRS
		Evaluates{{evaluates}}
		subgraph Rules
			Rule1(em_is_idle<br><b>rule</b>)
			Rule2(em_is_working<br><b>rule</b>)
		end

		subgraph Responses
			Response1(say: What's up?<br><b>response</b>)
			Response2(say: I'm busy<br><b>response</b>)
		end
	end

	Query(player clicked on em<br><b>query</b>) --> Evaluates
	Evaluates -->|not matched| Rule1
	Evaluates -->|matched| Rule2

	Rule1 --- Response1
	Rule2 --- Response2

	Response2 -->|emits| Signal((do a 'say'<br><b>signal</b>))
```

Basically, when a query is dispatched to `GRS` it evaluates the rule database. If found, the best matching rule's response is used. The response emits a signal from the `GrsActor` that's evaluating the query. The node with that `GrsActor` can then accept that signal and, for example, display the string in a textbox or play a voice line.
