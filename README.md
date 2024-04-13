# Snake for The GameBoy Advance [WIP]

## Written in GAS dialect ARM Assembly

Work in progress.

### Implemented

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

### TODO

1. Snake body tracking system. Ideas:
    - Linking Structure[^1]
        - Head->Body<sub>0</sub>->...->Body<sub>n</sub>->Tail
        - { <b>grid_idx : int</b>, <b>link : Node*</b> }
    - Only Store Head Index[^2]
        - Only store head idx, and then follow body segments by 
          checking adjacent grid cells for snake indicator value.
2. Point Tracker
3. Collision Checker
4. Bind Controls to Game Functions (e.g.: movement, pause/resume, menus, etc.)

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

