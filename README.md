# Snake for The GameBoy Advance [WIP]

## Written in GAS dialect ARM Assembly

Functional, but still a work in progress.

### Compilation and Running

#### Uses DevkitPro's DevkitARM toolchain

Specifically, the gba-dev package using DevkitPro's package manager, and specifically using the assembler provided
<b>by arm-none-eabi-gcc</b>.

The makefile itself might need to be used with GNU Make due to the way I wrote it, though.
I *hope* it works on Windows, though! I can only attest for it working on Linux.

#### Running the game

- On start up, the screen will be black. Just press the <b>Start</b> button to initialize the game! 

- I forgot to add a debouncing loop after the initial <b>Start</b> button press check, so it might initialize the grid, but then immediately pause itself:
    just press the <b>Start</b> button again and it should unpause you and let you play! From there, controls should just be intuitive;
    <b>DPad</b> moves the snake. 
- If you get a <b>Game Over</b>, a white noise sound effect will play, and the screen will go black again. If you just press 
  the <b>Start</b> button again, it will start a new game, just as it would when booting up!



### Implemented[^sidenote]

- Grid system
    - Draw grid state
    - RNG to grid idx for choosing apple location
- RNG system
    - LFSR-based RNG
    - Integrated RNG state manipulator into user-input poller
- User-Input system
    - Function/subroutine, poll_keys
        - Returns state of key input status register
        - Also passes this value to RNG state manipulator
- Handling of user inputs
- Snake movement, body tracking, and growth and apple spawning.

[^sidenote]: So, side note: the game's already finished now (as of 4/15/24).
    All that remains is optimizing the input handler so that controls run way more sleakly.


### TODO

- [x] Snake body tracking system. Ideas:
    - [x] Linking Structure[^1]
        - Head->Body<sub>0</sub>->...->Body<sub>n</sub>->Tail
        - { <b>grid_idx : int</b>, <b>link : Node*</b> }
    - [ ] Only Store Head Index[^2]
        - Only store head idx, and then follow body segments by 
          checking adjacent grid cells for snake indicator value.
- [ ] Point Tracker
- [x] Collision Checker
- [x] Bind Controls to Game Functions (e.g.: movement, pause/resume, menus, etc.)
- [x] Optimize input handler. Maybe just read directly from REG_KEY and only use poll_keys for RNG
   state manipulation.[^3]
- [ ] Beautification:
    - [x] Adding sound
    - [X] Adding text engine
    - [ ] Full menu system
    - [ ] Non-barebones pause screen

[^1]: This is the preferred choice given the simplicity of the game.
    Neither really strapped for cycle counts nor RAM, so the time and
    and space demand of a data structure as heavyweight as LL's 
    won't be an issue. This approach would also make updating the body
    way easier. Just append new head idx node to list and drop tail node.

[^2]: Just going to keep it real. This sounds like a pain to implement even
    in a high level language like C/C++. Moreover, I feel like dynamically 
    tracking the body would incur too much time overhead: definitely far 
    more than what the RAM, that we would save from foregoing the LL approach,
    would be worth.

[^3]: So initially, I thought my asm was just that bad, but I realized I forgot to implement the 2xbuffered
    grid system. So every main loop cycle, it would redraw the entire screen, which just resulted in a lot of
    redundency and time wasted. I implemented the double buffer and was able to get it to run super fast.
    So fast, in fact, that I actually just ended up having to make it invoke vsync several times in a row to make it
    human-playable (i.e.: let the game run slow enough to where player can react and move character as needed.


