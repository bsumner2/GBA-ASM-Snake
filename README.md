# Snake for The GameBoy Advance [WIP]

## Written in GAS dialect ARM Assembly

So far, I have the draw grid and rng stuff set up. Right now, it waits for user to press
start button in order to initialize the snake's location on the grid. The location is
randomly generated using LFSR RNG implementation, whose RNG state is constantly being 
manipulated by bitwise operations on the current RNG state and the value of 
the GBA Keypad status register. These constant manipulations are performed 
by the poll_keys subroutine which takes the value of the keypad status register,
both as the return value for poll_keys as well as the rng manip value passed to rng state manipulator subroutine.

