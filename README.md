# Snake for The GameBoy Advance [WIP]

## Written in GAS dialect ARM Assembly

Work in progress.

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
- [ ] Optimize input handler. Maybe just read directly from REG_KEY and only use poll_keys for RNG
   state manipulation.

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

