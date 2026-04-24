This is a template for a 2D platformer using Love2D.


# DO NOT REFERNCE: STARTING PROMPT
I want you to populate the @Plan.md with a plan for making a 2D platformer using Love2D. Specifically, I want to
  - create claude skills that will implement the creation of this 2D platformer
  - Have a skill that does research on the documentation of Love2D
  - Have a skill that researches other games built on Love2D that are open source who's code bases are available, and have
   similar features to the ones that the user is trying to implement.
  - A Skill that researches general game knowledge about how to implement a system or a feature. For example, how to
  define sprites, how to implement them into the codebase, what are typical physics and mechaincs and how they are
  implemented in other games, etc etc etc.
  - Have a skill the analyzes the users requests, and asks lots of contextual questions to verify the exact implementation
   of the request that they made.
  - Have a skill dedicated to code optimization and implementing LUA. It references LUA documentation, and verifies best
  pracitces.
  - A skill dedicated to cloud infrastructure and how to save global state. Also how to deploy the application, and access
   it.
  - a skill to analyze and audit the code. To be a pessimistic reviwer in a bad mood that look through the code in a vedry
   rigorous way.
  - A skill (a metaskill maybe) that will spin up a new project in Love2D. It will spin up a platformer only in 2D. It
  will make a game that is similar to the game 'Hollow Knight'. This will make a map for all the connected levels, it will
   connect the levels, it will implement limit the access to levels based on criteria of if a boss fight was won, or an
  item was obtained to be able to get through a passage or over a chasm.
  - A skill to define power curves in the game (how quickly a character progresses in the character abilities). Each new
  area or level should have ascending difficulty of the characters, and each new item or ability should give the player
  more damage, health, skills, abilities, items, etc to be able to go through the next round.
  - A skill new items that are recieved in the game. It implements new abilities for the character, and guides the user on
   how to define them. This also does this for abilities. It questions the developer of the game to defined these
  abilites. It gives them ability options from Overwatch 2, and terraria. This gives them concrete options for the
  abilites that they can give to the player.
  - A skill to be able to handle git commits. To be able to look at code changes, and do 'internal PR reviews' which will
  self analyze the code changes in a judgemental way to be able to optimize code before it is committed to git.

  What is the best way to sturcture these skills? How do we do this in a systematic way, and create boundaries between
  these skills so they are used optimially by the user?

  how do we test and refine these skills? Should there be a skill for that? how should the AI handle the creation,
  modification, and testing of these skills to be able to self improve?
